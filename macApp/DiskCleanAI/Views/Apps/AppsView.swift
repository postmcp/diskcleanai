import SwiftUI

struct AppsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme
    @AppStorage(Pref.unusedDays) private var unusedDays = 90
    @State private var filter: Filter = .all
    @State private var search = ""
    @State private var selected: InstalledApp.ID?
    @State private var sortOrder = [KeyPathComparator(\InstalledApp.totalBytes, order: .reverse)]

    enum Filter: Hashable { case all, unused, leftovers }

    var body: some View {
        Group {
            switch appState.apps {
            case .idle, .running:
                ProgressState(title: "Reading installed apps…", detail: "Sizes, last-opened dates and leftover support files")
            case .failed(let message):
                EmptyState(systemImage: "exclamationmark.triangle", title: "Could not read apps", message: message, actionTitle: "Try Again") { appState.loadApps(force: true) }
            case .done(let apps):
                content(apps)
            }
        }
        .onAppear { appState.loadApps() }
    }

    private func content(_ apps: [InstalledApp]) -> some View {
        let rows = filtered(apps)
        let unused = apps.filter { $0.isUnused(days: unusedDays) }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(title: "Apps", subtitle: "\(apps.count) apps · \(Format.bytes(apps.reduce(0) { $0 + $1.totalBytes })) including leftovers")
                Spacer()
                Button { appState.loadApps(force: true) } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.secondary).help("Reload")
            }
            HStack(spacing: 12) {
                StatTile(label: "Unused for \(unusedDays)+ days", value: "\(unused.count)", detail: Format.bytes(unused.reduce(0) { $0 + $1.totalBytes }), color: theme.warning)
                StatTile(label: "Leftover support files", value: Format.bytes(apps.reduce(0) { $0 + $1.leftoverBytes }), detail: "Caches, logs, preferences, saved state")
                StatTile(label: "Largest app", value: apps.max { $0.size < $1.size }?.name ?? "—", detail: apps.max { $0.size < $1.size }.map { Format.bytes($0.size) })
            }
            HStack(spacing: 10) {
                ChipPicker(options: [(Filter.all, "All"), (.unused, "Unused"), (.leftovers, "With leftovers")], selection: $filter)
                Picker("Unused after", selection: $unusedDays) {
                    Text("30 days").tag(30); Text("60 days").tag(60); Text("90 days").tag(90); Text("180 days").tag(180); Text("1 year").tag(365)
                }
                .frame(width: 170)
                Spacer()
                TextField("Search apps", text: $search).textFieldStyle(.roundedBorder).frame(width: 220)
            }

            HSplitView {
                Table(rows, selection: $selected, sortOrder: $sortOrder) {
                    TableColumn("App", value: \.name) { app in
                        HStack(spacing: 8) {
                            FileIconView(url: app.url, isDirectory: true, size: 22)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(app.name).foregroundStyle(theme.ink).lineLimit(1)
                                Text(app.version.map { "v\($0)" } ?? "").font(.system(size: 10.5)).foregroundStyle(theme.muted)
                            }
                        }
                    }
                    .width(min: 200, ideal: 260)
                    TableColumn("Size", value: \.size) { app in
                        Text(Format.bytes(app.size)).font(.system(size: 12, design: .monospaced)).foregroundStyle(theme.ink)
                    }
                    .width(90)
                    TableColumn("Leftovers", value: \.leftoverBytes) { app in
                        Text(app.leftovers.isEmpty ? "—" : Format.bytes(app.leftoverBytes)).font(.system(size: 12, design: .monospaced)).foregroundStyle(theme.body)
                    }
                    .width(90)
                    TableColumn("Last opened", value: \.sortableLastUsed) { app in
                        Text(Format.daysAgo(app.lastUsed))
                            .foregroundStyle(app.isUnused(days: unusedDays) ? theme.warning : theme.muted)
                    }
                    .width(120)
                }
                .scrollContentBackground(.hidden)
                .background(theme.card)
                .frame(minWidth: 420)

                Group {
                    if let app = rows.first(where: { $0.id == selected }) {
                        AppDetail(app: app)
                    } else {
                        EmptyState(systemImage: "app.badge", title: "Select an app", message: "See its size, when it was last opened, and the support files it leaves in your Library.")
                    }
                }
                .frame(minWidth: 320, idealWidth: 380, maxWidth: 460, maxHeight: .infinity)
                .background(theme.surface)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(theme.line))
        }
        .padding(24)
    }

    private func filtered(_ apps: [InstalledApp]) -> [InstalledApp] {
        var rows = apps.filter { app in
            switch filter {
            case .all: break
            case .unused: if !app.isUnused(days: unusedDays) { return false }
            case .leftovers: if app.leftovers.isEmpty { return false }
            }
            if !search.isEmpty, !app.name.localizedCaseInsensitiveContains(search) { return false }
            return true
        }
        rows.sort(using: sortOrder)
        return rows
    }
}

