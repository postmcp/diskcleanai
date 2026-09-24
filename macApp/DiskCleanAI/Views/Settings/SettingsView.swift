import SwiftUI

struct SettingsView: View {
    @Environment(\.theme) private var theme
    @Environment(ThemeManager.self) private var themes
    @Environment(\.colorScheme) private var systemScheme

    var body: some View {
        let resolved = themes.resolved(for: systemScheme)
        TabView {
            GeneralSettings().tabItem { Label("General", systemImage: "gearshape") }
            AppearanceSettings().tabItem { Label("Appearance", systemImage: "paintpalette") }
            AISettings().tabItem { Label("AI", systemImage: "sparkles") }
            UpdateSettings().tabItem { Label("Updates", systemImage: "arrow.triangle.2.circlepath") }
            PrivacySettings().tabItem { Label("Privacy", systemImage: "hand.raised") }
            AboutSettings().tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 640, height: 560)
        .environment(\.theme, resolved)
        .tint(resolved.brand)
        .preferredColorScheme(themes.preferredColorScheme)
    }
}

struct GeneralSettings: View {
    @Environment(\.theme) private var theme
    @AppStorage(Pref.largeFileMinMB) private var largeFileMinMB: Double = 100
    @AppStorage(Pref.duplicateMinMB) private var duplicateMinMB: Double = 1
    @AppStorage(Pref.unusedDays) private var unusedDays = 90
    @AppStorage(Pref.downloadsOldDays) private var downloadsOldDays = 30
    @AppStorage(Pref.confirmBeforeClean) private var confirmBeforeClean = true
    @AppStorage(Pref.sidebarVolumeBar) private var sidebarVolumeBar = true
    @Environment(SystemMonitor.self) private var monitor
    @AppStorage(Pref.menuBarFreeSpace) private var menuBarFreeSpace = false
    @State private var excluded: [String] = Pref.excludedPaths

    var body: some View {
        @Bindable var monitor = monitor
        Form {
            Section("Thresholds") {
                Picker("Large files start at", selection: $largeFileMinMB) {
                    Text("10 MB").tag(10.0); Text("50 MB").tag(50.0); Text("100 MB").tag(100.0); Text("500 MB").tag(500.0); Text("1 GB").tag(1024.0)
                }
                Picker("Ignore duplicates smaller than", selection: $duplicateMinMB) {
                    Text("100 KB").tag(0.1); Text("1 MB").tag(1.0); Text("10 MB").tag(10.0); Text("100 MB").tag(100.0)
                }
                Picker("An app counts as unused after", selection: $unusedDays) {
                    Text("30 days").tag(30); Text("60 days").tag(60); Text("90 days").tag(90); Text("180 days").tag(180); Text("1 year").tag(365)
                }
                Picker("A download counts as old after", selection: $downloadsOldDays) {
                    Text("7 days").tag(7); Text("30 days").tag(30); Text("90 days").tag(90); Text("1 year").tag(365)
                }
            }
            Section("Cleanup") {
                Toggle("Ask for confirmation before moving items to the Trash", isOn: $confirmBeforeClean)
                Toggle("Show volume usage at the bottom of the sidebar", isOn: $sidebarVolumeBar)
            }
            Section {
                Toggle("Show Disk Clean AI in the menu bar", isOn: $monitor.showInMenuBar)
                Toggle("Show free disk space next to the icon", isOn: $menuBarFreeSpace)
                    .disabled(!monitor.showInMenuBar)
            } header: {
                Text("Menu bar")
            } footer: {
                Text("Disk, memory and CPU at a glance, listening ports with one-click kill, keep awake and quick fixes.").font(.system(size: 11)).foregroundStyle(theme.muted)
            }
            Section {
                ForEach(excluded, id: \.self) { path in
                    HStack {
                        Text(Format.tildePath(path)).font(.system(size: 12, design: .monospaced)).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button { excluded.removeAll { $0 == path }; Pref.excludedPaths = excluded } label: { Image(systemName: "minus.circle") }.buttonStyle(.plain)
                    }
                }
                Button("Add Folder to Exclude…") {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.allowsMultipleSelection = true
                    if panel.runModal() == .OK {
                        for url in panel.urls where !excluded.contains(url.path) { excluded.append(url.path) }
                        Pref.excludedPaths = excluded
                    }
                }
            } header: {
                Text("Excluded from scans")
            } footer: {
                Text("Other mounted volumes, Time Machine snapshots and system metadata folders are always skipped.").font(.system(size: 11)).foregroundStyle(theme.muted)
            }
        }
        .formStyle(.grouped)
    }
}

