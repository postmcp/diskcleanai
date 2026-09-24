import SwiftUI

struct MindMapNode: Identifiable {
    let node: FileNode
    let point: CGPoint
    let radius: CGFloat
    let depth: Int
    let parentPoint: CGPoint?
    var id: ObjectIdentifier { node.id }
}

enum MindMapLayout {
    static func layout(focus: FileNode, depth maxDepth: Int, in size: CGSize) -> [MindMapNode] {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let base = min(size.width, size.height) / 2 - 24
        var out: [MindMapNode] = []
        let levels = max(min(maxDepth, 4), 1)
        func radiusFor(_ node: FileNode) -> CGFloat {
            let share = focus.size > 0 ? Double(node.size) / Double(focus.size) : 0
            return CGFloat(4 + 28 * sqrt(share))
        }
        func place(_ node: FileNode, depth: Int, start: Double, end: Double, parentPoint: CGPoint, limit: Int) {
            guard depth <= levels, node.isContainer, node.size > 0 else { return }
            let children = Array(node.children.filter { !$0.removed }.prefix(limit))
            let total = children.reduce(0.0) { $0 + Double($1.size) }
            guard total > 0 else { return }
            let ring = base * CGFloat(depth) / CGFloat(levels)
            var cursor = start
            for child in children {
                let span = (end - start) * Double(child.size) / total
                let angle = cursor + span / 2
                let p = CGPoint(x: center.x + ring * CGFloat(sin(angle)), y: center.y - ring * CGFloat(cos(angle)))
                out.append(MindMapNode(node: child, point: p, radius: radiusFor(child), depth: depth, parentPoint: parentPoint))
                if span > 0.05 {
                    place(child, depth: depth + 1, start: cursor, end: cursor + span, parentPoint: p, limit: max(3, limit / 2))
                }
                cursor += span
            }
        }
        place(focus, depth: 1, start: 0, end: 2 * .pi, parentPoint: center, limit: 18)
        return out
    }
}

struct MindMapView: View {
    @Environment(\.theme) private var theme
    @Environment(AppState.self) private var appState
    let focus: FileNode
    let colorer: NodeColorer
    let depth: Int
    @State private var hovered: FileNode?
    @State private var hoverPoint: CGPoint = .zero

    var body: some View {
        GeometryReader { geo in
            let nodes = MindMapLayout.layout(focus: focus, depth: depth, in: geo.size)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                Canvas { context, _ in
                    for n in nodes {
                        guard let from = n.parentPoint else { continue }
                        var path = Path()
                        path.move(to: from)
                        let control = CGPoint(x: (from.x + n.point.x) / 2 + (n.point.y - from.y) * 0.15, y: (from.y + n.point.y) / 2 - (n.point.x - from.x) * 0.15)
                        path.addQuadCurve(to: n.point, control: control)
                        context.stroke(path, with: .color(colorer.color(for: n.node).opacity(0.45)), lineWidth: max(0.6, n.radius / 8))
                    }
                    for n in nodes {
                        let color = colorer.color(for: n.node, depth: n.depth)
                        let rect = CGRect(x: n.point.x - n.radius, y: n.point.y - n.radius, width: n.radius * 2, height: n.radius * 2)
                        context.fill(Path(ellipseIn: rect), with: .color(color))
                        if appState.selectedNode === n.node || hovered === n.node {
                            context.stroke(Path(ellipseIn: rect.insetBy(dx: -2, dy: -2)), with: .color(theme.ink), lineWidth: 1.5)
                        }
                        if n.depth == 1 || n.radius > 7 {
                            let name = Text(n.node.name).font(.system(size: n.depth == 1 ? 11.5 : 10, weight: n.depth == 1 ? .semibold : .medium)).foregroundColor(theme.ink)
                            context.draw(name, at: CGPoint(x: n.point.x, y: n.point.y - n.radius - 9))
                            if n.depth == 1 {
                                let size = Text(Format.bytes(n.node.size)).font(.system(size: 9.5)).foregroundColor(theme.muted)
                                context.draw(size, at: CGPoint(x: n.point.x, y: n.point.y + n.radius + 8))
                            }
                        }
                    }
                    let hub = CGRect(x: center.x - 44, y: center.y - 44, width: 88, height: 88)
                    context.fill(Path(ellipseIn: hub), with: .color(theme.ink))
                    context.draw(Text(focus.displayName).font(.system(size: 11.5, weight: .semibold)).foregroundColor(theme.background), at: CGPoint(x: center.x, y: center.y - 8))
                    context.draw(Text(Format.bytes(focus.size)).font(.system(size: 13, weight: .bold)).foregroundColor(theme.background), at: CGPoint(x: center.x, y: center.y + 9))
                }
                .modifier(CanvasInteraction { point in
                    if hypot(point.x - center.x, point.y - center.y) < 44 { return focus.parent }
                    return hit(point, nodes)
                })
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let p): hoverPoint = p; hovered = hit(p, nodes)
                    case .ended: hovered = nil
                    }
                }
                if let hovered {
                    NodeTooltip(node: hovered, focus: focus).position(NodeTooltip.clamp(hoverPoint, in: geo.size))
                }
            }
        }
    }

    private func hit(_ p: CGPoint, _ nodes: [MindMapNode]) -> FileNode? {
        nodes.filter { hypot(p.x - $0.point.x, p.y - $0.point.y) <= max($0.radius, 8) }.min { $0.radius < $1.radius }?.node
    }
}
