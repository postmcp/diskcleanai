import SwiftUI

struct TreemapCell: Identifiable {
    let node: FileNode
    let rect: CGRect
    let depth: Int
    var id: ObjectIdentifier { node.id }
}

enum TreemapLayout {
    /// Squarified treemap of `nodes` (sorted largest first) inside `rect`.
    static func squarify(_ nodes: [FileNode], in rect: CGRect) -> [(FileNode, CGRect)] {
        let items = nodes.filter { $0.size > 0 && !$0.removed }
        let total = items.reduce(0.0) { $0 + Double($1.size) }
        guard total > 0, rect.width > 1, rect.height > 1 else { return [] }
        let scale = Double(rect.width * rect.height) / total
        let areas = items.map { Double($0.size) * scale }
        var result: [(FileNode, CGRect)] = []
        var remaining = rect
        var i = 0
        while i < areas.count, remaining.width > 0.5, remaining.height > 0.5 {
            let side = Double(min(remaining.width, remaining.height))
            var row = [i]
            var rowArea = areas[i]
            var worst = worstRatio([areas[i]], side)
            var j = i + 1
            while j < areas.count {
                let candidate = worstRatio(row.map { areas[$0] } + [areas[j]], side)
                if candidate <= worst { row.append(j); rowArea += areas[j]; worst = candidate; j += 1 } else { break }
            }
            if remaining.width >= remaining.height {
                let strip = CGFloat(rowArea / Double(remaining.height))
                var y = remaining.minY
                for k in row {
                    let h = CGFloat(areas[k] / Double(strip))
                    result.append((items[k], CGRect(x: remaining.minX, y: y, width: strip, height: h)))
                    y += h
                }
                remaining = CGRect(x: remaining.minX + strip, y: remaining.minY, width: remaining.width - strip, height: remaining.height)
            } else {
                let strip = CGFloat(rowArea / Double(remaining.width))
                var x = remaining.minX
                for k in row {
                    let w = CGFloat(areas[k] / Double(strip))
                    result.append((items[k], CGRect(x: x, y: remaining.minY, width: w, height: strip)))
                    x += w
                }
                remaining = CGRect(x: remaining.minX, y: remaining.minY + strip, width: remaining.width, height: remaining.height - strip)
            }
            i = j
        }
        return result
    }

    private static func worstRatio(_ areas: [Double], _ side: Double) -> Double {
        let sum = areas.reduce(0, +)
        guard sum > 0, side > 0, let maxA = areas.max(), let minA = areas.min(), minA > 0 else { return .infinity }
        let s2 = side * side
        return max(s2 * maxA / (sum * sum), sum * sum / (s2 * minA))
    }

    /// Two-level layout: the focus's children, each subdivided when it has room.
    static func cells(focus: FileNode, in rect: CGRect) -> [TreemapCell] {
        var out: [TreemapCell] = []
        for (node, r) in squarify(Array(focus.children.prefix(120)), in: rect) {
            out.append(TreemapCell(node: node, rect: r, depth: 1))
            if node.isContainer, r.width > 70, r.height > 50 {
                let inner = r.insetBy(dx: 4, dy: 4).offsetBy(dx: 0, dy: 9).insetBy(dx: 0, dy: 9).offsetBy(dx: 0, dy: -0)
                let innerRect = CGRect(x: r.minX + 4, y: r.minY + 22, width: r.width - 8, height: max(r.height - 26, 0))
                _ = inner
                for (child, cr) in squarify(Array(node.children.prefix(14)), in: innerRect) where cr.width > 3 && cr.height > 3 {
                    out.append(TreemapCell(node: child, rect: cr, depth: 2))
                }
            }
        }
        return out
    }
}

struct TreemapView: View {
    @Environment(\.theme) private var theme
    @Environment(AppState.self) private var appState
    let focus: FileNode
    let colorer: NodeColorer
    @State private var hovered: FileNode?
    @State private var hoverPoint: CGPoint = .zero

    var body: some View {
        GeometryReader { geo in
            let cells = TreemapLayout.cells(focus: focus, in: CGRect(origin: .zero, size: geo.size))
            ZStack {
                Canvas { context, _ in
                    for cell in cells {
                        let rect = cell.rect.insetBy(dx: 1, dy: 1)
                        guard rect.width > 0, rect.height > 0 else { continue }
                        let path = Path(roundedRect: rect, cornerRadius: cell.depth == 1 ? 6 : 3)
                        let color = colorer.color(for: cell.node, depth: cell.depth)
                        let dim = hovered != nil && hovered !== cell.node && cell.node.parent !== hovered
                        context.fill(path, with: .color(dim ? color.opacity(0.5) : color))
                        if appState.selectedNode === cell.node || hovered === cell.node {
                            context.stroke(path, with: .color(theme.ink), lineWidth: 1.5)
                        }
                        if cell.depth == 1, rect.width > 56, rect.height > 22 {
                            let label = Text(cell.node.name).font(.system(size: 11.5, weight: .semibold)).foregroundColor(theme.ink)
                            context.draw(label, in: CGRect(x: rect.minX + 7, y: rect.minY + 4, width: rect.width - 14, height: 16))
                            if rect.height > 40 && rect.width > 90 {
                                let size = Text(Format.bytes(cell.node.size)).font(.system(size: 10.5)).foregroundColor(theme.body)
                                context.draw(size, in: CGRect(x: rect.minX + 7, y: rect.maxY - 18, width: rect.width - 14, height: 14))
                            }
                        } else if cell.depth == 2, rect.width > 60, rect.height > 16 {
                            let label = Text(cell.node.name).font(.system(size: 10)).foregroundColor(theme.ink.opacity(0.85))
                            context.draw(label, in: CGRect(x: rect.minX + 4, y: rect.minY + 2, width: rect.width - 8, height: 13))
                        }
                    }
                }
                .modifier(CanvasInteraction { point in hit(point, cells) })
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let p): hoverPoint = p; hovered = hit(p, cells)
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

    private func hit(_ point: CGPoint, _ cells: [TreemapCell]) -> FileNode? {
        cells.last { $0.rect.contains(point) }?.node
    }
}