struct AppearanceSettings: View {
    @Environment(\.theme) private var theme
    @Environment(ThemeManager.self) private var themes

    private let columns = [GridItem(.adaptive(minimum: 170), spacing: 12)]

    var body: some View {
        @Bindable var themes = themes
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Theme").font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.ink)
                Text("Every theme restyles the whole window, including the sunburst and charts. Ocean is the default; Match System follows macOS between Daylight and Midnight.")
                    .font(.system(size: 12)).foregroundStyle(theme.body)
                LazyVGrid(columns: columns, spacing: 12) {
                    ThemeTile(theme: .daylight, title: "Match System", subtitle: "Daylight by day, Midnight in dark mode", isSelected: themes.selection == .system, isSystem: true) {
                        themes.selection = .system
                    }
                    ForEach(Theme.all) { t in
                        ThemeTile(theme: t, title: t.name, subtitle: t.tagline, isSelected: themes.selection == t.id, isSystem: false) {
                            themes.selection = t.id
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(theme.background)
    }
}

/// A miniature of the app window painted with the candidate theme.
struct ThemeTile: View {
    let theme: Theme
    let title: String
    let subtitle: String
    let isSelected: Bool
    let isSystem: Bool
    let action: () -> Void
    @Environment(\.theme) private var current

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(theme.background)
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(0..<4, id: \.self) { i in
                                Capsule().fill(i == 0 ? theme.brand : theme.line).frame(width: i == 0 ? 34 : 26, height: 4)
                            }
                            Spacer()
                        }
                        .padding(8)
                        .frame(width: 52)
                        .background(theme.surface)
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 3) {
                                ForEach(0..<6, id: \.self) { i in
                                    RoundedRectangle(cornerRadius: 2).fill(theme.chartColor(i)).frame(height: 10)
                                }
                            }
                            Capsule().fill(theme.ink).frame(width: 40, height: 4)
                            Capsule().fill(theme.muted).frame(width: 60, height: 3)
                            Spacer()
                            RoundedRectangle(cornerRadius: 3).fill(theme.card).overlay(RoundedRectangle(cornerRadius: 3).stroke(theme.line)).frame(height: 18)
                        }
                        .padding(8)
                    }
                    if isSystem {
                        HStack(spacing: 0) {
                            Spacer()
                            Rectangle().fill(Theme.midnight.background).frame(width: 44).overlay(Image(systemName: "moon.fill").foregroundStyle(Theme.midnight.brand).font(.system(size: 11)))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .frame(height: 92)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(isSelected ? current.brand : current.line, lineWidth: isSelected ? 2 : 1))
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(current.ink)
                        Text(subtitle).font(.system(size: 10.5)).foregroundStyle(current.muted).lineLimit(1)
                    }
                    Spacer()
                    if isSelected { Image(systemName: "checkmark.circle.fill").foregroundStyle(current.brand) }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct AISettings: View {
    @Environment(\.theme) private var theme
    @Environment(AppState.self) private var appState
    @AppStorage(Pref.model) private var model = Pref.defaultModel
    @State private var keyField = ""
    @State private var storedKey: String? = KeychainStore.read(account: KeychainStore.openRouterAccount)
    @State private var status: String?
    @State private var statusIsError = false
    @State private var models: [OpenRouterModel] = []
    @State private var loadingModels = false
    @State private var modelSearch = ""

    var body: some View {
        Form {
            Section {
                if let storedKey {
                    HStack {
                        Text(masked(storedKey)).font(.system(size: 12, design: .monospaced))
                        Spacer()
                        Badge(text: "In Keychain", color: theme.success)
                        Button("Remove") {
                            KeychainStore.delete(account: KeychainStore.openRouterAccount)
                            self.storedKey = nil
                            appState.refreshKeyStatus()
                            status = nil
                        }
                    }
                }
                HStack {
                    SecureField(storedKey == nil ? "sk-or-v1-…" : "Replace key", text: $keyField)
                        .textFieldStyle(.roundedBorder)
                    Button("Save & Verify") { saveAndVerify() }
                        .disabled(keyField.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if let status {
                    Text(status).font(.system(size: 11.5)).foregroundStyle(statusIsError ? theme.danger : theme.success)
                }
                Link("Get an OpenRouter key", destination: URL(string: "https://openrouter.ai/keys")!)
                    .font(.system(size: 12))
            } header: {
                Text("OpenRouter API key")
            } footer: {
                Text("Your key lives in the macOS Keychain and is only ever sent to openrouter.ai. Disk Clean AI does not resell AI credits or proxy your requests.")
                    .font(.system(size: 11)).foregroundStyle(theme.muted)
            }

            Section {
                HStack {
                    TextField("Model ID (e.g. anthropic/claude-sonnet-4.5)", text: $model)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                    Button(loadingModels ? "Loading…" : "Browse") { loadModels() }
                        .disabled(loadingModels || storedKey == nil)
                }
                if !models.isEmpty {
                    TextField("Filter models", text: $modelSearch).textFieldStyle(.roundedBorder)
                    List(filteredModels) { m in
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(m.displayName).font(.system(size: 12, weight: .medium))
                                Text(m.id).font(.system(size: 10.5, design: .monospaced)).foregroundStyle(theme.muted)
                            }
                            Spacer()
                            if let p = m.promptPricePerMillion, let c = m.completionPricePerMillion {
                                Text("$\(p, specifier: "%.2f") / $\(c, specifier: "%.2f") per 1M").font(.system(size: 10.5)).foregroundStyle(theme.muted)
                            }
                            if m.id == model { Image(systemName: "checkmark").foregroundStyle(theme.brand) }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { model = m.id }
                    }
                    .frame(height: 180)
                }
                HStack(spacing: 6) {
                    ForEach(["anthropic/claude-sonnet-4.5", "openai/gpt-4.1-mini", "google/gemini-2.5-flash", "meta-llama/llama-3.3-70b-instruct"], id: \.self) { id in
                        Button(id.split(separator: "/").last.map(String.init) ?? id) { model = id }
                            .buttonStyle(.secondary)
                    }
                }
            } header: {
                Text("Model")
            } footer: {
                Text("Any model OpenRouter offers works. Use a cheap one for everyday scans and a stronger one when you want more careful judgement.")
                    .font(.system(size: 11)).foregroundStyle(theme.muted)
            }
        }
        .formStyle(.grouped)
    }

    private var filteredModels: [OpenRouterModel] {
        modelSearch.isEmpty ? models : models.filter { $0.id.localizedCaseInsensitiveContains(modelSearch) || $0.displayName.localizedCaseInsensitiveContains(modelSearch) }
    }

    private func masked(_ key: String) -> String {
        guard key.count > 12 else { return "••••" }
        return key.prefix(9) + "••••••••••••" + key.suffix(4)
    }

    private func saveAndVerify() {
        let key = keyField.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try KeychainStore.save(key, account: KeychainStore.openRouterAccount)
            storedKey = key
            keyField = ""
            appState.refreshKeyStatus()
            status = "Saved. Verifying…"
            statusIsError = false
            Task {
                do {
                    let info = try await OpenRouterClient(apiKey: key).verifyKey()
                    var parts = ["Verified"]
                    if let label = info.label, !label.isEmpty { parts.append(label) }
                    if let usage = info.usage { parts.append("used \(Format.usd(usage))") }
                    if let limit = info.limit { parts.append("limit \(Format.usd(limit))") }
                    status = parts.joined(separator: " · ")
                } catch {
                    status = "Saved, but verification failed: \(error.localizedDescription)"
                    statusIsError = true
                }
            }
        } catch {
            status = "Could not save to Keychain: \(error.localizedDescription)"
            statusIsError = true
        }
    }

    private func loadModels() {
        guard let storedKey else { return }
        loadingModels = true
        Task {
            do {
                models = try await OpenRouterClient(apiKey: storedKey).listModels()
            } catch {
                status = "Could not load models: \(error.localizedDescription)"
                statusIsError = true
            }
            loadingModels = false
        }
    }
}

