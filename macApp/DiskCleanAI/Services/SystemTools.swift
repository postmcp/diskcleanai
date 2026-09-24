import Foundation
import AppKit
import IOKit.pwr_mgt

/// One-click maintenance actions for the menu bar and the Tools screen. None of
/// them delete user data; the ones that need root ask macOS for a password.
enum QuickTool: String, CaseIterable, Identifiable {
    case flushDNS, purgeMemory, restartFinder, restartDock, toggleHiddenFiles, clearClipboard, sleepDisplay, activityMonitor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flushDNS: return "Flush DNS Cache"
        case .purgeMemory: return "Free Inactive Memory"
        case .restartFinder: return "Restart Finder"
        case .restartDock: return "Restart Dock"
        case .toggleHiddenFiles: return SystemTools.hiddenFilesVisible ? "Hide Hidden Files" : "Show Hidden Files"
        case .clearClipboard: return "Clear Clipboard"
        case .sleepDisplay: return "Sleep Display"
        case .activityMonitor: return "Open Activity Monitor"
        }
    }

    /// Fits the two-column grid in the menu bar.
    var shortTitle: String {
        switch self {
        case .flushDNS: return "Flush DNS"
        case .purgeMemory: return "Free Memory"
        case .toggleHiddenFiles: return SystemTools.hiddenFilesVisible ? "Hide Dotfiles" : "Show Dotfiles"
        case .activityMonitor: return "Activity Monitor"
        default: return title
        }
    }

    var detail: String {
        switch self {
        case .flushDNS: return "Fixes stale hostnames after DNS or /etc/hosts changes"
        case .purgeMemory: return "Runs purge to drop disk caches from RAM"
        case .restartFinder: return "Relaunches a stuck or slow Finder"
        case .restartDock: return "Relaunches the Dock and Mission Control"
        case .toggleHiddenFiles: return "Dotfiles and hidden folders in Finder"
        case .clearClipboard: return "Removes whatever is on the pasteboard"
        case .sleepDisplay: return "Turns the screen off right away"
        case .activityMonitor: return "Every process, energy and network use"
        }
    }

    var systemImage: String {
        switch self {
        case .flushDNS: return "network"
        case .purgeMemory: return "memorychip"
        case .restartFinder: return "folder.badge.gearshape"
        case .restartDock: return "dock.rectangle"
        case .toggleHiddenFiles: return SystemTools.hiddenFilesVisible ? "eye.slash" : "eye"
        case .clearClipboard: return "clipboard"
        case .sleepDisplay: return "moon"
        case .activityMonitor: return "waveform.path.ecg"
        }
    }

    var needsAdmin: Bool { self == .flushDNS || self == .purgeMemory }
}

enum SystemTools {
    struct Failure: Error { let message: String }

    /// Runs the tool and returns a line for the status banner.
    static func run(_ tool: QuickTool) async -> Result<String, Failure> {
        switch tool {
        case .flushDNS:
            return await detached { runAsAdministrator("/usr/bin/dscacheutil -flushcache; /usr/bin/killall -HUP mDNSResponder") }
                .map { "DNS cache flushed." }
        case .purgeMemory:
            return await detached { runAsAdministrator("/usr/sbin/purge") }
                .map { "Inactive memory released." }
        case .restartFinder:
            return shell("/usr/bin/killall", ["Finder"]).map { _ in "Finder restarted." }
        case .restartDock:
            return shell("/usr/bin/killall", ["Dock"]).map { _ in "Dock restarted." }
        case .toggleHiddenFiles:
            let show = !hiddenFilesVisible
            return shell("/usr/bin/defaults", ["write", "com.apple.finder", "AppleShowAllFiles", "-bool", show ? "true" : "false"])
                .flatMap { _ in shell("/usr/bin/killall", ["Finder"]) }
                .map { _ in show ? "Finder now shows hidden files." : "Finder hides hidden files again." }
        case .clearClipboard:
            await MainActor.run { _ = NSPasteboard.general.clearContents() }
            return .success("Clipboard cleared.")
        case .sleepDisplay:
            return shell("/usr/bin/pmset", ["displaysleepnow"]).map { _ in "Display going to sleep." }
        case .activityMonitor:
            let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
            await MainActor.run { _ = NSWorkspace.shared.open(url) }
            return .success("Opened Activity Monitor.")
        }
    }

    static var hiddenFilesVisible: Bool {
        // Old tips wrote the key as a string ("YES", "TRUE"), so accept either form.
        CFPreferencesAppSynchronize("com.apple.finder" as CFString)
        let value = CFPreferencesCopyAppValue("AppleShowAllFiles" as CFString, "com.apple.finder" as CFString)
        if let flag = value as? Bool { return flag }
        if let text = value as? String { return ["yes", "true", "1"].contains(text.lowercased()) }
        return false
    }

    /// Runs a shell command as root through the standard macOS password prompt.
    @discardableResult
    static func runAsAdministrator(_ command: String) -> Result<Void, Failure> {
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"
        return shell("/usr/bin/osascript", ["-e", script]).mapError { failure in
            failure.message.contains("-128") ? Failure(message: "Cancelled.") : failure
        }.map { _ in () }
    }

    @discardableResult
    static func shell(_ path: String, _ arguments: [String]) -> Result<String, Failure> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        do { try process.run() } catch { return .failure(Failure(message: error.localizedDescription)) }
        let output = out.fileHandleForReading.readDataToEndOfFile()
        let errors = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(decoding: errors, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            return .failure(Failure(message: message.isEmpty ? "Exited with status \(process.terminationStatus)." : message))
        }
        return .success(String(decoding: output, as: UTF8.self))
    }

    private static func detached<T>(_ work: @escaping @Sendable () -> Result<T, Failure>) async -> Result<T, Failure> {
        await Task.detached(priority: .userInitiated, operation: work).value
    }
}

/// Holds an IOKit power assertion so the Mac and its display do not idle-sleep, like `caffeinate -d`.
final class KeepAwake {
    private var assertion: IOPMAssertionID = 0
    private(set) var isActive = false

    func start(reason: String = "Disk Clean AI: Keep Awake") -> Bool {
        guard !isActive else { return true }
        let status = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                                 IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                 reason as CFString, &assertion)
        isActive = status == kIOReturnSuccess
        return isActive
    }

    func stop() {
        guard isActive else { return }
        IOPMAssertionRelease(assertion)
        isActive = false
    }

    deinit { stop() }
}
