import SwiftUI

/// Listening ports, live memory / CPU, the heaviest processes and one-click fixes.
struct ToolsView: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(\.theme) private var theme
    @State private var search = ""
    @State private var processSort: ProcessSort = .memory

    enum ProcessSort: Hashable { case memory, cpu }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    SectionTitle(title: "System Tools", subtitle: "Listening ports, memory and quick fixes. Updates every few seconds while open.")
                    Spacer()
                    Button { Task { await monitor.refreshAll() } } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.secondary).help("Refresh now")
                }
                stats
                if let status = monitor.status {
                    MonitorStatusBanner(status: status)
                }
                HStack(alignment: .top, spacing: 16) {
                    portsCard.frame(maxWidth: .infinity)
                    toolsCard.frame(width: 300)
                }
                processesCard
            }
            .padding(24)
            .animation(.easeOut(duration: 0.2), value: monitor.status)
        }
        .onAppear { monitor.beginWatching(processes: true) }
        .onDisappear { monitor.endWatching(processes: true) }
    }

    // MARK: Stats

    private var stats: some View {
        HStack(spacing: 12) {
            if let disk = monitor.disk {
                StatTile(label: "Free on \(disk.name)", value: Format.bytes(disk.availableCapacity),
                         detail: "\(Format.percent(disk.usedFraction)) of \(Format.bytes(disk.totalCapacity)) used",
                         color: disk.usedFraction > 0.9 ? theme.danger : nil)
            }
            StatTile(label: "Memory used", value: Format.bytes(Int64(monitor.memory.used)),
                     detail: "of \(Format.bytes(Int64(monitor.memory.total))) · \(Format.bytes(Int64(monitor.memory.compressed))) compressed",
                     color: monitor.memory.fraction > 0.9 ? theme.warning : nil)
            StatTile(label: "CPU", value: monitor.cpu.map { Format.percent($0) } ?? "—",
                     detail: "\(ProcessInfo.processInfo.activeProcessorCount) cores · swap \(Format.bytes(Int64(monitor.memory.swapUsed)))")
            StatTile(label: "Local IP", value: monitor.localIP ?? "Offline",
                     detail: "\(monitor.ports.count) listening port\(monitor.ports.count == 1 ? "" : "s")")
                .onTapGesture { monitor.copyLocalIP() }
                .help("Click to copy")
        }
    }

    // MARK: Ports

    private var filteredPorts: [ListeningPort] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return monitor.ports }
        return monitor.ports.filter {
            "\($0.port)".hasPrefix(query) || $0.command.lowercased().contains(query) || "\($0.pid)" == query
        }
    }

    private var portsCard: some View {
        @Bindable var monitor = monitor
        let rows = filteredPorts
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Eyebrow(text: "Listening ports")
                Text("\(monitor.ports.count)").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(theme.muted)
                Spacer()
                Toggle("UDP", isOn: $monitor.includeUDP).toggleStyle(.checkbox).font(.system(size: 11.5))
                    .help("Also list bound UDP sockets")
            }
            HStack(spacing: 8) {
                TextField("Filter by port, name or PID", text: $search)
                    .textFieldStyle(.roundedBorder)
                KillPortField().frame(width: 230)
            }
            Divider()
            if !monitor.portsLoaded {
                ProgressView().frame(maxWidth: .infinity).padding(24)
            } else if rows.isEmpty {
                Text(monitor.ports.isEmpty ? "Nothing is listening. Start a dev server and it shows up here." : "No port matches “\(search)”.")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(24)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(rows) { port in
                        PortRow(port: port)
                        if port.id != rows.last?.id { Divider().opacity(0.6) }
                    }
                }
            }
            Text("Shows processes running as \(NSUserName()). Right-click a row to quit gracefully, force kill or kill as administrator.")
                .font(.system(size: 10.5))
                .foregroundStyle(theme.muted)
        }
        .card()
    }

    // MARK: Tools

    private var toolsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "Quick fixes")
            KeepAwakeRow()
            ForEach(QuickTool.allCases) { tool in
                QuickToolButton(tool: tool, showsDetail: true)
            }
        }
        .card()
    }

    // MARK: Processes

    private var processesCard: some View {
        let sorted = monitor.processes.sorted {
            processSort == .memory ? $0.memory > $1.memory : $0.cpu > $1.cpu
        }.prefix(10)
        let maxMemory = Double(sorted.map(\.memory).max() ?? 1)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Eyebrow(text: "Heaviest processes")
                Spacer()
                ChipPicker(options: [(ProcessSort.memory, "Memory"), (.cpu, "CPU")], selection: $processSort)
            }
            if sorted.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding(16)
            }
            ForEach(Array(sorted)) { process in
                HStack(spacing: 10) {
                    ProcessIcon(pid: process.pid)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(process.name).font(.system(size: 12.5, weight: .medium)).foregroundStyle(theme.ink).lineLimit(1)
                        Text(verbatim: "PID \(process.pid)\(process.isOwnedByUser ? "" : " · system")").font(.system(size: 10.5)).foregroundStyle(theme.muted)
                    }
                    .frame(width: 220, alignment: .leading)
                    SizeBar(fraction: Double(process.memory) / maxMemory, color: theme.chartColor(3))
                    Text(Format.bytes(Int64(process.memory))).font(.system(size: 11.5, weight: .medium)).foregroundStyle(theme.body).frame(width: 72, alignment: .trailing)
                    Text(String(format: "%.1f%%", process.cpu)).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(theme.body).frame(width: 60, alignment: .trailing)
                    if monitor.killing.contains(process.pid) {
                        ProgressView().controlSize(.small).frame(width: 60)
                    } else if process.isOwnedByUser {
                        Button("Quit") { Task { await monitor.quit(process) } }
                            .buttonStyle(.secondary)
                            .frame(width: 60)
                    } else {
                        Image(systemName: "lock.fill").font(.system(size: 10)).foregroundStyle(theme.muted).frame(width: 60)
                            .help("Owned by another user")
                    }
                }
                .contextMenu {
                    Button("Quit") { Task { await monitor.quit(process) } }
                    Button("Force Quit") { Task { await monitor.quit(process, force: true) } }
                    if !process.isOwnedByUser {
                        Button("Force Quit as Administrator…") { Task { await monitor.killAsAdministrator(pid: process.pid) } }
                    }
                }
            }
        }
        .card()
    }
}
