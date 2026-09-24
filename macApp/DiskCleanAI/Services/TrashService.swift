import Foundation
import AppKit

/// Every removal in the app goes through here and always lands in the Trash.
enum TrashService {
    static func trash(_ items: [CleanupItem], progress: @escaping @MainActor (Int, Int) -> Void) async -> CleanupBatch {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var moved: [CleanupBatch.Moved] = []
                var failures: [CleanupBatch.Failure] = []
                let fm = FileManager.default
                for (index, item) in items.enumerated() {
                    if item.safety == .protected {
                        failures.append(.init(url: item.url, message: "Protected path — skipped."))
                        continue
                    }
                    var resulting: NSURL?
                    do {
                        try fm.trashItem(at: item.url, resultingItemURL: &resulting)
                        moved.append(.init(original: item.url, trashed: (resulting as URL?) ?? item.url, size: item.size))
                    } catch {
                        failures.append(.init(url: item.url, message: error.localizedDescription))
                    }
                    let done = index + 1
                    Task { @MainActor in progress(done, items.count) }
                }
                continuation.resume(returning: CleanupBatch(performedAt: Date(), moved: moved, failures: failures))
            }
        }
    }

    /// Move a batch back out of the Trash. Returns the paths that could not be restored.
    static func restore(_ batch: CleanupBatch) async -> [CleanupBatch.Failure] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var failures: [CleanupBatch.Failure] = []
                let fm = FileManager.default
                for move in batch.moved.reversed() {
                    do {
                        try fm.createDirectory(at: move.original.deletingLastPathComponent(), withIntermediateDirectories: true)
                        try fm.moveItem(at: move.trashed, to: move.original)
                    } catch {
                        failures.append(.init(url: move.original, message: error.localizedDescription))
                    }
                }
                continuation.resume(returning: failures)
            }
        }
    }

    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
