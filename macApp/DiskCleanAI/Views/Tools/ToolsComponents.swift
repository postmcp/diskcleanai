import SwiftUI
import AppKit

/// Pieces shared by the Tools screen and the menu bar extra.

struct PortRow: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(\.theme) private var theme
    let port: ListeningPort
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 8 : 10) {
            Text(verbatim: ":\(port.port)")
                .font(.system(size: compact ? 12 : 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.ink)
                .frame(width: compact ? 54 : 64, alignment: .leading)
            ProcessIcon(pid: port.pid, size: compact ? 16 : 18)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(port.command).font(.system(size: compact ? 12 : 12.5, weight: .medium)).foregroundStyle(theme.ink).lineLimit(1)
                    if port.systemHint != nil {
                        Image(systemName: "info.circle").font(.system(size: 10)).foregroundStyle(theme.muted)
                    }
                }
                Text(verbatim: "PID \(port.pid) · \(port.proto.rawValue) · \(port.bindingLabel)")
                    .font(.system(size: 10.5))
                    .foregroundStyle(theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if !compact {
                Text(port.user).font(.system(size: 11)).foregroundStyle(theme.muted).lineLimit(1).frame(width: 90, alignment: .trailing)
            }
            if let url = port.browserURL {
                IconButton(systemImage: "safari", help: "Open \(url.absoluteString)") { NSWorkspace.shared.open(url) }
            }
            if monitor.killing.contains(port.pid) {
                ProgressView().controlSize(.small).frame(width: 22)
            } else {
                IconButton(systemImage: "xmark.circle.fill", color: theme.danger, help: "Stop \(port.command) (SIGTERM, then SIGKILL if it hangs)") {
                    Task { await monitor.kill(port) }
                }
            }
        }
        .padding(.vertical, compact ? 4 : 6)
        .contentShape(Rectangle())
        .help(port.systemHint ?? "")
        .contextMenu {
            if let url = port.browserURL {
                Button("Open in Browser") { NSWorkspace.shared.open(url) }
                Button("Copy URL") { copy(url.absoluteString) }
            }
            Button("Copy PID") { copy("\(port.pid)") }
            Button("Copy Kill Command") { copy("kill -9 \(port.pid)") }
            Divider()
            Button("Quit Gracefully (SIGTERM)") { Task { await monitor.kill(port, graceful: true) } }
            Button("Force Kill (SIGKILL)") { Task { await monitor.forceKill(port) } }
            Button("Kill as Administrator…") { Task { await monitor.killAsAdministrator(pid: port.pid) } }
        }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

/// App icon for GUI processes, a terminal glyph for everything else.
struct ProcessIcon: View {
    @Environment(\.theme) private var theme
    let pid: Int32
    var size: CGFloat = 18

    var body: some View {
        if let icon = NSRunningApplication(processIdentifier: pid)?.icon {
            Image(nsImage: icon).resizable().interpolation(.high).frame(width: size, height: size)
        } else {
            Image(systemName: "terminal")
                .font(.system(size: size * 0.6, weight: .medium))
                .foregroundStyle(theme.body)
                .frame(width: size, height: size)
                .background(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous).fill(theme.surface))
        }
    }
}

struct IconButton: View {
    @Environment(\.theme) private var theme
    let systemImage: String
    var color: Color? = nil
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14))
                .foregroundStyle(color ?? theme.body)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// Text field that kills whatever listens on the typed port.
struct KillPortField: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(\.theme) private var theme
    @State private var text = ""
    @State private var isWorking = false

    var body: some View {
        HStack(spacing: 6) {
            TextField("Port, e.g. 3000", text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .onChange(of: text) { _, value in
                    let digits = String(value.filter(\.isNumber).prefix(5))
                    if digits != value { text = digits }
                }
                .onSubmit(submit)
            Button(action: submit) {
                if isWorking { ProgressView().controlSize(.mini) } else { Text("Kill Port") }
            }
            .buttonStyle(.danger)
            .disabled(port == nil || isWorking)
        }
    }

    private var port: Int? {
        guard let value = Int(text), (1...65535).contains(value) else { return nil }
        return value
    }

    private func submit() {
        guard let port else { return }
        isWorking = true
        Task {
            await monitor.killPort(port)
            isWorking = false
            text = ""
        }
    }
}

