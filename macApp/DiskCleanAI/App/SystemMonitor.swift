import Foundation
import SwiftUI
import Observation
import AppKit

/// Live system readings and the port / process / quick-tool actions shared by the
/// menu bar extra and the Tools screen. Sampling only runs while one of them is
/// on screen; the free-space figure for the menu bar label ticks slowly in the background.
@MainActor
@Observable
final class SystemMonitor {
    struct Status: Equatable {
        enum Style { case info, success, warning }
        let id = UUID()
        let message: String
        let style: Style
        /// Set when a kill failed for lack of permission, so the UI can offer the admin prompt.
        var adminPID: Int32? = nil
    }

    // MARK: Readings
    var disk: VolumeInfo? = VolumeInfo.mounted().first(where: \.isRoot)
    var memory = SystemStats.memory()
    var cpu: Double?
    var localIP: String? = SystemStats.localIPAddress()
    var ports: [ListeningPort] = []
    var portsLoaded = false
    var processes: [SystemStats.ProcessUsage] = []

    // MARK: Activity
    var killing: Set<Int32> = []
    var runningTools: Set<QuickTool> = []
    var status: Status?
    var keepAwakeUntil: Date?
    var isKeepingAwake = false

    /// Drives `MenuBarExtra(isInserted:)`. Kept here rather than in `@AppStorage` on the
    /// App, which sends SwiftUI into an endless scene update loop.
    var showInMenuBar: Bool = UserDefaults.standard.object(forKey: Pref.menuBarIcon) as? Bool ?? true {
        didSet { UserDefaults.standard.set(showInMenuBar, forKey: Pref.menuBarIcon) }
    }

    var includeUDP: Bool = UserDefaults.standard.bool(forKey: Pref.portsIncludeUDP) {
        didSet {
            UserDefaults.standard.set(includeUDP, forKey: Pref.portsIncludeUDP)
            Task { await refreshPorts() }
        }
    }

    @ObservationIgnored private var watchers = 0
    @ObservationIgnored private var processWatchers = 0
    @ObservationIgnored private var liveTask: Task<Void, Never>?
    @ObservationIgnored private var diskTask: Task<Void, Never>?
    @ObservationIgnored private var statusTask: Task<Void, Never>?
    @ObservationIgnored private var keepAwakeTask: Task<Void, Never>?
    @ObservationIgnored private var lastTicks = SystemStats.cpuTicks()
    @ObservationIgnored private let keepAwake = KeepAwake()

