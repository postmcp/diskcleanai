import Foundation
import os

struct ScanProgress: Equatable {
    var files = 0
    var directories = 0
    var bytes: Int64 = 0
    var currentPath = ""
    var elapsed: TimeInterval = 0
}

struct ScanOptions {
    /// Absolute path prefixes to leave out of the walk.
    var excludedPaths: [String] = []
    /// Names that are never worth walking at any depth.
    var skippedNames: Set<String> = [".fseventsd", ".Spotlight-V100", ".DocumentRevisions-V100", ".TemporaryItems", ".vol", ".PKInstallSandboxManager", ".PKInstallSandboxManager-SystemSoftware", ".MobileBackups", ".hotfiles.btree", ".file", "lost+found"]
    /// Synthetic root-level views of the volume (`/.nofollow` mirrors `/` without firmlinks). Walking them counts everything twice.
    var skippedRootNames: Set<String> = [".nofollow", ".resolve", ".vol", ".file", "dev"]
}

/// Thread-safe counters the UI polls while a scan runs.
final class ScanCounters: @unchecked Sendable {
    private let state = OSAllocatedUnfairLock(initialState: ScanProgress())
    private let startedAt = Date()

    func add(files: Int, directories: Int, bytes: Int64, path: String) {
        state.withLock { p in
            p.files += files
            p.directories += directories
            p.bytes += bytes
            p.currentPath = path
        }
    }

    var snapshot: ScanProgress {
        var p = state.withLock { $0 }
        p.elapsed = Date().timeIntervalSince(startedAt)
        return p
    }
}

/// Walks a directory tree quickly: the first two levels are expanded serially,
/// then every sub-tree is scanned on its own thread with `concurrentPerform`.
/// Symbolic links are recorded but never followed and other mount points are skipped,
/// so scanning `/` counts the boot volume exactly once. A file with several hard links
/// is counted at the first path reached; its other paths show zero bytes, like `du`.
final class DiskScanner: @unchecked Sendable {
    let counters = ScanCounters()
    private let cancelFlag = OSAllocatedUnfairLock(initialState: false)
    private let options: ScanOptions
    private let fileManager = FileManager.default
    /// Identities of multiply-linked files already counted, shared by all scanning threads.
    private let countedHardLinks = OSAllocatedUnfairLock(initialState: Set<FileIdentity>())

    private static let keys: [URLResourceKey] = [
        .nameKey, .isDirectoryKey, .isSymbolicLinkKey, .isPackageKey, .isVolumeKey,
        .totalFileAllocatedSizeKey, .fileSizeKey, .contentModificationDateKey, .contentAccessDateKey, .linkCountKey,
    ]
    private static let keySet = Set(keys)

    init(options: ScanOptions = ScanOptions()) {
        self.options = options
    }

    func cancel() {
        cancelFlag.withLock { $0 = true }
    }

    var isCancelled: Bool { cancelFlag.withLock { $0 } }

    func scan(root: URL) async throws -> FileNode {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let node = try self.performScan(root: root)
                    continuation.resume(returning: node)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Implementation

    private struct WorkItem {
        let node: FileNode
        let url: URL
        let context: PathContext
        let depth: Int
    }

    private func performScan(root: URL) throws -> FileNode {
        let standardized = root.standardizedFileURL
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: standardized.path, isDirectory: &isDir), isDir.boolValue else {
            throw ScanError.notADirectory(standardized.path)
        }
        let values = try? standardized.resourceValues(forKeys: Self.keySet)
        let rootNode = FileNode(name: standardized.path == "/" ? "/" : standardized.path, kind: values?.isPackage == true ? .package : .directory,
                                modified: values?.contentModificationDate)
        var context = PathContext()
        if values?.isPackage == true { context = context.descending(into: standardized.lastPathComponent, isPackage: true) }

        // Phase 1: breadth-first expansion until there is enough parallel work.
        var pending: [WorkItem] = [WorkItem(node: rootNode, url: standardized, context: context, depth: 0)]
        var work: [WorkItem] = []
        var expanded: [FileNode] = []
        while !pending.isEmpty {
            if isCancelled { throw CancellationError() }
            let item = pending.removeFirst()
            if item.depth >= 2 || pending.count + work.count >= 96 {
                work.append(item)
                continue
            }
            expanded.append(item.node)
            let subdirs = expandOneLevel(item)
            pending.append(contentsOf: subdirs)
        }

        // Phase 2: parallel deep scan.
        DispatchQueue.concurrentPerform(iterations: work.count) { index in
            let item = work[index]
            self.scanSubtree(item.node, url: item.url, context: item.context)
        }
        if isCancelled { throw CancellationError() }

        // Phase 3: aggregate the serial levels (deepest first).
        for node in expanded.reversed() { node.finalize() }
        return rootNode
    }

