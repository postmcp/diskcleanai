import SwiftUI

struct IcicleCell: Identifiable {
    let node: FileNode
    let rect: CGRect
    let depth: Int
    var id: ObjectIdentifier { node.id }
}

enum IcicleLayout {
    static func cells(focus: FileNode, depth: Int, in size: CGSize) -> [IcicleCell] {
        let rowHeight = size.height / CGFloat(depth + 1)
        var out: [IcicleCell] = [IcicleCell(node: focus, rect: CGRect(x: 0, y: 0, width: size.width, height: rowHeight), depth: 0)]
        func place(_ node: FileNode, level: Int, x: CGFloat, width: CGFloat) {
            guard level <= depth, node.isContainer, node.size > 0 else { return }
            var cursor = x
            for child in node.children where !child.removed {
                let w = width * CGFloat(Double(child.size) / Double(node.size))
                if w < 1.5 { break }
                out.append(IcicleCell(node: child, rect: CGRect(x: cursor, y: rowHeight * CGFloat(level), width: w, height: rowHeight), depth: level))
                place(child, level: level + 1, x: cursor, width: w)
                cursor += w
            }
        }
        place(focus, level: 1, x: 0, width: size.width)
        return out
    }
}

struct IcicleView: View {
    @Environment(\.theme) private var theme
    @Environment(AppState.self) private var appState
    let focus: FileNode
    let colorer: NodeColorer
    let depth: Int
    @State private var hovered: FileNode?
    @State private var hoverPoint: CGPoint = .zero

    var body: some View {
        GeometryReader { geo in
            let cells = IcicleLayout.cells(focus: focus, depth: depth, in: geo.size)
            ZStack {
                Canvas { context, _ in
                    for cell in cells {
                        let rect = cell.rect.insetBy(dx: 0.75, dy: 1.5)
                        guard rect.width > 0 else { continue }
                        let path = Path(roundedRect: rect, cornerRadius: 4)
                        let color = cell.depth == 0 ? theme.ink : colorer.color(for: cell.node, depth: cell.depth)
                        let dim = hovered != nil && cell.depth > 0 && hovered !== cell.node && !isRelated(cell.node, hovered)
                        context.fill(path, with: .color(dim ? color.opacity(0.4) : color))
                        if appState.selectedNode === cell.node || hovered === cell.node {
                            context.stroke(path, with: .color(theme.ink), lineWidth: 1.5)
                        }
                        if rect.width > 44 {
                            let fg = cell.depth == 0 ? theme.background : theme.ink
                            let name = Text(cell.depth == 0 ? cell.node.displayName : cell.node.name).font(.system(size: 11, weight: .semibold)).foregroundColor(fg)
                            context.draw(name, in: CGRect(x: rect.minX + 6, y: rect.minY + 4, width: rect.width - 12, height: 14))
                            if rect.height > 34 {
                                let size = Text(Format.bytes(cell.node.size)).font(.system(size: 10)).foregroundColor(cell.depth == 0 ? theme.background.opacity(0.8) : theme.body)
                                context.draw(size, in: CGRect(x: rect.minX + 6, y: rect.minY + 19, width: rect.width - 12, height: 13))
                            }
                        }
                    }
                }
                .modifier(CanvasInteraction { point in
                    guard let node = cells.last(where: { $0.rect.contains(point) })?.node else { return nil }
                    return node === focus ? focus.parent : node
                })
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let p): hoverPoint = p; hovered = cells.last { $0.rect.contains(p) && $0.depth > 0 }?.node
                    case .ended: hovered = nil
                    }
                }
                if let hovered {
                    NodeTooltip(node: hovered, focus: focus).position(NodeTooltip.clamp(hoverPoint, in: geo.size))
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(theme.line))
    }

    private func isRelated(_ a: FileNode, _ b: FileNode?) -> Bool {
        guard let b else { return false }
        var n: FileNode? = a
        while let cur = n { if cur === b { return true }; n = cur.parent }
        n = b
        while let cur = n { if cur === a { return true }; n = cur.parent }
        return false
    }
}
