import Foundation

/// Coarse file classes used for the sunburst legend, the storage bar and filters.
enum FileCategory: Int, CaseIterable, Identifiable, Codable {
    case video = 0, photos, audio, documents, apps, archives, developer, caches, other

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .video: return "Video"
        case .photos: return "Photos"
        case .audio: return "Audio"
        case .documents: return "Documents"
        case .apps: return "Apps"
        case .archives: return "Archives & Images"
        case .developer: return "Developer"
        case .caches: return "Caches & Logs"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .video: return "film"
        case .photos: return "photo"
        case .audio: return "music.note"
        case .documents: return "doc.text"
        case .apps: return "app.badge"
        case .archives: return "shippingbox"
        case .developer: return "chevron.left.forwardslash.chevron.right"
        case .caches: return "internaldrive"
        case .other: return "questionmark.folder"
        }
    }

    /// Index into `Theme.chart`. `other` uses the theme's muted colour instead.
    var chartIndex: Int { rawValue }

    // MARK: Classification

    private static let videoExt: Set<String> = ["mp4", "mov", "m4v", "mkv", "avi", "wmv", "flv", "webm", "mpg", "mpeg", "m2ts", "mts", "3gp", "ts", "vob", "prores"]
    private static let photosExt: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "gif", "tiff", "tif", "bmp", "webp", "dng", "raw", "cr2", "cr3", "nef", "arw", "orf", "rw2", "psd", "ai", "svg", "avif"]
    private static let audioExt: Set<String> = ["mp3", "aac", "m4a", "wav", "aiff", "aif", "flac", "ogg", "wma", "alac", "opus", "caf", "mid", "midi"]
    private static let documentsExt: Set<String> = ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "key", "pages", "numbers", "txt", "rtf", "md", "csv", "epub", "mobi", "odt", "ods", "odp", "tex", "html", "htm"]
    private static let archivesExt: Set<String> = ["zip", "tar", "gz", "tgz", "bz2", "xz", "7z", "rar", "dmg", "iso", "pkg", "img", "sparseimage", "sparsebundle", "vdi", "vmdk", "qcow2", "ova", "xip"]
    private static let developerExt: Set<String> = ["swift", "m", "h", "c", "cpp", "cc", "hpp", "java", "kt", "js", "ts", "tsx", "jsx", "py", "rb", "go", "rs", "php", "cs", "json", "yaml", "yml", "toml", "lock", "xcodeproj", "xcworkspace", "framework", "a", "o", "dylib", "so", "wasm", "jar", "class", "ipa", "apk", "node", "map"]

    static func classify(name: String, context: PathContext) -> FileCategory {
        if context.inApplication { return .apps }
        if context.inCaches { return .caches }
        let ext = (name as NSString).pathExtension.lowercased()
        if context.inDeveloper && !videoExt.contains(ext) && !photosExt.contains(ext) && !audioExt.contains(ext) {
            return .developer
        }
        if videoExt.contains(ext) { return .video }
        if photosExt.contains(ext) { return .photos }
        if audioExt.contains(ext) { return .audio }
        if documentsExt.contains(ext) { return .documents }
        if archivesExt.contains(ext) { return .archives }
        if developerExt.contains(ext) { return .developer }
        if ext == "app" { return .apps }
        return .other
    }
}

/// Flags inherited while walking down a directory tree so files can be classified
/// by where they live, not only by extension.
struct PathContext: Hashable {
    var inApplication = false
    var inCaches = false
    var inDeveloper = false
    var inPackage = false
    var depth = 0

    private static let cacheNames: Set<String> = ["caches", "cache", "logs", "log", "tmp", "temp", "crashreporter", "diagnosticreports", "saved application state", "httpstorages", "webkit", "cookies"]
    private static let developerNames: Set<String> = ["node_modules", "deriveddata", ".build", "build", "target", ".gradle", ".cargo", ".rustup", ".npm", ".yarn", ".pnpm-store", ".cocoapods", "pods", "carthage", ".venv", "venv", "site-packages", "__pycache__", ".m2", "go", ".docker", "xcode", "coresimulator", "developer", ".cache"]

    func descending(into name: String, isPackage: Bool) -> PathContext {
        var next = self
        next.depth += 1
        let lower = name.lowercased()
        if isPackage {
            next.inPackage = true
            if lower.hasSuffix(".app") || lower.hasSuffix(".appex") || lower.hasSuffix(".xpc") { next.inApplication = true }
        }
        if Self.cacheNames.contains(lower) { next.inCaches = true }
        if Self.developerNames.contains(lower) { next.inDeveloper = true }
        return next
    }
}
