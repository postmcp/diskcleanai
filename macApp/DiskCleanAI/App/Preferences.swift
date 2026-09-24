import Foundation

/// UserDefaults keys shared between `@AppStorage` in views and `AppState`.
enum Pref {
    static let model = "ai.model"
    static let largeFileMinMB = "largeFiles.minMB"
    static let duplicateMinMB = "duplicates.minMB"
    static let photoThreshold = "photos.threshold"
    static let unusedDays = "apps.unusedDays"
    static let downloadsOldDays = "downloads.oldDays"
    static let excludedPathsKey = "scan.excludedPaths"
    static let lastScanPath = "scan.lastPath"
    static let sidebarVolumeBar = "sidebar.volumeBar"
    static let confirmBeforeClean = "cleanup.confirm"
    static let autoCheckUpdates = "updates.auto"
    static let lastUpdateCheck = "updates.lastCheck"
    static let skippedVersion = "updates.skippedVersion"
    static let updateRepo = "updates.repo"
    static let menuBarIcon = "menuBar.show"
    static let menuBarFreeSpace = "menuBar.freeSpace"
    static let portsIncludeUDP = "ports.includeUDP"

    static let defaultModel = "anthropic/claude-sonnet-4.5"

    static func register() {
        UserDefaults.standard.register(defaults: [
            model: defaultModel,
            largeFileMinMB: 100,
            duplicateMinMB: 1,
            photoThreshold: 8,
            unusedDays: 90,
            downloadsOldDays: 30,
            excludedPathsKey: "[]",
            sidebarVolumeBar: true,
            confirmBeforeClean: true,
            autoCheckUpdates: true,
            menuBarIcon: true,
            menuBarFreeSpace: false,
            portsIncludeUDP: false,
        ])
    }

    static var excludedPaths: [String] {
        get {
            guard let data = UserDefaults.standard.string(forKey: excludedPathsKey)?.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            let data = (try? JSONEncoder().encode(newValue)) ?? Data("[]".utf8)
            UserDefaults.standard.set(String(decoding: data, as: UTF8.self), forKey: excludedPathsKey)
        }
    }
}