struct PrivacySettings: View {
    @Environment(\.theme) private var theme
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Section("What stays on this Mac") {
                Label("The scan, the sunburst, duplicates, similar photos and app inventory never leave your Mac.", systemImage: "internaldrive")
                Label("No accounts and no telemetry. The only thing sent to Disk Clean AI's server is your version number when checking for updates.", systemImage: "eye.slash")
                Label("Removals always go to the Trash and can be undone.", systemImage: "arrow.uturn.backward")
            }
            Section("What the AI sees") {
                Label("File paths, names, sizes, kinds and dates for the items listed on the AI Advisor screen.", systemImage: "list.bullet.rectangle")
                Label("Never file contents, never thumbnails, never anything from Mail, Messages or Photos.", systemImage: "lock")
                Label("Use \"Show what was sent\" on the AI Advisor screen to read the exact payload.", systemImage: "doc.text.magnifyingglass")
            }
            Section("Full Disk Access") {
                HStack {
                    Label(appState.hasFullDiskAccess ? "Granted" : "Not granted", systemImage: appState.hasFullDiskAccess ? "checkmark.shield" : "exclamationmark.shield")
                        .foregroundStyle(appState.hasFullDiskAccess ? theme.success : theme.warning)
                    Spacer()
                    Button("Open System Settings") { FullDiskAccess.openSystemSettings() }
                    Button("Check Again") { appState.hasFullDiskAccess = FullDiskAccess.isGranted() }
                }
                Text("Needed to see Mail, Messages, Safari data sizes and some Library folders. The app only ever reads names and sizes there.")
                    .font(.system(size: 11)).foregroundStyle(theme.muted)
            }
        }
        .formStyle(.grouped)
    }
}