extension InstalledApp {
    var sortableLastUsed: Date { lastUsed ?? .distantPast }
}

struct AppDetail: View {
    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme
    let app: InstalledApp

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    FileIconView(url: app.url, isDirectory: true, size: 56)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(app.name).font(.system(size: 17, weight: .bold)).foregroundStyle(theme.ink)
                        Text(app.bundleID ?? app.url.lastPathComponent).font(.system(size: 11, design: .monospaced)).foregroundStyle(theme.muted).lineLimit(1)
                        Text("Last opened \(Format.daysAgo(app.lastUsed).lowercased()) · installed \(Format.shortDate(app.installed))").font(.system(size: 11.5)).foregroundStyle(theme.body)
                    }
                }
                HStack(spacing: 10) {
                    StatTile(label: "App bundle", value: Format.bytes(app.size))
                    StatTile(label: "Leftovers", value: Format.bytes(app.leftoverBytes), detail: "\(app.leftovers.count) locations")
                }
                HStack(spacing: 8) {
                    Button {
                        var items = [CleanupItem(url: app.url, size: app.size, source: .apps, reason: "Uninstall \(app.name) — last opened \(Format.daysAgo(app.lastUsed).lowercased())", isDirectory: true)]
                        items += app.leftovers.map { CleanupItem(url: $0.url, size: $0.size, source: .apps, reason: "\($0.kind) left by \(app.name)", isDirectory: $0.isDirectory) }
                        appState.enqueue(items)
                    } label: { Label("Uninstall", systemImage: "trash") }
                    .buttonStyle(.primary)
                    .disabled(!app.isRemovable || appState.isQueued(app.url))
                    .help(app.isRemovable ? "Queue the app and its leftovers for the Trash" : "This app is managed by macOS and cannot be removed here")

                    Button {
                        appState.enqueue(app.leftovers.map { CleanupItem(url: $0.url, size: $0.size, source: .apps, reason: "\($0.kind) left by \(app.name)", isDirectory: $0.isDirectory) })
                    } label: { Label("Clean leftovers only", systemImage: "sparkles") }
                    .buttonStyle(.secondary)
                    .disabled(app.leftovers.isEmpty)

                    Button { TrashService.reveal(app.url) } label: { Image(systemName: "magnifyingglass") }
                        .buttonStyle(.secondary).help("Reveal in Finder")
                }

                if !app.leftovers.isEmpty {
                    Text("Support files").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(theme.ink)
                    VStack(spacing: 0) {
                        ForEach(app.leftovers) { item in
                            HStack(spacing: 8) {
                                Image(systemName: item.isDirectory ? "folder" : "doc").foregroundStyle(theme.muted).frame(width: 16)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.kind).font(.system(size: 12, weight: .medium)).foregroundStyle(theme.ink)
                                    Text(Format.tildePath(item.url.path)).font(.system(size: 10.5, design: .monospaced)).foregroundStyle(theme.muted).lineLimit(1).truncationMode(.middle)
                                }
                                Spacer()
                                Text(Format.bytes(item.size)).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(theme.body)
                                Button {
                                    if appState.isQueued(item.url) { appState.dequeue(item.url) } else {
                                        appState.enqueue(CleanupItem(url: item.url, size: item.size, source: .apps, reason: "\(item.kind) left by \(app.name)", isDirectory: item.isDirectory))
                                    }
                                } label: {
                                    Image(systemName: appState.isQueued(item.url) ? "checkmark.circle.fill" : "plus.circle")
                                        .foregroundStyle(appState.isQueued(item.url) ? theme.brand : theme.muted)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 7)
                            .fileContextMenu(url: item.url, source: .apps, reason: "\(item.kind) left by \(app.name)", appState: appState)
                            Divider().overlay(theme.line)
                        }
                    }
                    .card(padding: 12)
                } else {
                    Text("No support files found outside the app bundle.").font(.system(size: 12)).foregroundStyle(theme.muted)
                }
            }
            .padding(16)
        }
    }
}
