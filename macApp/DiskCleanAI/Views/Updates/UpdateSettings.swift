import SwiftUI

/// Settings → Updates: the running version, manual and automatic update checks.
struct UpdateSettings: View {
    @Environment(UpdateChecker.self) private var updates
    @Environment(\.theme) private var theme
    @AppStorage(Pref.autoCheckUpdates) private var autoCheckUpdates = true

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Version \(AppConfig.versionString)")
                    Spacer()
                    Button(updates.isWorking ? "Checking…" : "Check for Updates") { updates.check(userInitiated: true) }
                        .disabled(updates.isWorking)
                }
                Toggle("Check for updates automatically", isOn: $autoCheckUpdates)
                if let release = updates.availableRelease {
                    Label("Version \(release.version) is available.", systemImage: "arrow.down.circle.fill").foregroundStyle(theme.brand)
                }
            } header: {
                Text("Updates")
            } footer: {
                Text("Updates come from the app's GitHub releases, are verified against the checksum GitHub publishes, and replace the app in place. The check is a single request to GitHub; nothing about you or your Mac is sent.")
                    .font(.system(size: 11)).foregroundStyle(theme.muted)
            }

            Section("Open source") {
                Link(destination: AppConfig.sourceURL) {
                    Label("Source code on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                Link(destination: AppConfig.releasesURL) {
                    Label("All releases", systemImage: "shippingbox")
                }
                Link(destination: AppConfig.issuesURL) {
                    Label("Report an issue or request a feature", systemImage: "exclamationmark.bubble")
                }
            }

            #if DEBUG
            Section("Developer") {
                LabeledContent("Release feed") { Text(AppConfig.latestReleaseAPI.absoluteString).font(.system(size: 11, design: .monospaced)) }
            }
            #endif
        }
        .formStyle(.grouped)
    }
}
