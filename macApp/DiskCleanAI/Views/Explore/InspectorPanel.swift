import SwiftUI
import QuickLook

/// Right-hand rail of the Explore screen: details for the selected item, or the
/// dashboard cards (AI suggestion, categories) when nothing is selected.
struct InspectorPanel: View {
    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme
    let focus: FileNode
    @State private var previewURL: URL?
    @State private var created: Date?

    var body: some View {
        let node = appState.selectedNode ?? focus
        let total = appState.snapshot?.totalSize ?? 1
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    FileIconView(url: node.url, isDirectory: node.isContainer, size: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(node.displayName)
                            .font(.system(size: 17, weight: .bold)).foregroundStyle(theme.ink).lineLimit(2)
                        HStack(spacing: 6) {
                            Badge(text: node.isContainer ? (node.isPackage ? "Package" : "Folder") : node.category.label, color: theme.color(for: node.dominantCategory))
                            SafetyBadge(level: SafetyPolicy.assess(path: node.path, insidePackage: node.isInsidePackage))
                        }
                    }
                    Spacer()
                    if appState.selectedNode != nil {
                        Button { appState.selectedNode = nil } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(theme.muted) }
                            .buttonStyle(.plain).help("Deselect")
                    }
                }
                Text(Format.tildePath(node.path))
                    .font(.system(size: 10.5, design: .monospaced)).foregroundStyle(theme.muted).lineLimit(2).truncationMode(.middle).textSelection(.enabled)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(Format.bytes(node.size)).font(.system(size: 28, weight: .bold)).tracking(-0.8).foregroundStyle(theme.ink)
                    Text("\(Format.percent(Double(node.size) / Double(max(total, 1)))) of scan").font(.system(size: 11.5)).foregroundStyle(theme.muted)
                }

                details(node)

                if node.isContainer, !node.children.isEmpty {
                    largestInside(node)
                }

                actions(node)

                if appState.selectedNode == nil {
                    AISuggestionCard()
                    categoriesCard()
                    if !appState.hasFullDiskAccess { FullDiskAccessBanner() }
                }
            }
            .padding(16)
        }
        .quickLookPreview($previewURL)
        .task(id: node.id) {
            created = (try? node.url.resourceValues(forKeys: [.creationDateKey]))?.creationDate
        }
    }

    private func details(_ node: FileNode) -> some View {
        let compressed = node.logicalSize - node.size
        return VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: "Details")
            detailRow("Size on disk", Format.bytes(node.size))
            detailRow("Logical size", Format.bytes(node.logicalSize))
            if compressed > 1024 { detailRow("Compressed by", Format.bytes(compressed), color: theme.success) }
            if node.isContainer {
                detailRow("Files", Format.count(node.fileCount))
                detailRow("Folders", Format.count(node.dirCount))
            }
            if let parent = node.parent, parent.size > 0 {
                detailRow("Of parent", Format.percent(Double(node.size) / Double(parent.size)))
            }
            detailRow("Modified", Format.daysAgo(node.modified))
            if let created { detailRow("Created", Format.daysAgo(created)) }
            if !node.isContainer, let accessed = node.accessed { detailRow("Last opened", Format.daysAgo(accessed)) }
        }
        .card(padding: 12)
    }

    private func detailRow(_ label: String, _ value: String, color: Color? = nil) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundStyle(theme.body)
            Spacer()
            Text(value).font(.system(size: 12, weight: .semibold)).foregroundStyle(color ?? theme.ink)
        }
    }

    private func largestInside(_ node: FileNode) -> some View {
        let top = node.children.filter { !$0.removed }.prefix(8)
        let max = Double(top.first?.size ?? 1)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Eyebrow(text: "Largest inside")
                Spacer()
                Text("\(Format.count(node.children.count)) items").font(.system(size: 11)).foregroundStyle(theme.muted)
            }
            ForEach(top) { child in
                Button { appState.selectedNode = child } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Circle().fill(theme.color(for: child.dominantCategory)).frame(width: 6, height: 6)
                            Text(child.name).font(.system(size: 12)).foregroundStyle(theme.ink).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Text(Format.bytes(child.size)).font(.system(size: 11.5, weight: .medium)).foregroundStyle(theme.body)
                        }
                        SizeBar(fraction: Double(child.size) / max, color: theme.color(for: child.dominantCategory), height: 3)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture(count: 2).onEnded { appState.focus(child) })
            }
        }
        .card(padding: 12)
    }

    private func actions(_ node: FileNode) -> some View {
        let level = SafetyPolicy.assess(path: node.path, insidePackage: node.isInsidePackage)
        let queued = appState.isQueued(node)
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button { TrashService.reveal(node.url) } label: { Label("Reveal", systemImage: "arrow.up.forward.square").frame(maxWidth: .infinity) }.buttonStyle(.secondary)
                Button { previewURL = node.url } label: { Label("Quick Look", systemImage: "eye").frame(maxWidth: .infinity) }.buttonStyle(.secondary)
            }
            HStack(spacing: 8) {
                Button { appState.focus(node) } label: { Label("Focus", systemImage: "scope").frame(maxWidth: .infinity) }
                    .buttonStyle(.secondary).disabled(!node.isContainer || node === focus)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(node.path, forType: .string)
                    appState.showToast("Path copied.", style: .info)
                } label: { Label("Copy Path", systemImage: "doc.on.doc").frame(maxWidth: .infinity) }.buttonStyle(.secondary)
            }
            Button {
                if queued { appState.dequeue(node.url) } else { appState.enqueue(node: node, source: .folders, reason: "Picked from Explore") }
            } label: {
                Label(queued ? "Remove from Cleanup" : "Add to Cleanup", systemImage: queued ? "checkmark.circle.fill" : "trash").frame(maxWidth: .infinity)
            }
            .buttonStyle(.primaryLarge)
            .disabled(level == .protected || node.parent == nil)
            .help(level == .protected ? "Protected path" : "Queue for Review & Clean")
        }
    }

    private func categoriesCard() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Eyebrow(text: "Biggest categories")
                Spacer()
                Button("See all") { appState.showLargeFiles(category: nil) }
                    .buttonStyle(.plain).font(.system(size: 11.5, weight: .medium)).foregroundStyle(theme.brand)
            }
            ForEach((appState.snapshot?.categoryBreakdown ?? []).prefix(6), id: \.category) { entry in
                Button { appState.showLargeFiles(category: entry.category) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Image(systemName: entry.category.systemImage).font(.system(size: 11)).foregroundStyle(theme.color(for: entry.category)).frame(width: 16)
                            Text(entry.category.label).font(.system(size: 12, weight: .medium)).foregroundStyle(theme.ink)
                            Spacer()
                            Text(Format.bytes(entry.bytes)).font(.system(size: 11.5)).foregroundStyle(theme.muted)
                        }
                        SizeBar(fraction: entry.fraction, color: theme.color(for: entry.category), height: 3)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .card(padding: 12)
    }
}