struct AboutSettings: View {
    @Environment(\.theme) private var theme
    @Environment(UpdateChecker.self) private var updates

    var body: some View {
        VStack(spacing: 14) {
            Image("Mascot").resizable().interpolation(.high).frame(width: 96, height: 96)
            Text("Disk Clean AI").font(.system(size: 20, weight: .bold)).foregroundStyle(theme.ink)
            Text("Version \(AppConfig.versionString)")
                .font(.system(size: 12)).foregroundStyle(theme.muted)
            Text("Free, open-source Mac storage cleaner. Visualize every file, uncover hidden clutter, and safely reclaim space with AI — using your own OpenRouter key.")
                .font(.system(size: 12.5)).foregroundStyle(theme.body).multilineTextAlignment(.center).frame(maxWidth: 420)
            HStack(spacing: 10) {
                Link("Website", destination: AppConfig.websiteURL)
                Link("Source Code", destination: AppConfig.sourceURL)
                Link("Support", destination: URL(string: "mailto:\(AppConfig.supportEmail)")!)
                Link("OpenRouter", destination: URL(string: "https://openrouter.ai")!)
                Button("Check for Updates…") { updates.check(userInitiated: true) }.buttonStyle(.plain).foregroundStyle(theme.brand)
            }
            .font(.system(size: 12, weight: .medium))
            Text("© 2026 Redesignr AI. Free and open source under the MIT license.").font(.system(size: 11)).foregroundStyle(theme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }
}
