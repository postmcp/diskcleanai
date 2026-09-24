import SwiftUI
import AppKit

/// The icon in the macOS menu bar.
struct MenuBarLabel: View {
    @Environment(SystemMonitor.self) private var monitor
    @AppStorage(Pref.menuBarFreeSpace) private var showFreeSpace = false

    var body: some View {
        if showFreeSpace, let disk = monitor.disk {
            HStack(spacing: 3) {
                Image(systemName: "internaldrive")
                Text(Format.bytes(disk.availableCapacity))
            }
        } else {
            Image(systemName: "internaldrive")
        }
    }
}

/// Resolves the theme for the menu bar window the same way `RootView` does for the main one.
struct MenuBarRoot: View {
    @Environment(ThemeManager.self) private var themes
    @Environment(\.colorScheme) private var systemScheme

    var body: some View {
        let theme = themes.resolved(for: systemScheme)
        MenuBarView()
            .environment(\.theme, theme)
            .tint(theme.brand)
            .preferredColorScheme(themes.preferredColorScheme)
    }
}

/// Popover shown from the menu bar: disk / memory / CPU at a glance, the listening
/// ports with a kill button each, quick fixes and a way back into the app.
struct MenuBarView: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            gauges
            if let status = monitor.status {
                MonitorStatusBanner(status: status)
            }
            ports
            tools
            footer
        }
        .padding(14)
        .frame(width: 360)
        .background(theme.background)
        .animation(.easeOut(duration: 0.2), value: monitor.status)
        .onAppear { monitor.beginWatching() }
        .onDisappear { monitor.endWatching() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 22, height: 22)
            Text("Disk Clean AI").font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.ink)
            Spacer()
            Button("Open App") { showMainWindow() }
                .buttonStyle(.secondary)
        }
    }

    private var gauges: some View {
        HStack(spacing: 14) {
            if let disk = monitor.disk {
                MiniGauge(label: "Disk free", value: Format.bytes(disk.availableCapacity), fraction: disk.usedFraction,
                          color: disk.usedFraction > 0.9 ? theme.danger : theme.brand)
            }
            MiniGauge(label: "Memory", value: Format.percent(monitor.memory.fraction), fraction: monitor.memory.fraction,
                      color: monitor.memory.fraction > 0.9 ? theme.warning : theme.chartColor(3))
            MiniGauge(label: "CPU", value: monitor.cpu.map { Format.percent($0) } ?? "—", fraction: monitor.cpu ?? 0,
                      color: theme.chartColor(6))
        }
        .card(padding: 12, radius: 12)
    }

    private var ports: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Eyebrow(text: "Listening ports")
                Text("\(monitor.ports.count)").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(theme.muted)
                Spacer()
                IconButton(systemImage: "arrow.clockwise", color: theme.muted, help: "Refresh") {
                    Task { await monitor.refreshPorts() }
                }
            }
            KillPortField()
            if !monitor.portsLoaded {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity).padding(8)
            } else if monitor.ports.isEmpty {
                Text("Nothing is listening right now.")
                    .font(.system(size: 11.5)).foregroundStyle(theme.muted)
                    .frame(maxWidth: .infinity).padding(8)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(monitor.ports) { port in
                            PortRow(port: port, compact: true)
                        }
                    }
                }
                .defaultScrollAnchor(.top)
                .frame(height: min(CGFloat(monitor.ports.count) * 38, 190))
            }
        }
        .card(padding: 12, radius: 12)
    }

    private var tools: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: "Quick fixes")
            KeepAwakeRow()
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                ForEach(QuickTool.allCases) { tool in
                    QuickToolButton(tool: tool)
                }
            }
            Button { monitor.copyLocalIP() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "wifi").frame(width: 18).foregroundStyle(theme.brand)
                    Text("Copy IP").foregroundStyle(theme.ink)
                    Text(monitor.localIP ?? "offline").font(.system(size: 11, design: .monospaced)).foregroundStyle(theme.muted)
                    Spacer()
                }
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 9).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(theme.surface))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .card(padding: 12, radius: 12)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                appState.selection = .explore
                appState.startScan(URL(fileURLWithPath: "/"))
                showMainWindow()
            } label: { Label("Scan Disk", systemImage: "internaldrive") }
                .buttonStyle(.primary)
                .disabled(appState.isScanning)
            Button {
                appState.selection = .tools
                showMainWindow()
            } label: { Label("All Tools", systemImage: "wrench.and.screwdriver") }
                .buttonStyle(.secondary)
            Spacer()
            Menu {
                Button("Settings…") {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                }
                Divider()
                Button("Quit Disk Clean AI") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    /// Brings the existing main window forward, or opens one if it was closed.
    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        let main = NSApp.windows.first { window in
            window.identifier?.rawValue.hasPrefix(MainWindow.id) == true && (window.isVisible || window.isMiniaturized)
        }
        if let main {
            if main.isMiniaturized { main.deminiaturize(nil) }
            main.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: MainWindow.id)
        }
    }
}

enum MainWindow {
    static let id = "main"
}