/// The "You can free up N GB" card. Shows AI results when available and a
/// heuristic estimate otherwise, so the card is useful before any key is set.
struct AISuggestionCard: View {
    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("AI Cleanup Suggestion", systemImage: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.brand)

            switch appState.ai {
            case .done(let analysis):
                Text("You can free up ").font(.system(size: 17, weight: .semibold)).foregroundStyle(theme.ink)
                + Text(Format.bytes(analysis.reclaimable)).font(.system(size: 17, weight: .bold)).foregroundStyle(theme.ink)
                Text(analysis.summary).font(.system(size: 12)).foregroundStyle(theme.body).lineLimit(4)
                Button { appState.selection = .aiAdvisor } label: {
                    HStack { Text("Review suggestions"); Image(systemName: "chevron.right") }.frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
            case .running:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Asking the model…").font(.system(size: 12)).foregroundStyle(theme.body)
                }
            case .failed(let message):
                Text(message).font(.system(size: 12)).foregroundStyle(theme.danger).lineLimit(3)
                Button("Open AI Advisor") { appState.selection = .aiAdvisor }.buttonStyle(.secondary)
            case .idle:
                let estimate = appState.snapshot?.quickWins.filter { $0.id != "media" && $0.id != "downloads" }.reduce(0) { $0 + $1.bytes } ?? 0
                Text("Roughly ").font(.system(size: 17, weight: .semibold)).foregroundStyle(theme.ink)
                + Text(Format.bytes(estimate)).font(.system(size: 17, weight: .bold)).foregroundStyle(theme.ink)
                + Text(" looks disposable").font(.system(size: 17, weight: .semibold)).foregroundStyle(theme.ink)
                Text("Caches, logs, build folders and simulators found in the scan. Ask the AI to review large files, downloads and apps too.")
                    .font(.system(size: 12)).foregroundStyle(theme.body)
                Button {
                    appState.selection = .aiAdvisor
                    if appState.hasAPIKey { appState.runAIAnalysis() }
                } label: {
                    HStack { Text(appState.hasAPIKey ? "Ask AI to review" : "Set up AI review"); Image(systemName: "chevron.right") }.frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
            }
        }
        .card(padding: 12)
    }
}