struct MonitorStatusBanner: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(\.theme) private var theme
    let status: SystemMonitor.Status

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(status.message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if let pid = status.adminPID {
                Button("Use Admin Password") { Task { await monitor.killAsAdministrator(pid: pid) } }
                    .buttonStyle(.secondary)
            }
            IconButton(systemImage: "xmark", color: theme.muted, help: "Dismiss") { monitor.status = nil }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(color.opacity(0.12)))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var icon: String {
        switch status.style {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch status.style {
        case .info: return theme.brand
        case .success: return theme.success
        case .warning: return theme.warning
        }
    }
}

/// Small labelled bar used in the menu bar header.
struct MiniGauge: View {
    @Environment(\.theme) private var theme
    let label: String
    let value: String
    let fraction: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 10.5, weight: .medium)).foregroundStyle(theme.muted)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .contentTransition(.numericText())
            SizeBar(fraction: fraction, color: color, height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct QuickToolButton: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(\.theme) private var theme
    let tool: QuickTool
    var showsDetail = false

    var body: some View {
        Button { Task { await monitor.run(tool) } } label: {
            HStack(spacing: 8) {
                Group {
                    if monitor.runningTools.contains(tool) {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: tool.systemImage).font(.system(size: 12, weight: .medium)).foregroundStyle(theme.brand)
                    }
                }
                .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(showsDetail ? tool.title : tool.shortTitle).font(.system(size: 12, weight: .medium)).foregroundStyle(theme.ink).lineLimit(1)
                    if showsDetail {
                        Text(tool.detail).font(.system(size: 10.5)).foregroundStyle(theme.muted).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if tool.needsAdmin {
                    Image(systemName: "lock.fill").font(.system(size: 9)).foregroundStyle(theme.muted)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, showsDetail ? 8 : 7)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(theme.surface))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(monitor.runningTools.contains(tool))
        .help(tool.detail + (tool.needsAdmin ? " (asks for an administrator password)" : ""))
    }
}

struct KeepAwakeRow: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: monitor.isKeepingAwake ? "cup.and.saucer.fill" : "cup.and.saucer")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(monitor.isKeepingAwake ? theme.success : theme.brand)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text("Keep Awake").font(.system(size: 12, weight: .medium)).foregroundStyle(theme.ink)
                Text(subtitle).font(.system(size: 10.5)).foregroundStyle(theme.muted).lineLimit(1)
            }
            Spacer(minLength: 0)
            Menu {
                Button("15 Minutes") { monitor.startKeepAwake(minutes: 15) }
                Button("1 Hour") { monitor.startKeepAwake(minutes: 60) }
                Button("2 Hours") { monitor.startKeepAwake(minutes: 120) }
                Button("8 Hours") { monitor.startKeepAwake(minutes: 480) }
                Button("Until Turned Off") { monitor.startKeepAwake(minutes: nil) }
                if monitor.isKeepingAwake {
                    Divider()
                    Button("Turn Off") { monitor.stopKeepAwake() }
                }
            } label: {
                Text(monitor.isKeepingAwake ? "On" : "Off")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(theme.surface))
        .help("Stops the Mac and its display from sleeping, like caffeinate")
    }

    private var subtitle: String {
        guard monitor.isKeepingAwake else { return "Display and Mac sleep normally" }
        guard let until = monitor.keepAwakeUntil else { return "Until you turn it off" }
        return "Until \(until.formatted(date: .omitted, time: .shortened))"
    }
}
