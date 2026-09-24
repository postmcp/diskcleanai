import Foundation
import CryptoKit
import os

struct DuplicateGroup: Identifiable, Hashable {
    let id: String
    let size: Int64
    let files: [FileNode]

    var wastedBytes: Int64 { size * Int64(max(files.count - 1, 0)) }
    var totalBytes: Int64 { size * Int64(files.count) }
}

/// Byte-for-byte duplicate detection in three passes: size, then a 128 KB
/// prefix hash, then a full SHA-256. Only files the user could sensibly delete
/// are considered: nothing inside packages, nothing under protected system paths.
/// Hard links to one file are kept to a single path, since trashing one frees nothing.
/// APFS clones (`cp -c`) also share storage but cannot be detected cheaply, so they still count.
final class DuplicateFinder: @unchecked Sendable {
    private let cancelFlag = OSAllocatedUnfairLock(initialState: false)
    private let progressState = OSAllocatedUnfairLock(initialState: (done: 0, total: 0))

    func cancel() { cancelFlag.withLock { $0 = true } }
    private var isCancelled: Bool { cancelFlag.withLock { $0 } }

    /// (hashed so far, total to hash)
    var progress: (done: Int, total: Int) { progressState.withLock { $0 } }

    func find(in root: FileNode, minimumSize: Int64) async throws -> [DuplicateGroup] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: try self.run(root: root, minimumSize: minimumSize))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func run(root: FileNode, minimumSize: Int64) throws -> [DuplicateGroup] {
        var bySize: [Int64: [FileNode]] = [:]
        root.forEachFile { node in
            guard node.kind == .file, node.size >= minimumSize, !node.isInsidePackage else { return }
            if SafetyPolicy.assess(path: node.path, insidePackage: false) == .protected { return }
            bySize[node.size, default: []].append(node)
        }
        let candidates = bySize.values.filter { $0.count > 1 }
        let totalToHash = candidates.reduce(0) { $0 + $1.count }
        progressState.withLock { $0 = (0, totalToHash) }

        var groups: [DuplicateGroup] = []
        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: candidates.count) { index in
            if self.isCancelled { return }
            let files = Self.oneLinkPerFile(candidates[index])
            let skipped = candidates[index].count - files.count
            if skipped > 0 { self.progressState.withLock { $0.done += skipped } }
            guard files.count > 1 else { return }
            let size = files[0].size
            // Pass 2: prefix hash.
            var byPrefix: [String: [FileNode]] = [:]
            for file in files {
                if let h = Self.hash(url: file.url, limit: 131_072) { byPrefix[h, default: []].append(file) }
                self.progressState.withLock { $0.done += 1 }
            }
            for (_, subset) in byPrefix where subset.count > 1 {
                if size <= 131_072 {
                    // Prefix covered the whole file.
                    let group = DuplicateGroup(id: "\(size)-\(subset[0].id.hashValue)", size: size, files: subset.sorted { ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast) })
                    lock.lock(); groups.append(group); lock.unlock()
                    continue
                }
                var byFull: [String: [FileNode]] = [:]
                for file in subset {
                    if let h = Self.hash(url: file.url, limit: nil) { byFull[h, default: []].append(file) }
                }
                for (hash, dupes) in byFull where dupes.count > 1 {
                    let group = DuplicateGroup(id: hash, size: size, files: dupes.sorted { ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast) })
                    lock.lock(); groups.append(group); lock.unlock()
                }
            }
        }
        if isCancelled { throw CancellationError() }
        return groups.sorted { $0.wastedBytes > $1.wastedBytes }
    }

    /// Drops every path after the first that points at the same file on disk.
    static func oneLinkPerFile(_ files: [FileNode]) -> [FileNode] {
        var seen = Set<FileIdentity>()
        return files.filter { file in
            guard let identity = FileIdentity(path: file.path) else { return true }
            return seen.insert(identity).inserted
        }
    }

    static func hash(url: URL, limit: Int?) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        var remaining = limit ?? Int.max
        let chunk = 1_048_576
        while remaining > 0 {
            let want = min(chunk, remaining)
            guard let data = try? handle.read(upToCount: want), !data.isEmpty else { break }
            hasher.update(data: data)
            remaining -= data.count
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
