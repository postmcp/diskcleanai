import Foundation
import SwiftUI
import Observation
import AppKit

enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case explore, find, apps, aiAdvisor, cleanup, tools

    var id: String { rawValue }

    var title: String {
        switch self {
        case .explore: return "Explore"
        case .find: return "Find"
        case .apps: return "Apps"
        case .aiAdvisor: return "AI Advisor"
        case .cleanup: return "Review & Clean"
        case .tools: return "System Tools"
        }
    }

    var subtitle: String {
        switch self {
        case .explore: return "Sunburst, treemap, folders…"
        case .find: return "Large files, duplicates, photos"
        case .apps: return "Unused apps and leftovers"
        case .aiAdvisor: return "Ask a model what to remove"
        case .cleanup: return "Approve, then Trash"
        case .tools: return "Ports, memory, quick fixes"
        }
    }

    var systemImage: String {
        switch self {
        case .explore: return "square.grid.2x2"
        case .find: return "magnifyingglass"
        case .apps: return "app.badge"
        case .aiAdvisor: return "sparkles"
        case .cleanup: return "trash"
        case .tools: return "wrench.and.screwdriver"
        }
    }
}

/// Tabs inside the Find screen.
enum FindTab: String, CaseIterable, Identifiable, Hashable {
    case largeFiles, duplicates, downloads, similarPhotos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .largeFiles: return "Large Files"
        case .duplicates: return "Duplicates"
        case .downloads: return "Downloads"
        case .similarPhotos: return "Similar Photos"
        }
    }

    var systemImage: String {
        switch self {
        case .largeFiles: return "doc.text.magnifyingglass"
        case .duplicates: return "doc.on.doc"
        case .downloads: return "arrow.down.circle"
        case .similarPhotos: return "photo.on.rectangle.angled"
        }
    }

    /// Whether the tab needs a completed scan.
    var needsScan: Bool { self != .downloads }
}

/// Generic lifecycle for the on-demand analyses (duplicates, photos, apps, AI).
enum TaskState<Value> {
    case idle
    case running
    case done(Value)
    case failed(String)

    var value: Value? {
        if case .done(let v) = self { return v }
        return nil
    }

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }
}

struct Toast: Identifiable, Equatable {
    enum Style { case info, success, warning }
    let id = UUID()
    let message: String
    let style: Style
    var actionTitle: String? = nil
}

/// The single source of truth for the window: scan results, every analysis, the
/// cleanup queue and navigation. Lives on the main actor; heavy work is awaited.
@MainActor
@Observable
final class AppState {
    // MARK: Scan
    enum ScanPhase: Equatable {
        case idle, scanning, done
        case failed(String)
    }

    var volumes: [VolumeInfo] = VolumeInfo.mounted()
    var scanRoot: URL
    var phase: ScanPhase = .idle
    var progress = ScanProgress()
    var snapshot: ScanSnapshot?
    var focusNode: FileNode?
    var hasFullDiskAccess = FullDiskAccess.isGranted()
    @ObservationIgnored private var scanner: DiskScanner?
    @ObservationIgnored private var progressTask: Task<Void, Never>?

    // MARK: Navigation
    var selection: SidebarItem? = .explore
    var findTab: FindTab = .largeFiles
    var largeFileCategoryFilter: FileCategory?
    /// Explore screen state.
    var exploreMode: ExploreMode = .sunburst
    var colorMode: ColorMode = .byType
    var exploreDepth: Int = 4
    var selectedNode: FileNode?
    var quickWin: QuickWin?
    var toast: Toast?
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    // MARK: Analyses
    var duplicates: TaskState<[DuplicateGroup]> = .idle
    var duplicateProgress: (done: Int, total: Int) = (0, 0)
    @ObservationIgnored private var duplicateFinder: DuplicateFinder?

    var similarPhotos: TaskState<[SimilarPhotoGroup]> = .idle
    var photoProgress: (done: Int, total: Int) = (0, 0)
    @ObservationIgnored private var photoFinder: SimilarPhotoFinder?

    var apps: TaskState<[InstalledApp]> = .idle
    var downloads: TaskState<FileNode> = .idle

