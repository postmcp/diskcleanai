import Foundation

/// Where a cleanup candidate came from. Drives grouping in the review screen.
enum CleanupSource: String, CaseIterable, Identifiable, Codable {
    case largeFiles, duplicates, apps, downloads, similarPhotos, ai, folders

    var id: String { rawValue }

    var label: String {
        switch self {
        case .largeFiles: return "Large files"
        case .duplicates: return "Duplicates"
        case .apps: return "Apps & leftovers"
        case .downloads: return "Downloads"
        case .similarPhotos: return "Similar photos"
        case .ai: return "AI suggestions"
        case .folders: return "Folders"
        }
    }

    var systemImage: String {
        switch self {
        case .largeFiles: return "doc.text.magnifyingglass"
        case .duplicates: return "doc.on.doc"
        case .apps: return "app.badge"
        case .downloads: return "arrow.down.circle"
        case .similarPhotos: return "photo.on.rectangle.angled"
        case .ai: return "sparkles"
        case .folders: return "folder"
        }
    }
}

/// How risky it is to remove a path. Computed by `SafetyPolicy`.
enum SafetyLevel: Int, Comparable, Codable {
    case safe, caution, protected

    static func < (lhs: SafetyLevel, rhs: SafetyLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .safe: return "Safe"
        case .caution: return "Review"
        case .protected: return "Protected"
        }
    }

    var systemImage: String {
        switch self {
        case .safe: return "checkmark.shield"
        case .caution: return "exclamationmark.triangle"
        case .protected: return "lock.shield"
        }
    }
}

/// A single path queued for the Trash. Everything the user approves flows
/// through this type, whichever screen produced it.
struct CleanupItem: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let name: String
    let size: Int64
    let source: CleanupSource
    let reason: String
    let safety: SafetyLevel
    let isDirectory: Bool
    var approved: Bool

    init(url: URL, size: Int64, source: CleanupSource, reason: String, isDirectory: Bool, approved: Bool = true) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent
        self.size = size
        self.source = source
        self.reason = reason
        self.isDirectory = isDirectory
        self.safety = SafetyPolicy.assess(path: url.path, insidePackage: false)
        self.approved = approved && self.safety != .protected
    }

    init(node: FileNode, source: CleanupSource, reason: String, approved: Bool = true) {
        self.id = UUID()
        self.url = node.url
        self.name = node.name
        self.size = node.size
        self.source = source
        self.reason = reason
        self.isDirectory = node.isContainer
        self.safety = SafetyPolicy.assess(path: node.path, insidePackage: node.isInsidePackage)
        self.approved = approved && self.safety != .protected
    }
}

/// Outcome of moving a batch to the Trash. Kept so the batch can be undone.
struct CleanupBatch: Identifiable {
    struct Moved: Hashable {
        let original: URL
        let trashed: URL
        let size: Int64
    }
    struct Failure: Identifiable {
        let id = UUID()
        let url: URL
        let message: String
    }

    let id = UUID()
    let performedAt: Date
    let moved: [Moved]
    let failures: [Failure]

    var freedBytes: Int64 { moved.reduce(0) { $0 + $1.size } }
}
