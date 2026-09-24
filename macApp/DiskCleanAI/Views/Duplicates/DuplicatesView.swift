import SwiftUI
import QuickLook

struct DuplicatesView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme
    @AppStorage(Pref.duplicateMinMB) private var minMB: Double = 1
    @State private var selectedGroup: DuplicateGroup.ID?
    @State private var previewURL: URL?

    enum KeepRule: String, CaseIterable, Identifiable {
        case newest, oldest, shortestPath
        var id: String { rawValue }
        var label: String {
            switch self {
            case .newest: return "Keep newest"
            case .oldest: return "Keep oldest"
            case .shortestPath: return "Keep shortest path"
            }
        }
    }
    @State private var keepRule: KeepRule = .newest

    var body: some View {
        switch appState.duplicates {
        case .idle:
            VStack(spacing: 16) {
                EmptyState(systemImage: "doc.on.doc", title: "Find duplicate files",
                           message: "Files are compared by size, then a partial hash, then a full SHA-256 — so a match is a byte-for-byte copy. App bundles, libraries and system folders are never touched.",
                           actionTitle: "Find Duplicates") { appState.findDuplicates() }
                HStack(spacing: 8) {
                    Text("Ignore files smaller than").font(.system(size: 12)).foregroundStyle(theme.body)
                    ChipPicker(options: [(0.1, "100 KB"), (1, "1 MB"), (10, "10 MB"), (100, "100 MB")], selection: $minMB)
                }
                .padding(.bottom, 40)
            }
        case .running:
            let p = appState.duplicateProgress
            ProgressState(title: "Hashing candidate files…", detail: p.total > 0 ? "\(Format.count(p.done)) of \(Format.count(p.total)) files compared" : "Grouping files by size",
                          fraction: p.total > 0 ? Double(p.done) / Double(p.total) : nil) { appState.cancelDuplicates() }
        case .failed(let message):
            EmptyState(systemImage: "exclamationmark.triangle", title: "Duplicate search failed", message: message, actionTitle: "Try Again") { appState.findDuplicates() }
        case .done(let groups):
            if groups.isEmpty {
                EmptyState(systemImage: "checkmark.seal", title: "No duplicates found", message: "No two files of \(Format.bytes(Int64(minMB * 1_048_576))) or more share the same bytes.", actionTitle: "Search Again") { appState.findDuplicates() }
            } else {
                results(groups)
            }
        }
    }

    private func results(_ groups: [DuplicateGroup]) -> some View {
        let wasted = groups.reduce(0) { $0 + $1.wastedBytes }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(title: "Duplicates", subtitle: "\(Format.count(groups.count)) groups · \(Format.bytes(wasted)) recoverable")
                Spacer()
                Picker("", selection: $keepRule) {
                    ForEach(KeepRule.allCases) { Text($0.label).tag($0) }
                }
                .frame(width: 180)
                Button {
                    let items = groups.flatMap { extras(in: $0) }.map { CleanupItem(node: $0, source: .duplicates, reason: "Duplicate copy — \(keepRule.label.lowercased())") }
                    appState.enqueue(items)
                } label: { Label("Add All Extras to Clean", systemImage: "plus.circle") }
                .buttonStyle(.primary)
                Button {
                    appState.findDuplicates()
                } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.secondary)
                .help("Search again")
            }

            HSplitView {
                List(groups, selection: $selectedGroup) { group in
                    HStack(spacing: 10) {
                        TypeIconView(ext: group.files[0].fileExtension, isDirectory: false, size: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.files[0].name).foregroundStyle(theme.ink).lineLimit(1)
                            Text("\(group.files.count) copies · \(Format.bytes(group.size)) each")
                                .font(.system(size: 11)).foregroundStyle(theme.muted)
                        }
                        Spacer()
                        Text(Format.bytes(group.wastedBytes))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(theme.brand)
                    }
                    .padding(.vertical, 3)
                    .tag(group.id)
                }
                .scrollContentBackground(.hidden)
                .background(theme.card)
                .frame(minWidth: 300, idealWidth: 380)

                Group {
                    if let group = groups.first(where: { $0.id == selectedGroup }) ?? groups.first {
                        groupDetail(group)
                    }
                }
                .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.surface)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(theme.line))
            .quickLookPreview($previewURL)
        }
        .padding(24)
        .onAppear { if selectedGroup == nil { selectedGroup = groups.first?.id } }
    }

    private func groupDetail(_ group: DuplicateGroup) -> some View {
        let keep = keeper(in: group)
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("\(group.files.count) identical copies · \(Format.bytes(group.size)) each")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.ink)
                    Spacer()
                    Button {
                        appState.enqueue(extras(in: group).map { CleanupItem(node: $0, source: .duplicates, reason: "Duplicate of \(keep?.name ?? group.files[0].name)") })
                    } label: { Label("Add extras", systemImage: "plus.circle") }
                    .buttonStyle(.secondary)
                }
                ForEach(group.files) { file in
                    let isKeeper = file === keep
                    HStack(alignment: .top, spacing: 12) {
                        if SimilarPhotoFinder.photoExtensions.contains(file.fileExtension) {
                            ThumbnailView(url: file.url, maxPixel: 160).frame(width: 64, height: 64)
                        } else {
                            FileIconView(url: file.url, isDirectory: false, size: 40).frame(width: 64, height: 64)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(file.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.ink).lineLimit(1)
                                if isKeeper { Badge(text: "Keep", color: theme.success) }
                                SafetyBadge(level: SafetyPolicy.assess(path: file.path, insidePackage: file.isInsidePackage))
                            }
                            Text(Format.tildePath(file.parent?.path ?? "")).font(.system(size: 11, design: .monospaced)).foregroundStyle(theme.muted).lineLimit(1).truncationMode(.middle)
                            Text("Modified \(Format.shortDate(file.modified)) · opened \(Format.daysAgo(file.accessed).lowercased())").font(.system(size: 11)).foregroundStyle(theme.body)
                        }
                        Spacer()
                        HStack(spacing: 6) {
                            Button { previewURL = file.url } label: { Image(systemName: "eye") }.buttonStyle(.secondary).help("Quick Look")
                            Button { TrashService.reveal(file.url) } label: { Image(systemName: "magnifyingglass") }.buttonStyle(.secondary).help("Reveal in Finder")
                            QueueToggle(appState: appState, node: file, source: .duplicates, reason: "Duplicate of \(keep?.name ?? file.name)")
                        }
                    }
                    .card(padding: 12)
                    .fileContextMenu(url: file.url, node: file, source: .duplicates, reason: "Duplicate copy", appState: appState)
                }
            }
            .padding(16)
        }
    }

    private func keeper(in group: DuplicateGroup) -> FileNode? {
        switch keepRule {
        case .newest: return group.files.max { ($0.modified ?? .distantPast) < ($1.modified ?? .distantPast) }
        case .oldest: return group.files.min { ($0.modified ?? .distantPast) < ($1.modified ?? .distantPast) }
        case .shortestPath: return group.files.min { $0.path.count < $1.path.count }
        }
    }

    private func extras(in group: DuplicateGroup) -> [FileNode] {
        let keep = keeper(in: group)
        return group.files.filter { $0 !== keep }
    }
}
