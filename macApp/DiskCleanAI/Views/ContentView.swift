import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var themes
    @Environment(\.theme) private var theme
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        @Bindable var appState = appState
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } detail: {
            DetailView()
        }
        .background(theme.background)
        .toolbar { toolbarContent }
        .overlay(alignment: .bottom) {
            if let toast = appState.toast {
                ToastView(toast: toast)
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: appState.toast)
        .onAppear {
            appState.hasFullDiskAccess = FullDiskAccess.isGranted()
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            LocationMenu()
        }
        ToolbarItemGroup(placement: .primaryAction) {
            if appState.isScanning {
                Button {
                    appState.cancelScan()
                } label: {
                    Label("Stop", systemImage: "stop.circle")
                }
                .help("Stop the current scan (⌘.)")
            } else {
                Button {
                    appState.startScan()
                } label: {
                    Label(appState.snapshot == nil ? "Scan" : "Rescan", systemImage: "arrow.clockwise")
                }
                .help("Scan the selected location (⌘R)")
            }

            Menu {
                ThemeMenu(themes: themes)
            } label: {
                Label("Theme", systemImage: "paintpalette")
            }
            .help("Switch theme")

            Button {
                appState.selection = .cleanup
            } label: {
                Label("Review & Clean", systemImage: "trash")
            }
            .badge(appState.queue.count)
            .help("Review the cleanup queue (⌘K)")
        }
    }
}

/// Volume / folder chooser in the toolbar.
struct LocationMenu: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Menu {
            Section("Volumes") {
                ForEach(appState.volumes) { volume in
                    Button {
                        appState.startScan(volume.url)
                    } label: {
                        Label("\(volume.name)  ·  \(Format.bytes(volume.usedCapacity)) of \(Format.bytes(volume.totalCapacity))", systemImage: volume.isRemovable ? "externaldrive" : "internaldrive")
                    }
                }
            }
            Section("Home") {
                Button {
                    appState.startScan(FileManager.default.homeDirectoryForCurrentUser)
                } label: { Label("Home folder", systemImage: "house") }
                Button {
                    appState.startScan(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library"))
                } label: { Label("~/Library", systemImage: "books.vertical") }
            }
            Divider()
            Button("Choose Folder…") { appState.chooseFolder() }
                .keyboardShortcut("o", modifiers: .command)
        } label: {
            Label(locationTitle, systemImage: appState.scanRoot.path == "/" ? "internaldrive" : "folder")
        }
        .disabled(appState.isScanning)
        .help("Choose what to scan")
    }

    private var locationTitle: String {
        if appState.scanRoot.path == "/" { return appState.volumes.first(where: \.isRoot)?.name ?? "Macintosh HD" }
        return Format.tildePath(appState.scanRoot.path)
    }
}

/// Large files, duplicates, downloads and similar photos under one roof.
struct FindView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme

    var body: some View {
        @Bindable var appState = appState
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 2) {
                    ForEach(FindTab.allCases) { tab in
                        let selected = appState.findTab == tab
                        Button { appState.findTab = tab } label: {
                            Label(tab.title, systemImage: tab.systemImage)
                                .font(.system(size: 12.5, weight: selected ? .semibold : .medium))
                                .lineLimit(1)
                                .fixedSize()
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .foregroundStyle(selected ? Color.white : theme.body)
                                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(selected ? theme.ink : Color.clear))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(theme.card))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(theme.line))
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            DetailView.ScanGate(needsScan: appState.findTab.needsScan) {
                switch appState.findTab {
                case .largeFiles: LargeFilesView()
                case .duplicates: DuplicatesView()
                case .downloads: DownloadsView()
                case .similarPhotos: SimilarPhotosView()
                }
            }
        }
    }
}

/// Routes the sidebar selection to a screen and handles the no-scan states.
struct DetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme

    var body: some View {
        Group {
            switch appState.selection ?? .explore {
            case .explore: scanGated { ExploreView() }
            case .find: FindView()
            case .apps: AppsView()
            case .aiAdvisor: AIAdvisorView()
            case .cleanup: CleanupReviewView()
            case .tools: ToolsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }

    private func scanGated<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        ScanGate(needsScan: true, content: content)
    }

    /// Shows the welcome, scanning or failure state until a snapshot exists.
    struct ScanGate<Content: View>: View {
        @Environment(AppState.self) private var appState
        let needsScan: Bool
        @ViewBuilder let content: () -> Content

        var body: some View {
            if !needsScan {
                content()
            } else {
                switch appState.phase {
                case .scanning:
                    ScanningView()
                case .failed(let message):
                    EmptyState(systemImage: "exclamationmark.triangle", title: "The scan could not finish", message: message, actionTitle: "Try Again") {
                        appState.startScan()
                    }
                case .idle, .done:
                    if appState.snapshot == nil {
                        WelcomeView()
                    } else {
                        content()
                    }
                }
            }
        }
    }
}
