import Foundation

/// One entry of the scanned tree. Reference type so a million nodes can share
/// structure cheaply; identity is the object itself.
final class FileNode: Identifiable, Hashable, @unchecked Sendable {
    enum Kind: UInt8 {
        case file, directory, package, symlink
    }

    let name: String
    let kind: Kind
    var size: Int64
    /// Bytes before filesystem compression; equals `size` for folders until finalized.
    var logicalSize: Int64
    var modified: Date?
    var accessed: Date?
    var category: FileCategory
    var fileCount: Int
    var dirCount: Int
    var children: [FileNode]
    weak var parent: FileNode?
    /// Present on directories: bytes per `FileCategory` so the sunburst can colour
    /// a folder by what dominates it.
    var categoryBytes: [Int64]?
    /// Set when the directory could not be listed (permissions).
    var unreadable = false
    /// Set when the node has been trashed by the cleanup flow.
    var removed = false

    init(name: String, kind: Kind, size: Int64 = 0, logicalSize: Int64? = nil, modified: Date? = nil, accessed: Date? = nil,
         category: FileCategory = .other, children: [FileNode] = []) {
        self.name = name
        self.kind = kind
        self.size = size
        self.logicalSize = logicalSize ?? size
        self.dirCount = 0
        self.modified = modified
        self.accessed = accessed
        self.category = category
        self.fileCount = kind == .file || kind == .symlink ? 1 : 0
        self.children = children
    }

    var id: ObjectIdentifier { ObjectIdentifier(self) }

    static func == (lhs: FileNode, rhs: FileNode) -> Bool { lhs === rhs }
    func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }

    var isContainer: Bool { kind == .directory || kind == .package }
    var isDirectory: Bool { kind == .directory }
    var isPackage: Bool { kind == .package }
    var isFile: Bool { kind == .file || kind == .symlink }

    /// `nil` for files so outline views know where the tree stops.
    var outlineChildren: [FileNode]? { isContainer && !children.isEmpty ? children : nil }

    var path: String {
        var parts: [String] = []
        var node: FileNode? = self
        while let n = node {
            parts.append(n.name)
            node = n.parent
        }
        let reversed = parts.reversed()
        var result = reversed.joined(separator: "/")
        if result.hasPrefix("//") { result.removeFirst() }
        return result
    }

    var url: URL { URL(fileURLWithPath: path) }

    /// Human-friendly name: the volume for `/`, "Home" for the user's folder, otherwise the file name.
    var displayName: String {
        if parent == nil {
            if name == "/" { return VolumeInfo.load(for: URL(fileURLWithPath: "/")).name }
            if name == SafetyPolicy.home { return "Home" }
            return Format.tildePath(name)
        }
        return name
    }

    var fileExtension: String { (name as NSString).pathExtension.lowercased() }

    var root: FileNode {
        var node = self
        while let p = node.parent { node = p }
        return node
    }

    var depth: Int {
        var d = 0
        var node = parent
        while let n = node { d += 1; node = n.parent }
        return d
    }

    /// Path from the root down to (and including) this node.
    var ancestry: [FileNode] {
        var chain: [FileNode] = []
        var node: FileNode? = self
        while let n = node { chain.append(n); node = n.parent }
        return chain.reversed()
    }

    /// True when any ancestor is a package (app bundle, photo library, ...).
    var isInsidePackage: Bool {
        var node = parent
        while let n = node {
            if n.kind == .package { return true }
            node = n.parent
        }
        return false
    }

    /// The direct child of `ancestor` that contains this node (or the node itself).
    func child(under ancestor: FileNode) -> FileNode? {
        var node: FileNode? = self
        while let n = node {
            if n.parent === ancestor { return n }
            node = n.parent
        }
        return nil
    }

    var dominantCategory: FileCategory {
        if isFile { return category }
        guard let bytes = categoryBytes, let maxIndex = bytes.indices.max(by: { bytes[$0] < bytes[$1] }), bytes[maxIndex] > 0 else {
            return .other
        }
        return FileCategory(rawValue: maxIndex) ?? .other
    }

    /// Sum sizes and category bytes from children; sort children by size (largest first).
    func finalize() {
        guard isContainer else { return }
        var total: Int64 = 0
        var logical: Int64 = 0
        var files = 0
        var dirs = 0
        var bytes = [Int64](repeating: 0, count: FileCategory.allCases.count)
        for child in children {
            total += child.size
            logical += child.logicalSize
            files += child.fileCount
            if child.isContainer { dirs += 1 + child.dirCount }
            if child.isFile {
                bytes[child.category.rawValue] += child.size
            } else if let cb = child.categoryBytes {
                for i in 0..<bytes.count { bytes[i] += cb[i] }
            }
        }
        size = total
        logicalSize = logical
        fileCount = files
        dirCount = dirs
        categoryBytes = bytes
        children.sort { $0.size > $1.size }
    }

    /// Recompute sizes after some descendants were removed.
    func refinalizeAncestors() {
        var node: FileNode? = self
        while let n = node {
            n.children.removeAll { $0.removed }
            n.finalize()
            node = n.parent
        }
    }

    /// Find a descendant by absolute path.
    func node(atPath target: String) -> FileNode? {
        let base = path
        guard target == base || target.hasPrefix(base.hasSuffix("/") ? base : base + "/") else { return nil }
        if target == base { return self }
        let rest = target.dropFirst(base.hasSuffix("/") ? base.count : base.count + 1)
        var node = self
        for component in rest.split(separator: "/") {
            guard let next = node.children.first(where: { $0.name == component }) else { return nil }
            node = next
        }
        return node
    }

    /// Depth-first traversal over files only.
    func forEachFile(_ body: (FileNode) -> Void) {
        var stack: [FileNode] = [self]
        while let node = stack.popLast() {
            if node.isFile {
                body(node)
            } else {
                stack.append(contentsOf: node.children)
            }
        }
    }

    /// Depth-first traversal over every node (containers included).
    func forEachNode(_ body: (FileNode) -> Void) {
        var stack: [FileNode] = [self]
        while let node = stack.popLast() {
            body(node)
            if node.isContainer { stack.append(contentsOf: node.children) }
        }
    }
}
