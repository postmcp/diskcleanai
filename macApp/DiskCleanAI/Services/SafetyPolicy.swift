import Foundation

/// Decides whether a path may be sent to the Trash from inside the app.
///
/// `protected` paths can never be queued: the OS, system frameworks, keychains, SSH/GPG
/// keys and anything inside a package. `caution` paths are allowed but flagged in the review
/// list so the user looks twice. Everything else under the home folder is `safe`.
enum SafetyPolicy {
    static let home = FileManager.default.homeDirectoryForCurrentUser.path

    private static let protectedPrefixes: [String] = [
        "/System", "/usr", "/bin", "/sbin", "/etc", "/private/etc", "/private/var/db", "/private/var/vm",
        "/Library/Apple", "/Library/Frameworks", "/Library/Extensions", "/Library/Security", "/Library/Keychains",
        "/cores", "/opt/homebrew/Cellar", "/nix", "/Volumes/Recovery", "/Volumes/Preboot",
        home + "/Library/Keychains", home + "/Library/Mail",
        home + "/Library/Messages", home + "/Library/Photos", home + "/Library/Accounts",
        home + "/Library/Safari", home + "/Library/CloudStorage", home + "/.ssh", home + "/.gnupg",
        home + "/Library/Mobile Documents/com~apple~CloudDocs/.Trash",
        home + "/Library/Application Support/MobileSync",
    ]

    /// Folders that must stay but whose individual entries may go: the app uninstaller
    /// removes an app's own preference plist and cookie file from these.
    private static let protectedFolders: [String] = [
        home + "/Library/Preferences", home + "/Library/Cookies",
    ]

    private static let cautionPrefixes: [String] = [
        "/Library", "/private/var", "/private/tmp", "/opt", "/Applications",
        home + "/Library", home + "/Pictures/Photos Library.photoslibrary",
        home + "/Library/Mobile Documents", home + "/Music/Music", home + "/.config",
    ]

    /// Sub-trees of ~/Library that are widely accepted as disposable.
    private static let safeLibraryPrefixes: [String] = [
        home + "/Library/Caches", home + "/Library/Logs", home + "/Library/Developer/Xcode/DerivedData",
        home + "/Library/Developer/Xcode/Archives", home + "/Library/Developer/Xcode/iOS DeviceSupport",
        home + "/Library/Developer/CoreSimulator/Caches", home + "/Library/Application Support/CrashReporter",
        home + "/Library/Saved Application State", home + "/Library/HTTPStorages",
    ]

    static func assess(path: String, insidePackage: Bool) -> SafetyLevel {
        if path == "/" || path == home { return .protected }
        if insidePackage { return .protected }
        for p in protectedPrefixes where matches(path, prefix: p) { return .protected }
        if protectedFolders.contains(path) { return .protected }
        for p in safeLibraryPrefixes where matches(path, prefix: p) { return path == p ? .caution : .safe }
        for p in cautionPrefixes where matches(path, prefix: p) { return .caution }
        if path.hasPrefix("/Users/") || path.hasPrefix("/Volumes/") { return .safe }
        return .caution
    }

    static func matches(_ path: String, prefix: String) -> Bool {
        path == prefix || path.hasPrefix(prefix.hasSuffix("/") ? prefix : prefix + "/")
    }

    /// Whether the current user can actually move the item to the Trash.
    static func isRemovable(_ url: URL) -> Bool {
        let parent = url.deletingLastPathComponent().path
        return FileManager.default.isWritableFile(atPath: parent)
    }
}
