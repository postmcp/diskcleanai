import SwiftUI

struct SunburstArc: Identifiable {
    let node: FileNode
    let depth: Int
    let start: Double
    let end: Double

    var id: ObjectIdentifier { node.id }
    var span: Double { end - start }
}

enum SunburstLayout {
    /// Angles are radians, 0 at 12 o'clock, increasing clockwise.
    static func arcs(focus: FileNode, rings: Int, minAngle: Double = 0.0045) -> [SunburstArc] {
        var out: [SunburstArc] = []
        func place(_ node: FileNode, depth: Int, start: Double, end: Double) {
            guard depth <= rings, node.isContainer, node.size > 0 else { return }
            var cursor = start
            let span = end - start
            for child in node.children where !child.removed {
                let angle = span * Double(child.size) / Double(node.size)
                if angle < minAngle { break } // children are sorted largest first
                out.append(SunburstArc(node: child, depth: depth, start: cursor, end: cursor + angle))
                place(child, depth: depth + 1, start: cursor, end: cursor + angle)
                cursor += angle
            }
        }
        place(focus, depth: 1, start: 0, end: 2 * .pi)
        return out
    }
}

/// Interactive sunburst. Hover to inspect, click to select, double-click a ring to zoom in, click the centre to zoom out.
struct SunburstView: View {
    @Environment(\.theme) private var theme
    let focus: FileNode
    let rings: Int
    let colorer: NodeColorer
    var selected: FileNode?
    let onSelect: (FileNode?) -> Void
    let onFocus: (FileNode) -> Void

    @State private var hovered: FileNode?
    @State private var hoverPoint: CGPoint = .zero

    var body: some View {
        GeometryReader { geo in
            let arcs = SunburstLayout.arcs(focus: focus, rings: rings)
            let side = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let outerRadius = side / 2 - 4
            let holeRadius = outerRadius * 0.28
            let ringWidth = (outerRadius - holeRadius) / CGFloat(rings)

            ZStack {
                Canvas { context, _ in
                    for arc in arcs {
                        let inner = holeRadius + ringWidth * CGFloat(arc.depth - 1) + 1
                        let outer = inner + ringWidth - 2
                        let path = Self.path(center: center, inner: inner, outer: outer, start: arc.start, end: arc.end)
                        let shade = colorer.color(for: arc.node, depth: arc.depth)
                        let dimmed = hovered != nil && hovered !== arc.node && !isAncestor(arc.node, of: hovered)
                        context.fill(path, with: .color(dimmed ? shade.opacity(0.45) : shade))
                        if hovered === arc.node || selected === arc.node {
                            context.stroke(path, with: .color(theme.ink), lineWidth: 1.5)
                        }
                    }
                }
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let point):
                        hoverPoint = point
                        hovered = hitTest(point, arcs: arcs, center: center, hole: holeRadius, ringWidth: ringWidth)
                    case .ended:
                        hovered = nil
                    }
                }
                .onTapGesture(count: 2) { location in
                    if let hit = hitTest(location, arcs: arcs, center: center, hole: holeRadius, ringWidth: ringWidth) { onFocus(hit) }
                }
                .onTapGesture(count: 1) { location in
                    let dx = location.x - center.x, dy = location.y - center.y
                    if hypot(dx, dy) < holeRadius {
                        if let parent = focus.parent { onFocus(parent) }
                    } else {
                        onSelect(hitTest(location, arcs: arcs, center: center, hole: holeRadius, ringWidth: ringWidth))
                    }
                }

                VStack(spacing: 2) {
                    Text(Format.bytes(focus.size))
                        .font(.system(size: holeRadius * 0.34, weight: .bold))
                        .tracking(-0.6)
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(focus.parent == nil ? "Total scanned" : focus.name)
                        .font(.system(size: max(holeRadius * 0.16, 10), weight: .medium))
                        .foregroundStyle(theme.muted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if focus.parent != nil {
                        Image(systemName: "arrow.up.circle")
                            .font(.system(size: 13))
                            .foregroundStyle(theme.muted)
                            .padding(.top, 2)
                    }
                }
                .frame(width: holeRadius * 1.7)
                .allowsHitTesting(false)

                if let hovered {
                    NodeTooltip(node: hovered, focus: focus)
                        .position(NodeTooltip.clamp(hoverPoint, in: geo.size))
                }
            }
        }
    }

    private func isAncestor(_ candidate: FileNode, of node: FileNode?) -> Bool {
        var n = node?.parent
        while let cur = n {
            if cur === candidate { return true }
            n = cur.parent
        }
        return false
    }

    private func hitTest(_ point: CGPoint, arcs: [SunburstArc], center: CGPoint, hole: CGFloat, ringWidth: CGFloat) -> FileNode? {
        let dx = point.x - center.x, dy = point.y - center.y
        let r = hypot(dx, dy)
        guard r >= hole, ringWidth > 0 else { return nil }
        let depth = Int((r - hole) / ringWidth) + 1
        guard depth <= rings else { return nil }
        var angle = atan2(dy, dx) + .pi / 2
        if angle < 0 { angle += 2 * .pi }
        return arcs.first { $0.depth == depth && angle >= $0.start && angle < $0.end }?.node
    }

    /// Annular sector built from line segments so it is independent of the platform's arc direction quirks.
    static func path(center: CGPoint, inner: CGFloat, outer: CGFloat, start: Double, end: Double) -> Path {
        var path = Path()
        let steps = max(2, Int((end - start) / 0.035) + 1)
        func point(_ radius: CGFloat, _ angle: Double) -> CGPoint {
            CGPoint(x: center.x + radius * CGFloat(sin(angle)), y: center.y - radius * CGFloat(cos(angle)))
        }
        path.move(to: point(outer, start))
        for i in 1...steps {
            path.addLine(to: point(outer, start + (end - start) * Double(i) / Double(steps)))
        }
        for i in stride(from: steps, through: 0, by: -1) {
            path.addLine(to: point(inner, start + (end - start) * Double(i) / Double(steps)))
        }
        path.closeSubpath()
        return path
    }
}