    var ai: TaskState<AIAnalysis> = .idle
    var aiPayloadPreview: String?
    var hasAPIKey: Bool = KeychainStore.read(account: KeychainStore.openRouterAccount) != nil

    // MARK: Cleanup
    var queue: [CleanupItem] = []
    var lastBatch: CleanupBatch?
    var isCleaning = false
    var cleaningProgress: (done: Int, total: Int) = (0, 0)
    /// Why each item in the queue could not be moved during the last cleanup, so the
    /// review screen can explain the failure and offer to ignore it.
    var cleanupFailures: [URL: String] = [:]
    /// Bytes this app moved to the Trash that are still sitting there. Counted as free
    /// in the sidebar so the disk readout moves as soon as a cleanup finishes.
    var pendingTrashBytes: Int64 = 0
    @ObservationIgnored private var trashedItems: [CleanupBatch.Moved] = []
    @ObservationIgnored private var activationObserver: NSObjectProtocol?

    init() {
        Pref.register()
        let last = UserDefaults.standard.string(forKey: Pref.lastScanPath)
        scanRoot = URL(fileURLWithPath: last ?? "/")
        if !FileManager.default.fileExists(atPath: scanRoot.path) { scanRoot = URL(fileURLWithPath: "/") }
        // The user may empty the Trash in Finder while we are in the background.
        activationObserver = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshPendingTrash() }
        }
    }

    // MARK: - Scanning

    var isScanning: Bool { phase == .scanning }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Scan"
        panel.message = "Choose a drive or folder to analyse."
        if panel.runModal() == .OK, let url = panel.url {
            scanRoot = url
            startScan()
        }
    }

    func startScan(_ root: URL? = nil) {
        if let root { scanRoot = root }
        guard !isScanning else { return }
        hasFullDiskAccess = FullDiskAccess.isGranted()
        UserDefaults.standard.set(scanRoot.path, forKey: Pref.lastScanPath)
        let scanner = DiskScanner(options: ScanOptions(excludedPaths: Pref.excludedPaths))
        self.scanner = scanner
        phase = .scanning
        progress = ScanProgress()
        resetDerivedState()
        let started = Date()
        progressTask?.cancel()
        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self, let scanner = self.scanner else { return }
                self.progress = scanner.counters.snapshot
            }
        }
        let root = scanRoot
        Task {
            do {
                let node = try await scanner.scan(root: root)
                let built = await Task.detached(priority: .userInitiated) {
                    ScanSnapshot.build(root: node, rootURL: root, duration: Date().timeIntervalSince(started))
                }.value
                progressTask?.cancel()
                snapshot = built
                focusNode = built.root
                volumes = VolumeInfo.mounted()
                phase = .done
                refreshPendingTrash()
                if selection == nil { selection = .explore }
                if built.unreadableCount > 0 && !hasFullDiskAccess {
                    showToast("\(Format.count(built.unreadableCount)) folders could not be read. Grant Full Disk Access for a complete picture.", style: .warning)
                }
            } catch is CancellationError {
                progressTask?.cancel()
                phase = snapshot == nil ? .idle : .done
            } catch {
                progressTask?.cancel()
                phase = .failed(error.localizedDescription)
            }
            self.scanner = nil
        }
    }

    func cancelScan() {
        scanner?.cancel()
    }

    private func resetDerivedState() {
        duplicates = .idle
        similarPhotos = .idle
        ai = .idle
        aiPayloadPreview = nil
        focusNode = nil
        selectedNode = nil
        quickWin = nil
        largeFileCategoryFilter = nil
    }

    /// Rebuild the derived lists after items were trashed.
    private func rebuildSnapshot() {
        guard let old = snapshot else { return }
        old.root.refinalizeAncestors()
        snapshot = ScanSnapshot.build(root: old.root, rootURL: old.rootURL, duration: old.duration)
        if let focus = focusNode, focus.removed { focusNode = snapshot?.root }
        if let sel = selectedNode, sel.removed { selectedNode = nil }
        if let win = quickWin { quickWin = snapshot?.quickWins.first { $0.id == win.id } }
    }

    // MARK: - Analyses

    func findDuplicates() {
        guard let root = snapshot?.root, !duplicates.isRunning else { return }
        let minMB = max(UserDefaults.standard.double(forKey: Pref.duplicateMinMB), 0.05)
        let finder = DuplicateFinder()
        duplicateFinder = finder
        duplicates = .running
        let poll = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                self?.duplicateProgress = finder.progress
            }
        }
        Task {
            do {
                let groups = try await finder.find(in: root, minimumSize: Int64(minMB * 1_048_576))
                duplicates = .done(groups)
            } catch is CancellationError {
                duplicates = .idle
            } catch {
                duplicates = .failed(error.localizedDescription)
            }
            poll.cancel()
            duplicateFinder = nil
        }
    }

    func cancelDuplicates() { duplicateFinder?.cancel() }

    func findSimilarPhotos() {
        guard let root = snapshot?.root, !similarPhotos.isRunning else { return }
        let threshold = max(min(UserDefaults.standard.integer(forKey: Pref.photoThreshold), 20), 1)
        let finder = SimilarPhotoFinder()
        photoFinder = finder
        similarPhotos = .running
        let poll = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                self?.photoProgress = finder.progress
            }
        }
        Task {
            do {
                let groups = try await finder.find(in: root, threshold: threshold)
                similarPhotos = .done(groups)
            } catch is CancellationError {
                similarPhotos = .idle
            } catch {
                similarPhotos = .failed(error.localizedDescription)
            }
            poll.cancel()
            photoFinder = nil
        }
    }

    func cancelSimilarPhotos() { photoFinder?.cancel() }

    func loadApps(force: Bool = false) {
        if case .done = apps, !force { return }
        if apps.isRunning { return }
        apps = .running
        Task {
            apps = .done(await AppInventory.load())
        }
    }

    func loadDownloads(force: Bool = false) {
        if case .done = downloads, !force { return }
        if downloads.isRunning { return }
        downloads = .running
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        Task {
            do {
                let node = try await DiskScanner().scan(root: url)
                downloads = .done(node)
            } catch {
                downloads = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - AI

    func refreshKeyStatus() {
        hasAPIKey = KeychainStore.read(account: KeychainStore.openRouterAccount) != nil
    }

    func runAIAnalysis() {
        guard !ai.isRunning else { return }
        guard let key = KeychainStore.read(account: KeychainStore.openRouterAccount), !key.isEmpty else {
            ai = .failed(OpenRouterError.missingKey.localizedDescription)
            return
        }
        let model = UserDefaults.standard.string(forKey: Pref.model) ?? Pref.defaultModel
        let downloadNodes = (downloads.value?.children ?? []).sorted { $0.size > $1.size }
        let payload = AIAdvisor.buildPayload(snapshot: snapshot, downloads: downloadNodes, apps: apps.value ?? [], duplicates: duplicates.value ?? [])
        aiPayloadPreview = try? AIAdvisor.encode(payload)
        ai = .running
        let snapshot = self.snapshot
        Task {
            do {
                let analysis = try await AIAdvisor.analyze(client: OpenRouterClient(apiKey: key), model: model, payload: payload, snapshot: snapshot)
                ai = .done(analysis)
            } catch {
                ai = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - Cleanup queue

    var approvedItems: [CleanupItem] { queue.filter(\.approved) }
    var approvedBytes: Int64 { approvedItems.reduce(0) { $0 + $1.size } }
    /// Items still in the queue that the last cleanup could not move.
    var failedItems: [CleanupItem] { queue.filter { cleanupFailures[$0.url] != nil } }

    func isQueued(_ url: URL) -> Bool {
        queue.contains { $0.url == url }
    }

    func isQueued(_ node: FileNode) -> Bool { isQueued(node.url) }

    @discardableResult
    func enqueue(_ item: CleanupItem) -> Bool {
        guard item.safety != .protected else {
            showToast("\(item.name) is protected and cannot be removed from here.", style: .warning)
            return false
        }
        guard !isQueued(item.url) else { return false }
        queue.append(item)
        return true
    }

    func enqueue(_ items: [CleanupItem]) {
        var added = 0
        var skipped = 0
        for item in items {
            if item.safety == .protected { skipped += 1; continue }
            if !isQueued(item.url) { queue.append(item); added += 1 }
        }
        if added > 0 {
            showToast("Added \(added) item\(added == 1 ? "" : "s") to Review & Clean.", style: .success)
        }
        if skipped > 0 {
            showToast("\(skipped) protected item\(skipped == 1 ? " was" : "s were") skipped.", style: .warning)
        }
    }

    func enqueue(node: FileNode, source: CleanupSource, reason: String) {
        enqueue(CleanupItem(node: node, source: source, reason: reason))
    }

    func toggle(node: FileNode, source: CleanupSource, reason: String) {
        if let index = queue.firstIndex(where: { $0.url == node.url }) {
            queue.remove(at: index)
        } else {
            enqueue(node: node, source: source, reason: reason)
        }
    }

    func dequeue(_ url: URL) {
        queue.removeAll { $0.url == url }
        cleanupFailures[url] = nil
    }

    func dequeue(ids: Set<CleanupItem.ID>) {
        for item in queue where ids.contains(item.id) { cleanupFailures[item.url] = nil }
        queue.removeAll { ids.contains($0.id) }
    }

    /// Drop items the last cleanup could not move. Files in use or without permission
    /// stay on disk; ignoring them just takes them off the list.
    func ignoreFailed(_ urls: Set<URL>? = nil) {
        let targets = urls ?? Set(cleanupFailures.keys)
        guard !targets.isEmpty else { return }
        queue.removeAll { targets.contains($0.url) }
        for url in targets { cleanupFailures[url] = nil }
    }

    func setApproval(_ approved: Bool, for ids: Set<CleanupItem.ID>? = nil) {
        for i in queue.indices where ids == nil || ids!.contains(queue[i].id) {
            queue[i].approved = approved && queue[i].safety != .protected
        }
    }

    func clearQueue() {
        queue.removeAll()
        cleanupFailures.removeAll()
    }

    func performCleanup() { performCleanup(approvedItems) }

    /// Try again with only the items the last cleanup left behind.
    func retryFailed() { performCleanup(failedItems) }

    private func performCleanup(_ items: [CleanupItem]) {
        guard !items.isEmpty, !isCleaning else { return }
        isCleaning = true
        cleaningProgress = (0, items.count)
        cleanupFailures.removeAll()
        Task {
            let batch = await TrashService.trash(items) { [weak self] done, total in
                self?.cleaningProgress = (done, total)
            }
            lastBatch = batch
            let movedURLs = Set(batch.moved.map(\.original))
            queue.removeAll { movedURLs.contains($0.url) }
            for failure in batch.failures { cleanupFailures[failure.url] = failure.message }
            trashedItems.append(contentsOf: batch.moved)
            markRemoved(movedURLs)
            volumes = VolumeInfo.mounted()
            refreshPendingTrash()
            isCleaning = false
            if batch.failures.isEmpty {
                showToast("Moved \(batch.moved.count) item\(batch.moved.count == 1 ? "" : "s") to the Trash — \(Format.bytes(batch.freedBytes)) reclaimed.", style: .success, actionTitle: "Undo")
            } else {
                showToast("\(batch.moved.count) moved, \(batch.failures.count) failed. \(Format.bytes(batch.freedBytes)) reclaimed.", style: .warning, actionTitle: batch.moved.isEmpty ? nil : "Undo")
            }
        }
    }

    func undoLastCleanup() {
        guard let batch = lastBatch, !batch.moved.isEmpty else { return }
        Task {
            let failures = await TrashService.restore(batch)
            lastBatch = nil
            let stuck = Set(failures.map(\.url))
            let restored = Set(batch.moved.filter { !stuck.contains($0.original) }.map(\.trashed))
            trashedItems.removeAll { restored.contains($0.trashed) }
            refreshPendingTrash()
            if failures.isEmpty {
                showToast("Restored \(batch.moved.count) item\(batch.moved.count == 1 ? "" : "s") from the Trash.", style: .info)
            } else {
                showToast("Restored \(batch.moved.count - failures.count) items; \(failures.count) could not be moved back.", style: .warning)
            }
            // Restored files are back on disk; a rescan brings them back into the tree.
            if snapshot != nil { startScan() }
        }
    }

    private func markRemoved(_ urls: Set<URL>) {
        guard !urls.isEmpty else { return }
        if let root = snapshot?.root {
            for url in urls {
                if let node = root.node(atPath: url.path) { node.removed = true }
            }
            rebuildSnapshot()
        }
        if let groups = duplicates.value {
            duplicates = .done(groups.compactMap { g in
                let remaining = g.files.filter { !urls.contains($0.url) }
                return remaining.count > 1 ? DuplicateGroup(id: g.id, size: g.size, files: remaining) : nil
            })
        }
        if let groups = similarPhotos.value {
            similarPhotos = .done(groups.compactMap { g in
                let remaining = g.photos.filter { !urls.contains($0.node.url) }
                return remaining.count > 1 ? SimilarPhotoGroup(id: g.id, photos: remaining) : nil
            })
        }
        if let analysis = ai.value {
            let remaining = analysis.suggestions.filter { !urls.contains(URL(fileURLWithPath: $0.path)) }
            ai = .done(AIAnalysis(summary: analysis.summary, suggestions: remaining, model: analysis.model, promptTokens: analysis.promptTokens,
                                  completionTokens: analysis.completionTokens, cost: analysis.cost, createdAt: analysis.createdAt))
        }
        if case .done = apps, urls.contains(where: { $0.pathExtension == "app" || $0.path.contains("/Library/") }) { loadApps(force: true) }
        if case .done = downloads, urls.contains(where: { $0.path.contains("/Downloads/") }) { loadDownloads(force: true) }
    }

    /// Re-check which of our trashed items still exist and credit their size to the
    /// sidebar. Once the user empties the Trash the real free space catches up and
    /// the credit drops to zero.
    func refreshPendingTrash() {
        let items = trashedItems
        pendingTrashBytes = items.reduce(0) { $0 + $1.size }
        guard !items.isEmpty else { return }
        Task {
            let gone = await Task.detached(priority: .utility) {
                let fm = FileManager.default
                return Set(items.filter { !fm.fileExists(atPath: $0.trashed.path) }.map(\.trashed))
            }.value
            // Prune rather than replace: a cleanup may have appended items while we were checking.
            trashedItems.removeAll { gone.contains($0.trashed) }
            pendingTrashBytes = trashedItems.reduce(0) { $0 + $1.size }
        }
    }

    // MARK: - Toasts

    func showToast(_ message: String, style: Toast.Style = .info, actionTitle: String? = nil) {
        toast = Toast(message: message, style: style, actionTitle: actionTitle)
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(actionTitle == nil ? 4 : 8))
            if !Task.isCancelled { self?.toast = nil }
        }
    }

    // MARK: - Navigation helpers

    func showInSunburst(_ node: FileNode) {
        focusNode = node.isContainer ? node : node.parent
        selectedNode = node.isContainer ? nil : node
        exploreMode = .sunburst
        quickWin = nil
        selection = .explore
    }

    func showInFolders(_ node: FileNode) {
        focusNode = node.isContainer ? node : node.parent
        selectedNode = node.isContainer ? nil : node
        exploreMode = .list
        quickWin = nil
        selection = .explore
    }

    /// Drill into a container (or select a file) from any explore pattern.
    func focus(_ node: FileNode) {
        if node.isContainer, !node.children.isEmpty {
            focusNode = node
            selectedNode = nil
        } else {
            selectedNode = node
        }
    }

    func focusParent() {
        if let parent = focusNode?.parent { focusNode = parent; selectedNode = nil }
    }

    func showQuickWin(_ win: QuickWin) {
        quickWin = win
        exploreMode = .topSizes
        selection = .explore
    }

    func showLargeFiles(category: FileCategory?) {
        largeFileCategoryFilter = category
        findTab = .largeFiles
        selection = .find
    }

    func showFind(_ tab: FindTab) {
        findTab = tab
        selection = .find
    }
}
