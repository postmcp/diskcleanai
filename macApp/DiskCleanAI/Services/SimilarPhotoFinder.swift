import Foundation
import ImageIO
import CoreGraphics
import os

struct PhotoEntry: Identifiable, Hashable {
    let node: FileNode
    let hash: UInt64
    let pixelWidth: Int
    let pixelHeight: Int

    var id: ObjectIdentifier { node.id }
    var pixels: Int { pixelWidth * pixelHeight }
}

struct SimilarPhotoGroup: Identifiable, Hashable {
    let id: String
    let photos: [PhotoEntry]

    /// Everything except the best candidate to keep (largest, then newest).
    var extras: [PhotoEntry] { Array(photos.dropFirst()) }
    var reclaimable: Int64 { extras.reduce(0) { $0 + $1.node.size } }
}

/// Perceptual near-duplicate detection using a 64-bit difference hash computed
/// from an embedded or generated thumbnail. Photos inside libraries and app
/// bundles are never considered.
final class SimilarPhotoFinder: @unchecked Sendable {
    static let photoExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "gif", "bmp", "webp", "dng", "cr2", "cr3", "nef", "arw", "raw"]

    private let cancelFlag = OSAllocatedUnfairLock(initialState: false)
    private let progressState = OSAllocatedUnfairLock(initialState: (done: 0, total: 0))

    func cancel() { cancelFlag.withLock { $0 = true } }
    private var isCancelled: Bool { cancelFlag.withLock { $0 } }
    var progress: (done: Int, total: Int) { progressState.withLock { $0 } }

    func find(in root: FileNode, maxPhotos: Int = 12_000, threshold: Int = 8, minimumSize: Int64 = 50 * 1024) async throws -> [SimilarPhotoGroup] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: try self.run(root: root, maxPhotos: maxPhotos, threshold: threshold, minimumSize: minimumSize))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func run(root: FileNode, maxPhotos: Int, threshold: Int, minimumSize: Int64) throws -> [SimilarPhotoGroup] {
        var photos: [FileNode] = []
        root.forEachFile { node in
            guard node.kind == .file, node.size >= minimumSize, Self.photoExtensions.contains(node.fileExtension), !node.isInsidePackage else { return }
            if SafetyPolicy.assess(path: node.path, insidePackage: false) == .protected { return }
            photos.append(node)
        }
        photos.sort { $0.size > $1.size }
        if photos.count > maxPhotos { photos.removeLast(photos.count - maxPhotos) }
        progressState.withLock { $0 = (0, photos.count) }

        var entries = [PhotoEntry?](repeating: nil, count: photos.count)
        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: photos.count) { i in
            if self.isCancelled { return }
            let node = photos[i]
            if let (hash, w, h) = Self.differenceHash(url: node.url) {
                let entry = PhotoEntry(node: node, hash: hash, pixelWidth: w, pixelHeight: h)
                lock.lock(); entries[i] = entry; lock.unlock()
            }
            self.progressState.withLock { $0.done += 1 }
        }
        if isCancelled { throw CancellationError() }
        let valid = entries.compactMap { $0 }

        // Union-find over hamming distance.
        var parent = Array(0..<valid.count)
        func find(_ x: Int) -> Int {
            var x = x
            while parent[x] != x { parent[x] = parent[parent[x]]; x = parent[x] }
            return x
        }
        for i in 0..<valid.count {
            for j in (i + 1)..<valid.count where (valid[i].hash ^ valid[j].hash).nonzeroBitCount <= threshold {
                let a = find(i), b = find(j)
                if a != b { parent[a] = b }
            }
        }
        var buckets: [Int: [PhotoEntry]] = [:]
        for i in 0..<valid.count { buckets[find(i), default: []].append(valid[i]) }
        return buckets.values
            .filter { $0.count > 1 }
            .map { members in
                let sorted = members.sorted {
                    if $0.pixels != $1.pixels { return $0.pixels > $1.pixels }
                    if $0.node.size != $1.node.size { return $0.node.size > $1.node.size }
                    return ($0.node.modified ?? .distantPast) > ($1.node.modified ?? .distantPast)
                }
                return SimilarPhotoGroup(id: sorted[0].node.path, photos: sorted)
            }
            .sorted { $0.reclaimable > $1.reclaimable }
    }

    /// 9x8 greyscale dHash. Returns the hash plus the source pixel dimensions.
    static func differenceHash(url: URL) -> (UInt64, Int, Int)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = props?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = props?[kCGImagePropertyPixelHeight] as? Int ?? 0
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 64,
            kCGImageSourceShouldCache: false,
        ]
        guard let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return (hash(of: thumb), width, height)
    }

    static func hash(of image: CGImage) -> UInt64 {
        let w = 9, h = 8
        var pixels = [UInt8](repeating: 0, count: w * h)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                          space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return 0 }
        var bits: UInt64 = 0
        for y in 0..<h {
            for x in 0..<(w - 1) {
                bits <<= 1
                if pixels[y * w + x] > pixels[y * w + x + 1] { bits |= 1 }
            }
        }
        return bits
    }
}
