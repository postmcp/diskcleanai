import SwiftUI
import QuickLook

/// Outline table of the focused folder, largest first.
struct ExploreListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme
    let focus: FileNode
    let filter: String?
    @State private var selection: Set<FileNode.ID> = []
    @State private var previewURL: URL?

    var body: some View {
        let rows = focus.children.filter { node in !node.removed && (filter.map { f in node.name.localizedCaseInsensitiveContains(f) } ?? true) }
        Table(rows, children: \.outlineChildren, selection: $selection) {
            TableColumn("Name") { node in
                HStack(spacing: 8) {
                    FileIconView(url: node.url, isDirectory: node.isContainer, size: 16)
                    Text(node.name).foregroundStyle(node.unreadable ? theme.muted : theme.ink).lineLimit(1)
                    if node.unreadable {
                        Image(systemName: "lock").font(.system(size: 10)).foregroundStyle(theme.muted).help("Could not be read")
                    }
                    if appState.isQueued(node) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 11)).foregroundStyle(theme.brand)
                    }
                }
            }
            .width(min: 220, ideal: 360)
            TableColumn("Size") { node in
                HStack(spacing: 8) {
                    SizeBar(fraction: focus.size > 0 ? Double(node.size) / Double(focus.size) : 0, color: theme.color(for: node.dominantCategory), height: 5)
                        .frame(width: 70)
                    Text(Format.bytes(node.size)).font(.system(size: 12, design: .monospaced)).foregroundStyle(theme.ink)
                }
            }
            .width(min: 150, ideal: 170)
            TableColumn("Share") { node in
                Text(Format.percent(focus.size > 0 ? Double(node.size) / Double(focus.size) : 0)).foregroundStyle(theme.muted)
            }
            .width(60)
            TableColumn("Items") { node in
                Text(node.isContainer ? Format.count(node.fileCount) : "—").foregroundStyle(theme.muted)
            }
            .width(80)
            TableColumn("Kind") { node in
                Text(node.isContainer ? (node.isPackage ? "Package" : "Folder") : node.category.label).foregroundStyle(theme.muted)
            }
            .width(110)
            TableColumn("Modified") { node in
                Text(Format.shortDate(node.modified)).foregroundStyle(theme.muted)
            }
            .width(110)
        }
        .contextMenu(forSelectionType: FileNode.ID.self) { ids in
            if let node = node(for: ids.first) {
                Button("Reveal in Finder") { TrashService.reveal(node.url) }
                Button("Quick Look") { previewURL = node.url }
                Button("Copy Path") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(node.path, forType: .string)
                }
                Divider()
                if node.isContainer { Button("Open Here") { appState.focus(node) } }
                Button("Show in Sunburst") { appState.showInSunburst(node) }
                Divider()
                if appState.isQueued(node) {
                    Button("Remove from Review & Clean") { appState.dequeue(node.url) }
                } else {
                    Button("Add to Review & Clean") { appState.enqueue(node: node, source: .folders, reason: "Picked from the folder list") }
                        .disabled(SafetyPolicy.assess(path: node.path, insidePackage: node.isInsidePackage) == .protected)
                }
            }
        } primaryAction: { ids in
            if let node = node(for: ids.first) {
                if node.isContainer { appState.focus(node) } else { previewURL = node.url }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(theme.line))
        .quickLookPreview($previewURL)
        .onChange(of: selection) { _, ids in appState.selectedNode = node(for: ids.first) }
        .onChange(of: focus.id) { _, _ in selection = [] }
    }

    /// Resolves a row id to its node by walking the focused sub-tree once per selection change.
    private func node(for id: FileNode.ID?) -> FileNode? {
        guard let id else { return nil }
        var stack: [FileNode] = focus.children
        while let node = stack.popLast() {
            if node.id == id { return node }
            if node.isContainer { stack.append(contentsOf: node.children) }
        }
        return nil
    }
}
