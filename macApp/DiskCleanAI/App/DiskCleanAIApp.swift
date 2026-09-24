import SwiftUI

/// Starts the real app, or an empty one when Xcode launches the app as the host for
/// unit tests. The tests only need the module loaded; the real app's windows, menu bar
/// monitor, Keychain clean-up and update check would run on every test launch, and on
/// a CI runner anything that waits for the user keeps the tests from ever starting.
@main
@MainActor
enum AppLauncher {
    static func main() {
        let environment = ProcessInfo.processInfo.environment
        let isTestHost = ["XCTestConfigurationFilePath", "XCTestSessionIdentifier", "XCTestBundlePath"]
            .contains { environment[$0] != nil }
        if isTestHost {
            TestHostApp.main()
        } else {
            DiskCleanAIApp.main()
        }
    }
}

private struct TestHostApp: App {
    var body: some Scene {
        Settings { EmptyView() }
    }
}

struct DiskCleanAIApp: App {
    @State private var appState = AppState()
    @State private var themes = ThemeManager()
    @State private var updates = UpdateChecker()
    @State private var monitor = SystemMonitor()

    var body: some Scene {
        @Bindable var monitor = monitor
        WindowGroup(id: MainWindow.id) {
            RootView()
                .environment(appState)
                .environment(themes)
                .environment(updates)
                .environment(monitor)
                .task {
                    KeychainStore.removeLegacyLicensing()
                    updates.checkAutomaticallyIfDue()
                }
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1280, height: 820)
        .commands {
            AppCommands(appState: appState, themes: themes, updates: updates)
        }

        Settings {
            SettingsView()
                .environment(appState)
                .environment(themes)
                .environment(updates)
                .environment(monitor)
        }

        MenuBarExtra(isInserted: $monitor.showInMenuBar) {
            MenuBarRoot()
                .environment(appState)
                .environment(themes)
                .environment(monitor)
        } label: {
            MenuBarLabel()
                .environment(monitor)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Resolves the theme against the system appearance and pushes it into the environment.
struct RootView: View {
    @Environment(ThemeManager.self) private var themes
    @Environment(UpdateChecker.self) private var updates
    @Environment(\.colorScheme) private var systemScheme

    var body: some View {
        @Bindable var updates = updates
        let theme = themes.resolved(for: systemScheme)
        ContentView()
            .environment(\.theme, theme)
            .tint(theme.brand)
            .preferredColorScheme(themes.preferredColorScheme)
            .frame(minWidth: 1024, minHeight: 640)
            .background(WindowConfigurator())
            .sheet(isPresented: $updates.showSheet) {
                UpdateSheet()
                    .environment(\.theme, theme)
                    .tint(theme.brand)
            }
    }
}

/// Keeps the window a standard resizable window: the green button zooms instead of
/// entering full screen, so close / minimise / zoom stay visible at the top-left.
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configure(nsView.window) }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        if window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }
        var behavior = window.collectionBehavior
        behavior.remove(.fullScreenPrimary)
        behavior.insert(.fullScreenNone)
        if window.collectionBehavior != behavior { window.collectionBehavior = behavior }
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(button)?.isHidden = false
        }
    }
}
