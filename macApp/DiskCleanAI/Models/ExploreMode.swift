import SwiftUI

/// The visual patterns the Explore screen can draw the same scan in.
enum ExploreMode: String, CaseIterable, Identifiable, Codable {
    case folders, sunburst, treemap, bubbles, mindMap, icicle, topSizes, ageMap, list

    var id: String { rawValue }

    var title: String {
        switch self {
        case .folders: return "Folders"
        case .sunburst: return "Sunburst"
        case .treemap: return "Treemap"
        case .bubbles: return "Bubbles"
        case .mindMap: return "Mind Map"
        case .icicle: return "Icicle"
        case .topSizes: return "Top Sizes"
        case .ageMap: return "Age Map"
        case .list: return "List"
        }
    }

    var systemImage: String {
        switch self {
        case .folders: return "folder"
        case .sunburst: return "circle.circle"
        case .treemap: return "rectangle.split.2x2"
        case .bubbles: return "circle.hexagongrid"
        case .mindMap: return "point.3.connected.trianglepath.dotted"
        case .icicle: return "rectangle.split.3x1"
        case .topSizes: return "chart.bar"
        case .ageMap: return "calendar"
        case .list: return "list.bullet.rectangle"
        }
    }

    var blurb: String {
        switch self {
        case .folders: return "Browse folder by folder, sized as you go"
        case .sunburst: return "Rings radiating out from the focused folder"
        case .treemap: return "Every item is a rectangle sized by bytes"
        case .bubbles: return "Nested bubbles, one per folder"
        case .mindMap: return "Branches from the root, sized by weight"
        case .icicle: return "Layers from the root down, widest wins"
        case .topSizes: return "The biggest items, ranked"
        case .ageMap: return "Where your bytes sit on a timeline"
        case .list: return "Outline of every folder with sizes and dates"
        }
    }

    /// Modes that draw nested levels and honour the depth slider.
    var usesDepth: Bool { self == .sunburst || self == .icicle || self == .mindMap }
    var usesColorMode: Bool { self != .topSizes && self != .ageMap && self != .list }
}

/// How nodes are coloured in the graphical patterns.
enum ColorMode: String, CaseIterable, Identifiable, Codable {
    case byType, byFolder, byAge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .byType: return "By type"
        case .byFolder: return "By folder"
        case .byAge: return "By age"
        }
    }

    var systemImage: String {
        switch self {
        case .byType: return "tag"
        case .byFolder: return "folder"
        case .byAge: return "clock"
        }
    }
}

/// Resolves a node to a colour for the current focus, mode and theme.
struct NodeColorer {
    let theme: Theme
    let mode: ColorMode
    let focus: FileNode

    static let ageBucketLabels = ["Last 7 days", "8–30 days", "1–3 months", "3–12 months", "1–2 years", "Over 2 years"]

    static func ageBucket(_ date: Date?) -> Int {
        guard let date else { return 5 }
        let days = Date().timeIntervalSince(date) / 86_400
        switch days {
        case ..<7: return 0
        case ..<30: return 1
        case ..<90: return 2
        case ..<365: return 3
        case ..<730: return 4
        default: return 5
        }
    }

    func ageColor(bucket: Int) -> Color {
        switch bucket {
        case 0: return theme.success
        case 1: return theme.chartColor(3)
        case 2: return theme.brand
        case 3: return theme.chartColor(6)
        case 4: return theme.chartColor(4)
        default: return theme.danger
        }
    }

    /// Base colour before depth shading.
    func color(for node: FileNode) -> Color {
        switch mode {
        case .byType:
            return theme.color(for: node.dominantCategory)
        case .byFolder:
            let top = node.child(under: focus) ?? node
            let index = focus.children.firstIndex(where: { $0 === top }) ?? 0
            return theme.chartColor(index)
        case .byAge:
            return ageColor(bucket: Self.ageBucket(node.modified))
        }
    }

    /// Lighter with depth so nested rings and rectangles stay readable.
    func color(for node: FileNode, depth: Int) -> Color {
        color(for: node).mixed(with: theme.card, amount: min(0.16 * Double(max(depth - 1, 0)), 0.6))
    }

    /// Legend entries for the current mode.
    var legend: [(label: String, color: Color)] {
        switch mode {
        case .byType:
            return FileCategory.allCases.map { ($0.label, theme.color(for: $0)) }
        case .byFolder:
            return focus.children.prefix(8).enumerated().map { ($0.element.name, theme.chartColor($0.offset)) }
        case .byAge:
            return Self.ageBucketLabels.enumerated().map { ($0.element, ageColor(bucket: $0.offset)) }
        }
    }
}
