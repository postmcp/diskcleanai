import SwiftUI

/// Ranked bars: items in the focused folder, or the biggest files/folders anywhere in the scan.
struct TopSizesView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme
    let focus: FileNode
    let snapshot: ScanSnapshot
    let filter: String?

    enum Scope: Hashable { case folder, files, folders, quickWin }
    @State private var scope: Scope = .folder
    @State private var biggestFolders: [FileNode] = []

    var body: some View {
        let rows = rows()
        let top = rows.first?.size ?? 1
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ChipPicker(options: chips, selection: $scope)
                Spacer()
                Text("\(rows.count) shown").font(.system(size: 11.5)).foregroundStyle(theme.muted)
                if let win = appState.quickWin, scope == .quickWin {
                    Button {
                        appState.enqueue(win.nodes.map { CleanupItem(node: $0, source: .folders, reason: "Quick win: \(win.label)") })
                    } label: { Label("Stage all \(win.count) for cleanup", systemImage: "trash") }
                    .buttonStyle(.primary)
                }
            }
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, node in
                        row(index + 1, node, fraction: Double(node.size) / Double(max(top, 1)))
                    }
                }
            }
        }
        .onAppear { if appState.quickWin != nil { scope = .quickWin } }
        .onChange(of: appState.quickWin?.id) { _, id in scope = id == nil ? .folder : .quickWin }
        .onChange(of: scope) { _, s in if s == .folders && biggestFolders.isEmpty { computeBiggestFolders() } }
    }

    private var chips: [(Scope, String)] {
        var c: [(Scope, String)] = [(.folder, "In this folder"), (.files, "Biggest files anywhere"), (.folders, "Biggest folders anywhere")]
        if let win = appState.quickWin { c.insert((.quickWin, win.label), at: 0) }
        return c
    }

    private func rows() -> [FileNode] {
        var list: [FileNode]
        switch scope {
        case .folder: list = focus.children
        case .files: list = Array(snapshot.largeFiles.prefix(200))
        case .folders: list = biggestFolders
        case .quickWin: list = appState.quickWin?.nodes ?? []
        }
        list = list.filter { !$0.removed }
        if let filter { list = list.filter { $0.name.localizedCaseInsensitiveContains(filter) } }
        return Array(list.prefix(300))
    }

    private func computeBiggestFolders() {
        let root = snapshot.root
        Task.detached(priority: .userInitiated) {
            var dirs: [FileNode] = []
            root.forEachNode { node in
                if node.isContainer, node !== root, node.parent !== root, node.size > 50 * 1_048_576 { dirs.append(node) }
            }
            dirs.sort { $0.size > $1.size }
            let top = Array(dirs.prefix(150))
            await MainActor.run { biggestFolders = top }
        }
    }

    private func row(_ rank: Int, _ node: FileNode, fraction: Double) -> some View {
        let selected = appState.selectedNode === node
        let color = theme.color(for: node.dominantCategory)
        return Button {
            appState.selectedNode = node
        } label: {
            HStack(spacing: 10) {
                Text("\(rank)").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(theme.muted).frame(width: 26, alignment: .trailing)
                FileIconView(url: node.url, isDirectory: node.isContainer, size: 18)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(theme.surface)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 6, style: .continuous).fill(color.opacity(theme.isDark ? 0.45 : 0.32))
                            .frame(width: max(geo.size.width * fraction, 4))
                    }
                    Text(scope == .folder ? node.name : Format.tildePath(node.path))
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(theme.ink).lineLimit(1).truncationMode(.middle).padding(.horizontal, 10)
                }
                .frame(height: 30)
                Text(node.isContainer ? "\(Format.count(node.fileCount)) files" : Format.daysAgo(node.modified))
                    .font(.system(size: 11)).foregroundStyle(theme.muted).frame(width: 110, alignment: .trailing)
                Text(Format.percent(focus.size > 0 ? Double(node.size) / Double(snapshot.totalSize) : 0))
                    .font(.system(size: 11)).foregroundStyle(theme.muted).frame(width: 50, alignment: .trailing)
                Text(Format.bytes(node.size)).font(.system(size: 13, weight: .bold)).foregroundStyle(theme.ink).frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(selected ? theme.brandSoft : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture(count: 2).onEnded { appState.focus(node) })
        .fileContextMenu(url: node.url, node: node, source: .folders, reason: scope == .quickWin ? "Quick win: \(appState.quickWin?.label ?? "")" : "Ranked by size", appState: appState)
    }
}