    /// Lists one directory, attaching file nodes immediately and returning the
    /// sub-directories still to be walked.
    private func expandOneLevel(_ item: WorkItem) -> [WorkItem] {
        guard let entries = list(item.url) else {
            item.node.unreadable = true
            return []
        }
        var subdirs: [WorkItem] = []
        var children: [FileNode] = []
        children.reserveCapacity(entries.count)
        var files = 0
        var bytes: Int64 = 0
        for entry in entries {
            guard let values = try? entry.resourceValues(forKeys: Self.keySet) else { continue }
            let name = values.name ?? entry.lastPathComponent
            if let node = makeNode(name: name, values: values, url: entry, context: item.context, parent: item.node) {
                children.append(node)
                if node.isContainer {
                    subdirs.append(WorkItem(node: node, url: entry, context: item.context.descending(into: name, isPackage: node.isPackage), depth: item.depth + 1))
                } else {
                    files += 1
                    bytes += node.size
                }
            }
        }
        item.node.children = children
        counters.add(files: files, directories: 1, bytes: bytes, path: item.url.path)
        return subdirs
    }

    private func scanSubtree(_ node: FileNode, url: URL, context: PathContext) {
        if isCancelled { return }
        guard let entries = list(url) else {
            node.unreadable = true
            node.finalize()
            return
        }
        var children: [FileNode] = []
        children.reserveCapacity(entries.count)
        var files = 0
        var bytes: Int64 = 0
        for entry in entries {
            guard let values = try? entry.resourceValues(forKeys: Self.keySet) else { continue }
            let name = values.name ?? entry.lastPathComponent
            guard let child = makeNode(name: name, values: values, url: entry, context: context, parent: node) else { continue }
            children.append(child)
            if child.isContainer {
                scanSubtree(child, url: entry, context: context.descending(into: name, isPackage: child.isPackage))
            } else {
                files += 1
                bytes += child.size
            }
        }
        node.children = children
        node.finalize()
        counters.add(files: files, directories: 1, bytes: bytes, path: url.path)
    }

    private func list(_ url: URL) -> [URL]? {
        try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: Self.keys, options: [])
    }

    private func makeNode(name: String, values: URLResourceValues, url: URL, context: PathContext, parent: FileNode) -> FileNode? {
        if options.skippedNames.contains(name) { return nil }
        let allocated = Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
        let logical = Int64(values.fileSize ?? Int(allocated))
        if values.isSymbolicLink == true {
            let node = FileNode(name: name, kind: .symlink, size: allocated, logicalSize: logical, modified: values.contentModificationDate, accessed: values.contentAccessDate,
                                category: FileCategory.classify(name: name, context: context))
            node.parent = parent
            return node
        }
        if values.isDirectory == true {
            if values.isVolume == true { return nil } // another mount point
            if context.depth == 0, parent.parent == nil, parent.name == "/", options.skippedRootNames.contains(name) { return nil }
            // Resource values cached by the directory listing can miss the mount-point flag (seen with /.nofollow),
            // so shallow directories get a fresh check. Deeper mounts are rare and cheap to miss.
            if context.depth < 3, (try? URL(fileURLWithPath: url.path).resourceValues(forKeys: [.isVolumeKey]))?.isVolume == true { return nil }
            let path = url.path
            for excluded in options.excludedPaths where SafetyPolicy.matches(path, prefix: excluded) { return nil }
            let node = FileNode(name: name, kind: values.isPackage == true ? .package : .directory, modified: values.contentModificationDate)
            node.parent = parent
            if values.isPackage == true {
                node.category = FileCategory.classify(name: name, context: context.descending(into: name, isPackage: true))
            }
            return node
        }
        let counted = isFirstLink(values: values, url: url)
        let node = FileNode(name: name, kind: .file, size: counted ? allocated : 0, logicalSize: counted ? logical : 0,
                            modified: values.contentModificationDate, accessed: values.contentAccessDate,
                            category: FileCategory.classify(name: name, context: context))
        node.parent = parent
        return node
    }

    /// False for the second and later hard links to a file, so its bytes are counted once.
    /// Only files that report more than one link pay for the `lstat`.
    private func isFirstLink(values: URLResourceValues, url: URL) -> Bool {
        guard (values.linkCount ?? 1) > 1, let identity = FileIdentity(path: url.path) else { return true }
        return countedHardLinks.withLock { $0.insert(identity).inserted }
    }
}

enum ScanError: LocalizedError {
    case notADirectory(String)

    var errorDescription: String? {
        switch self {
        case .notADirectory(let path): return "\(path) is not a folder that can be scanned."
        }
    }
}
