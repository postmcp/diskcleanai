import SwiftUI

/// Grid of folder-shaped cards, one per child of the focused folder.
struct FolderCardsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme
    let focus: FileNode
    let colorer: NodeColorer
    let filter: String?

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 14)]

    var body: some View {
        let items = focus.children.filter { node in !node.removed && (filter.map { f in node.name.localizedCaseInsensitiveContains(f) } ?? true) }
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text("Folders & files").font(.system(size: 15, weight: .semibold)).foregroundStyle(theme.ink)
                    Badge(text: "\(items.count)", color: theme.muted)
                }
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(items.prefix(400)) { node in
                        card(node)
                    }
                }
                if items.count > 400 {
                    Text("Showing the 400 largest of \(Format.count(items.count)) items. Use the List pattern or the filter for the rest.")
                        .font(.system(size: 11.5)).foregroundStyle(theme.muted)
                }
            }
            .padding(2)
        }
    }

    private func card(_ node: FileNode) -> some View {
        let tint = colorer.color(for: node)
        let selected = appState.selectedNode === node
        let topCats: [FileCategory] = node.isContainer
            ? (node.categoryBytes ?? []).enumerated().filter { $0.element > 0 }.sorted { $0.element > $1.element }.prefix(3).compactMap { FileCategory(rawValue: $0.offset) }
            : [node.category]
        return Button {
            appState.selectedNode = node
        } label: {
            ZStack(alignment: .topLeading) {
                FolderShape(isFolder: node.isContainer)
                    .fill(tint.opacity(theme.isDark ? 0.22 : 0.16))
                FolderShape(isFolder: node.isContainer)
                    .stroke(selected ? theme.brand : tint.opacity(0.35), lineWidth: selected ? 2 : 1)
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()
                    HStack(alignment: .top) {
                        if !node.isContainer { FileIconView(url: node.url, isDirectory: false, size: 28) }
                        Text(node.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(theme.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        HStack(spacing: -3) {
                            ForEach(topCats, id: \.self) { cat in
                                Circle().fill(theme.color(for: cat)).frame(width: 9, height: 9)
                                    .overlay(Circle().stroke(theme.card, lineWidth: 1))
                            }
                        }
                        Text(node.isContainer ? "\(Format.count(node.fileCount)) items" : node.category.label)
                            .font(.system(size: 11.5)).foregroundStyle(theme.body)
                        Spacer()
                        Text(Format.bytes(node.size))
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.ink)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 34)
                .padding(.bottom, 14)
            }
            .frame(height: 150)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture(count: 2).onEnded { appState.focus(node) })
        .fileContextMenu(url: node.url, node: node, source: .folders, reason: "Picked from Explore", appState: appState)
        .help(Format.tildePath(node.path))
    }
}

/// A rounded rectangle with a folder tab on the top-left; plain rounded rectangle for files.
struct FolderShape: Shape {
    var isFolder: Bool

    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 12
        var p = Path()
        if !isFolder {
            p.addRoundedRect(in: rect, cornerSize: CGSize(width: r, height: r), style: .continuous)
            return p
        }
        let tabWidth = rect.width * 0.38
        let tabHeight: CGFloat = 16
        let bodyTop = rect.minY + tabHeight
        p.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + tabWidth - 10, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX + tabWidth + 6, y: bodyTop), control: CGPoint(x: rect.minX + tabWidth, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: bodyTop))
        p.addArc(center: CGPoint(x: rect.maxX - r, y: bodyTop + r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        return p
    }
}
