import SwiftUI
import QuickLook

/// The checklist every removal passes through. Approved items go to the Trash; a batch can be undone.
struct CleanupReviewView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme
    @AppStorage(Pref.confirmBeforeClean) private var confirmBeforeClean = true
    @State private var showConfirm = false
    @State private var selection: Set<CleanupItem.ID> = []
    @State private var previewURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                SectionTitle(title: "Review & Clean", subtitle: "Everything you approve moves to the Trash — never straight to oblivion — so a wrong click is one undo away.")
                Spacer()
                if let batch = appState.lastBatch, !batch.moved.isEmpty {
                    Button { appState.undoLastCleanup() } label: { Label("Undo last cleanup (\(Format.bytes(batch.freedBytes)))", systemImage: "arrow.uturn.backward") }
                        .buttonStyle(.secondary)
                }
            }

            if appState.queue.isEmpty {
                EmptyState(systemImage: "trash.slash", title: "Nothing queued yet",
                           message: "Add items from Large Files, Duplicates, Apps, Downloads, Similar Photos or the AI Advisor. They show up here for a final look before anything moves.",
                           actionTitle: "Go to Explore") { appState.selection = .explore }
            } else {
                summary
                if !appState.failedItems.isEmpty { failedBanner }
                list
            }
        }
        .padding(24)
        .animation(.easeOut(duration: 0.25), value: appState.failedItems.count)
        .confirmationDialog("Move \(appState.approvedItems.count) items (\(Format.bytes(appState.approvedBytes))) to the Trash?", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Move to Trash") { appState.performCleanup() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Items stay in the Trash until you empty it. You can undo this batch from here or the Clean menu.")
        }
        .sheet(isPresented: Binding(get: { appState.isCleaning }, set: { _ in })) {
            VStack(spacing: 14) {
                ProgressView(value: Double(appState.cleaningProgress.done), total: Double(max(appState.cleaningProgress.total, 1)))
                    .frame(width: 320)
                Text("Moving to Trash… \(appState.cleaningProgress.done) of \(appState.cleaningProgress.total)")
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(32)
        }
        .quickLookPreview($previewURL)
    }

    private var summary: some View {
        HStack(spacing: 12) {
            StatTile(label: "Approved", value: "\(appState.approvedItems.count) of \(appState.queue.count)", detail: "items will move to the Trash")
            StatTile(label: "Space to reclaim", value: Format.bytes(appState.approvedBytes), color: theme.brand)
            StatTile(label: "Needs a second look", value: "\(appState.queue.filter { $0.safety == .caution }.count)", detail: "items from Library or system folders", color: theme.warning)
            VStack(spacing: 8) {
                Button {
                    if confirmBeforeClean { showConfirm = true } else { appState.performCleanup() }
                } label: {
                    Label("Clean \(Format.bytes(appState.approvedBytes))", systemImage: "trash").frame(maxWidth: .infinity)
                }
                .buttonStyle(.primaryLarge)
                .disabled(appState.approvedItems.isEmpty || appState.isCleaning)
                .keyboardShortcut(.defaultAction)
                HStack(spacing: 6) {
                    Button("All") { appState.setApproval(true) }.buttonStyle(.secondary)
                    Button("None") { appState.setApproval(false) }.buttonStyle(.secondary)
                    Button("Clear") { appState.clearQueue() }.buttonStyle(.secondary)
                }
            }
            .frame(width: 220)
        }
    }

    /// Shown after a cleanup left some items behind — typically files in use or paths
    /// macOS will not let the app touch. Nothing was lost; they are simply still here.
    private var failedBanner: some View {
        let failed = appState.failedItems
        return HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(theme.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(failed.count) item\(failed.count == 1 ? "" : "s") couldn't be moved to the Trash")
                    .font(.system(size: 12.5, weight: .semibold)).foregroundStyle(theme.ink)
                Text("Usually the file is in use or macOS won't let this app touch it. Retry, or ignore \(failed.count == 1 ? "it" : "them") to take \(failed.count == 1 ? "it" : "them") off the list.")
                    .font(.system(size: 11)).foregroundStyle(theme.body)
            }
            Spacer()
            Button("Retry") { appState.retryFailed() }.buttonStyle(.secondary).disabled(appState.isCleaning)
            Button("Ignore failed") { appState.ignoreFailed() }.buttonStyle(.secondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(theme.warning.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(theme.warning.opacity(0.35)))
    }

    private var list: some View {
        let grouped = Dictionary(grouping: appState.queue, by: \.source)
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(CleanupSource.allCases.filter { grouped[$0] != nil }) { source in
                    let items = grouped[source] ?? []
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label(source.label, systemImage: source.systemImage).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(theme.ink)
                            Text("\(items.count) · \(Format.bytes(items.reduce(0) { $0 + $1.size }))").font(.system(size: 11.5)).foregroundStyle(theme.muted)
                            Spacer()
                            Button("Approve all") { appState.setApproval(true, for: Set(items.map(\.id))) }.buttonStyle(.plain).font(.system(size: 11.5, weight: .medium)).foregroundStyle(theme.brand)
                            Button("Skip all") { appState.setApproval(false, for: Set(items.map(\.id))) }.buttonStyle(.plain).font(.system(size: 11.5, weight: .medium)).foregroundStyle(theme.muted)
                            Button("Remove") { appState.dequeue(ids: Set(items.map(\.id))) }.buttonStyle(.plain).font(.system(size: 11.5, weight: .medium)).foregroundStyle(theme.danger)
                        }
                        VStack(spacing: 0) {
                            ForEach(items) { item in
                                row(item)
                                Divider().overlay(theme.line)
                            }
                        }
                        .card(padding: 4)
                    }
                }
            }
        }
    }

    private func row(_ item: CleanupItem) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(get: { item.approved }, set: { appState.setApproval($0, for: [item.id]) }))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(item.safety == .protected)
            FileIconView(url: item.url, isDirectory: item.isDirectory, size: 22)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(item.name).font(.system(size: 12.5, weight: .medium)).foregroundStyle(item.approved ? theme.ink : theme.muted).lineLimit(1)
                    SafetyBadge(level: item.safety)
                }
                Text(Format.tildePath(item.url.path)).font(.system(size: 10.5, design: .monospaced)).foregroundStyle(theme.muted).lineLimit(1).truncationMode(.middle)
                if let failure = appState.cleanupFailures[item.url] {
                    Label(failure, systemImage: "exclamationmark.circle").font(.system(size: 11)).foregroundStyle(theme.danger).lineLimit(1).help(failure)
                } else {
                    Text(item.reason).font(.system(size: 11)).foregroundStyle(theme.body).lineLimit(1)
                }
            }
            Spacer()
            Text(Format.bytes(item.size)).font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundStyle(theme.ink)
            Button { previewURL = item.url } label: { Image(systemName: "eye") }.buttonStyle(.secondary).help("Quick Look")
            Button { TrashService.reveal(item.url) } label: { Image(systemName: "magnifyingglass") }.buttonStyle(.secondary).help("Reveal in Finder")
            if appState.cleanupFailures[item.url] != nil {
                Button("Ignore") { appState.ignoreFailed([item.url]) }.buttonStyle(.secondary).help("Leave this on disk and take it off the list")
            } else {
                Button { appState.dequeue(item.url) } label: { Image(systemName: "xmark") }.buttonStyle(.secondary).help("Remove from list")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contextMenu {
            Button("Reveal in Finder") { TrashService.reveal(item.url) }
            Button("Quick Look") { previewURL = item.url }
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.url.path, forType: .string)
            }
            Divider()
            if appState.cleanupFailures[item.url] != nil {
                Button("Ignore") { appState.ignoreFailed([item.url]) }
            } else {
                Button("Remove from list") { appState.dequeue(item.url) }
            }
        }
    }
}
