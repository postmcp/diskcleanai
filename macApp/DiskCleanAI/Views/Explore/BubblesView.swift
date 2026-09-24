import SwiftUI

struct PackedCircle: Identifiable {
    let node: FileNode
    var x: Double
    var y: Double
    var r: Double
    let depth: Int
    var id: ObjectIdentifier { node.id }
}

enum CirclePacking {
    /// Greedy packing: each circle (largest first) is placed tangent to an existing one, as close to the centre as possible.
    static func pack(_ nodes: [FileNode], gap: Double = 0.02) -> [(FileNode, Double, Double, Double)] {
        let items = nodes.filter { $0.size > 0 && !$0.removed }
        guard !items.isEmpty else { return [] }
        var placed: [(FileNode, Double, Double, Double)] = []
        for node in items {
            let r = sqrt(Double(node.size))
            if placed.isEmpty { placed.append((node, 0, 0, r)); continue }
            var best: (Double, Double)?
            var bestDist = Double.infinity
            for (_, cx, cy, cr) in placed {
                let d = cr + r + gap * r
                for step in 0..<48 {
                    let a = Double(step) / 48 * 2 * .pi
                    let x = cx + d * cos(a), y = cy + d * sin(a)
                    let dist = x * x + y * y
                    if dist >= bestDist { continue }
                    var ok = true
                    for (_, px, py, pr) in placed where hypot(x - px, y - py) < pr + r - 0.001 { ok = false; break }
                    if ok { best = (x, y); bestDist = dist }
                }
            }
            if let best { placed.append((node, best.0, best.1, r)) } else { placed.append((node, 0, 0, r)) }
        }
        return placed
    }

    /// Layout the focus's children inside a circle, then nest each container's top children.
    static func layout(focus: FileNode, in size: CGSize) -> [PackedCircle] {
        let packed = pack(Array(focus.children.prefix(60)))
        guard !packed.isEmpty else { return [] }
        let bound = packed.map { hypot($0.1, $0.2) + $0.3 }.max() ?? 1
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let scale = Double(min(size.width, size.height) / 2 - 8) / bound
        var out: [PackedCircle] = []
        for (node, x, y, r) in packed {
            let c = PackedCircle(node: node, x: Double(center.x) + x * scale, y: Double(center.y) + y * scale, r: r * scale, depth: 1)
            out.append(c)
            if node.isContainer, c.r > 26 {
                let inner = pack(Array(node.children.prefix(12)))
                let innerBound = inner.map { hypot($0.1, $0.2) + $0.3 }.max() ?? 1
                let innerScale = c.r * 0.82 / innerBound
                for (child, ix, iy, ir) in inner where ir * innerScale > 2.5 {
                    out.append(PackedCircle(node: child, x: c.x + ix * innerScale, y: c.y + iy * innerScale + Double(c.r > 60 ? 6 : 0), r: ir * innerScale, depth: 2))
                }
            }
        }
        return out
    }
}

struct BubblesView: View {
    @Environment(\.theme) private var theme
    @Environment(AppState.self) private var appState
    let focus: FileNode
    let colorer: NodeColorer
    @State private var hovered: FileNode?
    @State private var hoverPoint: CGPoint = .zero

    var body: some View {
        GeometryReader { geo in
            let circles = CirclePacking.layout(focus: focus, in: geo.size)
            ZStack {
                Canvas { context, size in
                    let outer = Path(ellipseIn: CGRect(x: size.width / 2 - min(size.width, size.height) / 2 + 2, y: size.height / 2 - min(size.width, size.height) / 2 + 2,
                                                       width: min(size.width, size.height) - 4, height: min(size.width, size.height) - 4))
                    context.stroke(outer, with: .color(theme.line), lineWidth: 1)
                    let title = Text(focus.displayName).font(.system(size: 14, weight: .semibold)).foregroundColor(theme.ink)
                    context.draw(title, at: CGPoint(x: size.width / 2, y: size.height / 2 - min(size.width, size.height) / 2 + 16))
                    for c in circles {
                        let rect = CGRect(x: c.x - c.r, y: c.y - c.r, width: c.r * 2, height: c.r * 2)
                        let color = colorer.color(for: c.node, depth: c.depth)
                        let dim = hovered != nil && hovered !== c.node && c.node.parent !== hovered
                        context.fill(Path(ellipseIn: rect), with: .color((dim ? color.opacity(0.35) : color.opacity(c.depth == 1 ? 0.55 : 0.85))))
                        context.stroke(Path(ellipseIn: rect), with: .color(appState.selectedNode === c.node || hovered === c.node ? theme.ink : color.opacity(0.7)), lineWidth: appState.selectedNode === c.node ? 2 : 1)
                        if c.depth == 1, c.r > 22 {
                            let label = Text(c.node.name).font(.system(size: min(14, max(10, c.r / 5)), weight: .semibold)).foregroundColor(theme.ink)
                            context.draw(label, in: CGRect(x: c.x - c.r * 0.9, y: c.y - c.r + (c.r > 60 ? 8 : c.r - 8), width: c.r * 1.8, height: 16))
                        } else if c.depth == 2, c.r > 18 {
                            let label = Text(c.node.name).font(.system(size: 10, weight: .medium)).foregroundColor(theme.ink)
                            context.draw(label, in: CGRect(x: c.x - c.r * 0.9, y: c.y - 7, width: c.r * 1.8, height: 14))
                        }
                    }
                }
                .modifier(CanvasInteraction { point in hit(point, circles) })
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let p): hoverPoint = p; hovered = hit(p, circles)
                    case .ended: hovered = nil
                    }
                }
                if let hovered {
                    NodeTooltip(node: hovered, focus: focus).position(NodeTooltip.clamp(hoverPoint, in: geo.size))
                }
            }
        }
    }

    private func hit(_ p: CGPoint, _ circles: [PackedCircle]) -> FileNode? {
        circles.last { hypot(Double(p.x) - $0.x, Double(p.y) - $0.y) <= $0.r }?.node
    }
}