    init() {
        diskTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                self?.refreshDisk()
            }
        }
    }

    // MARK: - Sampling

    /// Call from `onAppear`; balanced by `endWatching`. Processes are only sampled
    /// for the full Tools screen because `ps` is the most expensive reading.
    func beginWatching(processes: Bool = false) {
        watchers += 1
        if processes { processWatchers += 1 }
        guard liveTask == nil else {
            if processes { Task { await refreshProcesses() } }
            return
        }
        liveTask = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                guard let self else { return }
                self.refreshStats()
                if tick % 2 == 0 { await self.refreshPorts() }
                if tick % 2 == 0, self.processWatchers > 0 { await self.refreshProcesses() }
                tick += 1
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func endWatching(processes: Bool = false) {
        watchers = max(watchers - 1, 0)
        if processes { processWatchers = max(processWatchers - 1, 0) }
        if watchers == 0 {
            liveTask?.cancel()
            liveTask = nil
        }
    }

    func refreshAll() async {
        refreshStats()
        await refreshPorts()
        if processWatchers > 0 { await refreshProcesses() }
    }

    func refreshStats() {
        refreshDisk()
        memory = SystemStats.memory()
        let ticks = SystemStats.cpuTicks()
        if let usage = ticks?.usage(since: lastTicks) { cpu = usage }
        lastTicks = ticks
        localIP = SystemStats.localIPAddress()
    }

    func refreshDisk() {
        disk = VolumeInfo.load(for: URL(fileURLWithPath: "/"))
    }

    func refreshPorts() async {
        let list = await PortScanner.list(includeUDP: includeUDP)
        if list != ports { ports = list }
        portsLoaded = true
    }

    func refreshProcesses() async {
        let all = await SystemStats.topProcesses()
        processes = all.filter { $0.pid != getpid() }
    }

    // MARK: - Ports

    /// Stops every visible process listening on `port`.
    func killPort(_ port: Int) async {
        await refreshPorts()
        let matches = ports.filter { $0.port == port }
        guard !matches.isEmpty else {
            show("Nothing you own is listening on :\(port).", style: .info)
            return
        }
        for pid in Set(matches.map(\.pid)) {
            if let row = matches.first(where: { $0.pid == pid }) { await kill(row) }
        }
    }

    func kill(_ port: ListeningPort, graceful: Bool = false) async {
        await signal(pid: port.pid, name: port.command, label: ":\(port.port)", graceful: graceful)
    }

    func forceKill(_ port: ListeningPort) async {
        killing.insert(port.pid)
        report(PortScanner.forceKill(pid: port.pid), name: port.command, label: ":\(port.port)", pid: port.pid)
        killing.remove(port.pid)
        await refreshPorts()
    }

    func quit(_ process: SystemStats.ProcessUsage, force: Bool = false) async {
        if force {
            report(PortScanner.forceKill(pid: process.pid), name: process.name, label: nil, pid: process.pid)
            await refreshProcesses()
        } else {
            await signal(pid: process.pid, name: process.name, label: nil, graceful: true)
        }
    }

    func killAsAdministrator(pid: Int32) async {
        killing.insert(pid)
        let result = await Task.detached { PortScanner.killAsAdministrator(pid: pid) }.value
        killing.remove(pid)
        report(result, name: "PID \(pid)", label: nil, pid: pid)
        await refreshAll()
    }

    private func signal(pid: Int32, name: String, label: String?, graceful: Bool) async {
        killing.insert(pid)
        let result = await PortScanner.terminate(pid: pid, graceful: graceful)
        killing.remove(pid)
        report(result, name: name, label: label, pid: pid)
        await refreshPorts()
        if processWatchers > 0 { await refreshProcesses() }
    }

    private func report(_ result: PortScanner.KillResult, name: String, label: String?, pid: Int32) {
        let target = label.map { "\(name) on \($0)" } ?? name
        switch result {
        case .terminated: show("Stopped \(target).", style: .success)
        case .forced: show("Force-killed \(target).", style: .success)
        case .alreadyGone: show("\(target) had already exited.", style: .info)
        case .notPermitted: show("\(target) belongs to another user.", style: .warning, adminPID: pid)
        case .failed(let message): show("Could not stop \(target): \(message)", style: .warning)
        }
    }

    // MARK: - Quick tools

    func run(_ tool: QuickTool) async {
        guard !runningTools.contains(tool) else { return }
        runningTools.insert(tool)
        let result = await SystemTools.run(tool)
        runningTools.remove(tool)
        switch result {
        case .success(let message): show(message, style: .success)
        case .failure(let failure): show("\(tool.title): \(failure.message)", style: failure.message == "Cancelled." ? .info : .warning)
        }
        if tool == .purgeMemory { memory = SystemStats.memory() }
    }

    func copyLocalIP() {
        guard let ip = localIP ?? SystemStats.localIPAddress() else {
            show("No network address. Are you connected?", style: .warning)
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ip, forType: .string)
        show("Copied \(ip).", style: .success)
    }

    /// `nil` minutes keeps the Mac awake until turned off.
    func startKeepAwake(minutes: Int?) {
        keepAwakeTask?.cancel()
        guard keepAwake.start() else {
            show("macOS refused the keep-awake request.", style: .warning)
            return
        }
        isKeepingAwake = true
        keepAwakeUntil = minutes.map { Date().addingTimeInterval(TimeInterval($0 * 60)) }
        if let minutes {
            keepAwakeTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(minutes * 60))
                guard !Task.isCancelled else { return }
                self?.stopKeepAwake()
            }
        }
        show(minutes.map { "Keeping the Mac awake for \(Format.duration(TimeInterval($0 * 60)))." } ?? "Keeping the Mac awake until you turn it off.", style: .success)
    }

    func stopKeepAwake() {
        keepAwakeTask?.cancel()
        keepAwake.stop()
        isKeepingAwake = false
        keepAwakeUntil = nil
    }

    // MARK: - Status

    func show(_ message: String, style: Status.Style, adminPID: Int32? = nil) {
        status = Status(message: message, style: style, adminPID: adminPID)
        statusTask?.cancel()
        statusTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(adminPID == nil ? 4 : 10))
            guard !Task.isCancelled else { return }
            self?.status = nil
        }
    }
}
