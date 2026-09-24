import Foundation
import AppKit

/// Detects whether the app has Full Disk Access by probing a TCC-protected file.
enum FullDiskAccess {
    static func isGranted() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let probes = [
            home.appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db"),
            home.appendingPathComponent("Library/Safari/Bookmarks.plist"),
            home.appendingPathComponent("Library/Mail"),
        ]
        for probe in probes {
            if let handle = try? FileHandle(forReadingFrom: probe) {
                try? handle.close()
                return true
            }
            if FileManager.default.fileExists(atPath: probe.path), (try? FileManager.default.contentsOfDirectory(atPath: probe.path)) != nil {
                return true
            }
        }
        return false
    }

    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
