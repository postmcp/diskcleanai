import Foundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Small in-memory cache of image thumbnails for the duplicates and photo views.
final class ThumbnailLoader {
    static let shared = ThumbnailLoader()
    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 600
    }

    func thumbnail(for url: URL, maxPixel: Int = 320) async -> NSImage? {
        let key = "\(url.path)#\(maxPixel)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let image: NSImage? = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return continuation.resume(returning: nil) }
                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxPixel,
                ]
                guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return continuation.resume(returning: nil) }
                continuation.resume(returning: NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height)))
            }
        }
        if let image { cache.setObject(image, forKey: key) }
        return image
    }

    /// Finder-style icon for a path. Real files get their real icon; unknown paths fall back to the type icon.
    static func icon(for url: URL, isDirectory: Bool) -> NSImage {
        if FileManager.default.fileExists(atPath: url.path) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        if isDirectory { return NSWorkspace.shared.icon(for: .folder) }
        let type = UTType(filenameExtension: url.pathExtension) ?? .data
        return NSWorkspace.shared.icon(for: type)
    }

    static func typeIcon(extension ext: String, isDirectory: Bool) -> NSImage {
        if isDirectory { return NSWorkspace.shared.icon(for: .folder) }
        return NSWorkspace.shared.icon(for: UTType(filenameExtension: ext) ?? .data)
    }
}
