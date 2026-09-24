import SwiftUI

struct AppCommands: Commands {
    let appState: AppState
    let themes: ThemeManager
    let updates: UpdateChecker

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Check for Updates…") { updates.check(userInitiated: true) }
        }

        CommandGroup(replacing: .newItem) {
            Button("Scan Startup Disk") { appState.startScan(URL(fileURLWithPath: "/")) }
                .keyboardShortcut("n", modifiers: .command)
            Button("Scan Folder…") { appState.chooseFolder() }
                .keyboardShortcut("o", modifiers: .command)
            Button("Rescan") { appState.startScan() }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(appState.snapshot == nil)
            Divider()
            Button("Stop Scan") { appState.cancelScan() }
                .keyboardShortcut(".", modifiers: .command)
                .disabled(!appState.isScanning)
        }

        CommandMenu("Analyze") {
            Button("Explore") { appState.selection = .explore }
                .keyboardShortcut("1", modifiers: .command)
            Button("Apps") { appState.selection = .apps }
                .keyboardShortcut("3", modifiers: .command)
            Button("System Tools") { appState.selection = .tools }
                .keyboardShortcut("t", modifiers: .command)
            Divider()
            ForEach(FindTab.allCases) { tab in
                Button(tab.title) { appState.showFind(tab) }
            }
            Divider()
            Button("Find Duplicates") { appState.showFind(.duplicates); appState.findDuplicates() }
                .disabled(appState.snapshot == nil)
            Button("Find Similar Photos") { appState.showFind(.similarPhotos); appState.findSimilarPhotos() }
                .disabled(appState.snapshot == nil)
            Button("Ask AI for Suggestions") { appState.selection = .aiAdvisor; appState.runAIAnalysis() }
                .keyboardShortcut("i", modifiers: [.command, .shift])
        }

        CommandMenu("Clean") {
            Button("Review & Clean") { appState.selection = .cleanup }
                .keyboardShortcut("k", modifiers: .command)
            Button("Move Approved Items to Trash") { appState.selection = .cleanup; appState.performCleanup() }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(appState.approvedItems.isEmpty || appState.isCleaning)
            Button("Undo Last Cleanup") { appState.undoLastCleanup() }
                .disabled(appState.lastBatch == nil)
            Divider()
            Button("Clear Queue") { appState.clearQueue() }
                .disabled(appState.queue.isEmpty)
        }

        CommandGroup(after: .toolbar) {
            ThemeMenu(themes: themes)
            Divider()
        }

        CommandGroup(replacing: .help) {
            Link("Disk Clean AI Website", destination: AppConfig.websiteURL)
            Link("Source Code on GitHub", destination: AppConfig.sourceURL)
            Link("Report an Issue", destination: AppConfig.issuesURL)
            Link("Contact Support", destination: URL(string: "mailto:\(AppConfig.supportEmail)")!)
            Link("Get an OpenRouter Key", destination: URL(string: "https://openrouter.ai/keys")!)
            Divider()
            Button("Grant Full Disk Access…") { FullDiskAccess.openSystemSettings() }
        }
    }
}

struct ThemeMenu: View {
    let themes: ThemeManager

    var body: some View {
        @Bindable var themes = themes
        Picker("Theme", selection: $themes.selection) {
            Text(ThemeID.system.displayName).tag(ThemeID.system)
            Divider()
            ForEach(Theme.all) { theme in
                Text(theme.name).tag(theme.id)
            }
        }
        .pickerStyle(.inline)
    }
}
