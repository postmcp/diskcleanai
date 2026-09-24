import Foundation

struct VolumeInfo: Hashable, Identifiable {
    let url: URL
    let name: String
    let totalCapacity: Int64
    let availableCapacity: Int64
    let isRoot: Bool
    let isRemovable: Bool

    var id: String { url.path }
    var usedCapacity: Int64 { max(totalCapacity - availableCapacity, 0) }
    var usedFraction: Double { totalCapacity > 0 ? Double(usedCapacity) / Double(totalCapacity) : 0 }

    /// The same volume with `bytes` counted as already free. Moving a file to the
    /// Trash does not release space until the Trash is emptied, so the sidebar shows
    /// what the disk *will* look like rather than a number that never moves.
    func reclaiming(_ bytes: Int64) -> VolumeInfo {
        guard bytes > 0 else { return self }
        return VolumeInfo(url: url, name: name, totalCapacity: totalCapacity,
                          availableCapacity: min(availableCapacity + bytes, totalCapacity),
                          isRoot: isRoot, isRemovable: isRemovable)
    }

    static func load(for url: URL) -> VolumeInfo {
        let keys: Set<URLResourceKey> = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey, .volumeIsRootFileSystemKey, .volumeIsRemovableKey, .volumeURLKey]
        let values = try? url.resourceValues(forKeys: keys)
        let available = values?.volumeAvailableCapacityForImportantUsage ?? Int64(values?.volumeAvailableCapacity ?? 0)
        return VolumeInfo(
            url: values?.volume ?? url,
            name: values?.volumeName ?? url.lastPathComponent,
            totalCapacity: Int64(values?.volumeTotalCapacity ?? 0),
            availableCapacity: available,
            isRoot: values?.volumeIsRootFileSystem ?? (url.path == "/"),
            isRemovable: values?.volumeIsRemovable ?? false)
    }

    static func mounted() -> [VolumeInfo] {
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeNameKey], options: [.skipHiddenVolumes]) ?? []
        return urls
            .filter { !$0.path.hasPrefix("/System/Volumes") }
            .map(load(for:))
            .filter { $0.totalCapacity > 0 }
            .sorted { $0.isRoot && !$1.isRoot }
    }
}

/// A ready-made cleanup opportunity surfaced in the sidebar.
struct QuickWin: Identifiable, Hashable {
    let id: String
    let label: String
    let systemImage: String
    let nodes: [FileNode]
    let bytes: Int64
    let chartIndex: Int

    var count: Int { nodes.count }
}

/// Immutable result of one completed scan plus derived lists the views need.
struct ScanSnapshot {
    let root: FileNode
    let rootURL: URL
    let volume: VolumeInfo
    let scannedAt: Date
    let duration: TimeInterval
    let fileCount: Int
    let directoryCount: Int
    let categoryTotals: [FileCategory: Int64]
    /// Every file at or above 10 MB, largest first (capped).
    let largeFiles: [FileNode]
    /// Directories that were skipped because they could not be read.
    let unreadableCount: Int
    let quickWins: [QuickWin]

    var totalSize: Int64 { root.size }

    var isWholeVolume: Bool { rootURL.path == volume.url.path }

    /// Percentage of the *scanned* bytes per category, ordered by size.
    var categoryBreakdown: [(category: FileCategory, bytes: Int64, fraction: Double)] {
        let total = max(Double(totalSize), 1)
        return categoryTotals
            .map { ($0.key, $0.value, Double($0.value) / total) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
    }

    static func build(root: FileNode, rootURL: URL, duration: TimeInterval, largeFileFloor: Int64 = 10 * 1_048_576) -> ScanSnapshot {
        var totals: [FileCategory: Int64] = [:]
        var large: [FileNode] = []
        var files = 0
        var dirs = 0
        var unreadable = 0
        var nodeModules: [FileNode] = []
        var buildDirs: [FileNode] = []
        var media: [FileNode] = []
        let buildNames: Set<String> = ["build", ".build", "target", "dist", ".next", ".nuxt", "Pods", ".gradle", "out"]
        root.forEachNode { node in
            if node.isFile {
                files += 1
                totals[node.category, default: 0] += node.size
                if node.size >= largeFileFloor { large.append(node) }
                if node.size >= 100 * 1_048_576, [.video, .audio, .photos].contains(node.category) { media.append(node) }
            } else {
                dirs += 1
                if node.unreadable { unreadable += 1 }
                if node.name == "node_modules" { nodeModules.append(node) }
                else if buildNames.contains(node.name), node.size > 1_048_576, node.parent?.name != "node_modules" { buildDirs.append(node) }
            }
        }
        large.sort { $0.size > $1.size }
        if large.count > 5000 { large.removeLast(large.count - 5000) }
        media.sort { $0.size > $1.size }

        // Drop nested matches so a win is counted once.
        func outermost(_ nodes: [FileNode]) -> [FileNode] {
            let ids = Set(nodes.map(\.id))
            return nodes.filter { node in
                var p = node.parent
                while let n = p { if ids.contains(n.id) { return false }; p = n.parent }
                return true
            }.sorted { $0.size > $1.size }
        }
        let home = SafetyPolicy.home
        func children(of path: String, minBytes: Int64 = 1_048_576) -> [FileNode] {
            (root.node(atPath: path)?.children ?? []).filter { $0.size >= minBytes }.sorted { $0.size > $1.size }
        }
        var wins: [QuickWin] = []
        func add(_ id: String, _ label: String, _ icon: String, _ nodes: [FileNode], _ chart: Int) {
            let bytes = nodes.reduce(0) { $0 + $1.size }
            if !nodes.isEmpty, bytes > 0 { wins.append(QuickWin(id: id, label: label, systemImage: icon, nodes: nodes, bytes: bytes, chartIndex: chart)) }
        }
        add("downloads", "Downloads", "arrow.down.circle", children(of: home + "/Downloads", minBytes: 0), 4)
        add("caches", "Caches & logs", "internaldrive", children(of: home + "/Library/Caches") + children(of: home + "/Library/Logs"), 7)
        add("simulators", "iOS Simulators", "iphone", [root.node(atPath: home + "/Library/Developer/CoreSimulator/Devices"), root.node(atPath: home + "/Library/Developer/CoreSimulator/Caches")].compactMap { $0 }, 2)
        add("media", "Large media", "film", Array(media.prefix(400)), 0)
        add("node_modules", "node_modules", "shippingbox", outermost(nodeModules), 6)
        add("build", "Build artifacts", "hammer", outermost(buildDirs), 6)
        add("derived", "Xcode DerivedData", "wrench.and.screwdriver", children(of: home + "/Library/Developer/Xcode/DerivedData"), 1)
        add("trash", "Trash", "trash", (root.node(atPath: home + "/.Trash")?.children ?? []).sorted { $0.size > $1.size }, 5)
        wins.sort { $0.bytes > $1.bytes }

        return ScanSnapshot(root: root, rootURL: rootURL, volume: VolumeInfo.load(for: rootURL), scannedAt: Date(),
                            duration: duration, fileCount: files, directoryCount: dirs, categoryTotals: totals,
                            largeFiles: large, unreadableCount: unreadable, quickWins: wins)
    }
}
