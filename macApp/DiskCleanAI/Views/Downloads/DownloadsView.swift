import SwiftUI
import QuickLook

struct DownloadsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme
    @AppStorage(Pref.downloadsOldDays) private var oldDays = 30
    @State private var age: Age = .all
    @State private var kind: Kind = .all
    @State private var selection: Set<FileNode.ID> = []
    @State private var sortOrder = [KeyPathComparator(\FileNode.size, order: .reverse)]
    @State private var previewURL: URL?

    enum Age: Hashable { case all, old, veryOld, ancient }
    enum Kind: Hashable { case all, installers, archives, media, documents }

    private static let installers: Set<String> = ["dmg", "pkg", "xip", "mpkg"]
    private static let archives: Set<String> = ["zip", "tar", "gz", "tgz", "7z", "rar", "bz2", "xz"]

    var body: some View {
        Group {
            switch appState.downloads {
            case .idle, .running:
                ProgressState(title: "Reading ~/Downloads…", detail: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path)
            case .failed(let message):
                EmptyState(systemImage: "exclamationmark.triangle", title: "Could not read Downloads", message: message, actionTitle: "Try Again") { appState.loadDownloads(force: true) }
            case .done(let root):
                content(root)
            }
        }
        .onAppear { appState.loadDownloads() }
    }

    private func content(_ root: FileNode) -> some View {
        let all = root.children.filter { !$0.removed }
        let rows = filtered(all)
        let old = all.filter { isOlder(than: oldDays, $0) }
        let installers = all.filter { Self.installers.contains($0.fileExtension) }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(title: "Downloads", subtitle: "\(Format.count(all.count)) items · \(Format.bytes(root.size))")
                Spacer()
                Button {
                    appState.enqueue(rows.filter { selection.contains($0.id) }.map { CleanupItem(node: $0, source: .downloads, reason: reason(for: $0)) })
                } label: { Label("Add \(selection.count) to Clean", systemImage: "plus.circle") }
                .buttonStyle(.primary)
                .disabled(selection.isEmpty)
                Button { appState.loadDownloads(force: true) } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.secondary).help("Reload")
            }
            HStack(spacing: 12) {
                StatTile(label: "Older than \(oldDays) days", value: Format.bytes(old.reduce(0) { $0 + $1.size }), detail: "\(old.count) items", color: theme.warning)
                StatTile(label: "Installers (.dmg, .pkg)", value: Format.bytes(installers.reduce(0) { $0 + $1.size }), detail: "\(installers.count) items — usually safe once installed")
                StatTile(label: "Largest download", value: all.first.map { Format.bytes($0.size) } ?? "—", detail: all.first?.name)
            }
            HStack(spacing: 10) {
                ChipPicker(options: [(Age.all, "Any age"), (.old, "\(oldDays)+ days"), (.veryOld, "90+ days"), (.ancient, "1+ year")], selection: $age)
                Divider().frame(height: 18)
                ChipPicker(options: [(Kind.all, "All types"), (.installers, "Installers"), (.archives, "Archives"), (.media, "Media"), (.documents, "Documents")], selection: $kind)
                Spacer()
                Button {
                    appState.enqueue(installers.filter { isOlder(than: 7, $0) }.map { CleanupItem(node: $0, source: .downloads, reason: "Installer downloaded \(Format.daysAgo($0.modified).lowercased())") })
                } label: { Label("Queue old installers", systemImage: "shippingbox") }
                .buttonStyle(.secondary)
                .disabled(installers.isEmpty)
            }

            Table(rows, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("") { node in QueueToggle(appState: appState, node: node, source: .downloads, reason: reason(for: node)) }.width(24)
                TableColumn("Name", value: \.name) { node in
                    HStack(spacing: 8) {
                        FileIconView(url: node.url, isDirectory: node.isContainer, size: 16)
                        Text(node.name).foregroundStyle(theme.ink).lineLimit(1)
                    }
                }
                .width(min: 260, ideal: 420)
                TableColumn("Size", value: \.size) { node in
                    Text(Format.bytes(node.size)).font(.system(size: 12, design: .monospaced)).foregroundStyle(theme.ink)
                }
                .width(90)
                TableColumn("Kind") { node in
                    Text(node.isContainer ? "Folder" : (Self.installers.contains(node.fileExtension) ? "Installer" : node.category.label)).foregroundStyle(theme.body)
                }
                .width(120)
                TableColumn("Downloaded", value: \.sortableModified) { node in
                    Text(Format.daysAgo(node.modified)).foregroundStyle(isOlder(than: oldDays, node) ? theme.warning : theme.muted)
                }
                .width(120)
                TableColumn("Last opened", value: \.sortableAccessed) { node in
                    Text(Format.daysAgo(node.accessed)).foregroundStyle(theme.muted)
                }
                .width(110)
            }
            .contextMenu(forSelectionType: FileNode.ID.self) { ids in
                if let node = rows.first(where: { ids.contains($0.id) }) {
                    Button("Reveal in Finder") { TrashService.reveal(node.url) }
                    Button("Quick Look") { previewURL = node.url }
                    Button("Open") { TrashService.open(node.url) }
                    Divider()
                    Button("Add \(ids.count) to Review & Clean") {
                        appState.enqueue(rows.filter { ids.contains($0.id) }.map { CleanupItem(node: $0, source: .downloads, reason: reason(for: $0)) })
                    }
                }
            } primaryAction: { ids in
                if let node = rows.first(where: { ids.contains($0.id) }) { previewURL = node.url }
            }
            .scrollContentBackground(.hidden)
            .background(theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(theme.line))
            .quickLookPreview($previewURL)
        }
        .padding(24)
    }

    private func isOlder(than days: Int, _ node: FileNode) -> Bool {
        guard let date = node.modified else { return false }
        return Date().timeIntervalSince(date) > Double(days) * 86_400
    }

    private func reason(for node: FileNode) -> String {
        if Self.installers.contains(node.fileExtension) { return "Installer downloaded \(Format.daysAgo(node.modified).lowercased())" }
        return "Download from \(Format.daysAgo(node.modified).lowercased())"
    }

    private func filtered(_ all: [FileNode]) -> [FileNode] {
        var rows = all.filter { node in
            switch age {
            case .all: break
            case .old: if !isOlder(than: oldDays, node) { return false }
            case .veryOld: if !isOlder(than: 90, node) { return false }
            case .ancient: if !isOlder(than: 365, node) { return false }
            }
            switch kind {
            case .all: return true
            case .installers: return Self.installers.contains(node.fileExtension)
            case .archives: return Self.archives.contains(node.fileExtension)
            case .media: return [.video, .photos, .audio].contains(node.category)
            case .documents: return node.category == .documents
            }
        }
        rows.sort(using: sortOrder)
        return rows
    }
}
