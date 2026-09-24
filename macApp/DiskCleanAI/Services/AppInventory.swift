import Foundation
import AppKit

struct LeftoverItem: Identifiable, Hashable {
    let url: URL
    let kind: String
    let size: Int64
    let isDirectory: Bool

    var id: String { url.path }
}

struct InstalledApp: Identifiable, Hashable {
    let url: URL
    let name: String
    let bundleID: String?
    let version: String?
    let size: Int64
    let lastUsed: Date?
    let installed: Date?
    let leftovers: [LeftoverItem]
    let isRemovable: Bool

    var id: String { url.path }
    var leftoverBytes: Int64 { leftovers.reduce(0) { $0 + $1.size } }
    var totalBytes: Int64 { size + leftoverBytes }

    var daysSinceUse: Int? {
        guard let lastUsed else { return nil }
        return Calendar.current.dateComponents([.day], from: lastUsed, to: Date()).day
    }

    /// Unused when it has never been opened or not for at least `days`.
    func isUnused(days: Int) -> Bool {
        guard let d = daysSinceUse else { return true }
        return d >= days
    }
}

/// Enumerates user-installed applications with their on-disk size, last-used date
/// from Spotlight metadata, and the support files they leave around ~/Library.
enum AppInventory {
    static let searchRoots: [URL] = [
        URL(fileURLWithPath: "/Applications"),
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
    ]

    private static let leftoverFolders: [(String, String)] = [
        ("Application Support", "Library/Application Support"),
        ("Caches", "Library/Caches"),
        ("Logs", "Library/Logs"),
        ("Preferences", "Library/Preferences"),
        ("Saved State", "Library/Saved Application State"),
        ("HTTP Storage", "Library/HTTPStorages"),
        ("WebKit", "Library/WebKit"),
        ("Containers", "Library/Containers"),
        ("Group Containers", "Library/Group Containers"),
        ("Cookies", "Library/Cookies"),
        ("Application Scripts", "Library/Application Scripts"),
    ]

    static func load() async -> [InstalledApp] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: enumerate())
            }
        }
    }

    private static func enumerate() -> [InstalledApp] {
        let fm = FileManager.default
        var bundles: [URL] = []
        for root in searchRoots {
            guard let entries = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isPackageKey], options: [.skipsHiddenFiles]) else { continue }
            for entry in entries where entry.pathExtension == "app" {
                bundles.append(entry)
            }
        }
        var apps = [InstalledApp?](repeating: nil, count: bundles.count)
        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: bundles.count) { i in
            let app = describe(bundles[i])
            lock.lock(); apps[i] = app; lock.unlock()
        }
        return apps.compactMap { $0 }.sorted { $0.totalBytes > $1.totalBytes }
    }

    private static func describe(_ url: URL) -> InstalledApp? {
        let bundle = Bundle(url: url)
        let info = bundle?.infoDictionary ?? [:]
        let name = (info["CFBundleDisplayName"] as? String) ?? (info["CFBundleName"] as? String) ?? url.deletingPathExtension().lastPathComponent
        let bundleID = bundle?.bundleIdentifier
        let version = (info["CFBundleShortVersionString"] as? String) ?? (info["CFBundleVersion"] as? String)
        let size = directorySize(url)
        let lastUsed = spotlightLastUsed(url)
        let installed = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate
        let leftovers = findLeftovers(bundleID: bundleID, name: name)
        return InstalledApp(url: url, name: name, bundleID: bundleID, version: version, size: size, lastUsed: lastUsed,
                            installed: installed, leftovers: leftovers, isRemovable: SafetyPolicy.isRemovable(url))
    }

    static func spotlightLastUsed(_ url: URL) -> Date? {
        guard let item = MDItemCreateWithURL(kCFAllocatorDefault, url as CFURL) else { return nil }
        return MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date
    }

    static func directorySize(_ url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileSizeKey, .isDirectoryKey]
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys), options: [], errorHandler: { _, _ in true }) else {
            return (try? url.resourceValues(forKeys: keys))?.totalFileAllocatedSize.map(Int64.init) ?? 0
        }
        var total: Int64 = 0
        for case let file as URL in enumerator {
            guard let values = try? file.resourceValues(forKeys: keys), values.isDirectory != true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
        }
        if total == 0, let values = try? url.resourceValues(forKeys: keys), values.isDirectory != true {
            total = Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
        }
        return total
    }

    static func findLeftovers(bundleID: String?, name: String) -> [LeftoverItem] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        var found: [LeftoverItem] = []
        var seen: Set<String> = []
        let candidates = [bundleID, name].compactMap { $0 }.filter { !$0.isEmpty }
        guard !candidates.isEmpty else { return [] }

        func add(_ url: URL, kind: String) {
            guard !seen.contains(url.path), fm.fileExists(atPath: url.path) else { return }
            seen.insert(url.path)
            var isDir: ObjCBool = false
            fm.fileExists(atPath: url.path, isDirectory: &isDir)
            let size = isDir.boolValue ? directorySize(url) : Int64((try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?.totalFileAllocatedSize ?? 0)
            found.append(LeftoverItem(url: url, kind: kind, size: size, isDirectory: isDir.boolValue))
        }

        for (kind, relative) in leftoverFolders {
            let folder = home.appendingPathComponent(relative)
            for candidate in candidates {
                add(folder.appendingPathComponent(candidate), kind: kind)
            }
            if kind == "Preferences", let bundleID {
                add(folder.appendingPathComponent("\(bundleID).plist"), kind: kind)
                if let entries = try? fm.contentsOfDirectory(atPath: folder.path) {
                    for entry in entries where entry.hasPrefix(bundleID + ".") && entry.hasSuffix(".plist") {
                        add(folder.appendingPathComponent(entry), kind: kind)
                    }
                }
            }
            if kind == "Saved State", let bundleID {
                add(folder.appendingPathComponent("\(bundleID).savedState"), kind: kind)
            }
            if kind == "Cookies", let bundleID {
                add(folder.appendingPathComponent("\(bundleID).binarycookies"), kind: kind)
            }
            if kind == "Group Containers", let bundleID, let entries = try? fm.contentsOfDirectory(atPath: folder.path) {
                for entry in entries where entry.hasSuffix("." + bundleID) || entry.hasSuffix(bundleID) {
                    add(folder.appendingPathComponent(entry), kind: kind)
                }
            }
        }
        return found.sorted { $0.size > $1.size }
    }
}
