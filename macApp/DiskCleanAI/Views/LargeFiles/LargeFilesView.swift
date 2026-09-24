import SwiftUI
import QuickLook

struct LargeFilesView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme
    @AppStorage(Pref.largeFileMinMB) private var minMB: Double = 100
    @State private var search = ""
    @State private var selection: Set<FileNode.ID> = []
    @State private var sortOrder = [KeyPathComparator(\FileNode.size, order: .reverse)]
    @State private var previewURL: URL?
    @State private var hideProtected = true

    private let sizeOptions: [(Double, String)] = [(10, "10 MB+"), (50, "50 MB+"), (100, "100 MB+"), (500, "500 MB+"), (1024, "1 GB+")]

    var body: some View {
        if let snapshot = appState.snapshot {
            let rows = filtered(snapshot)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(title: "Large Files", subtitle: "\(Format.count(rows.count)) files · \(Format.bytes(rows.reduce(0) { $0 + $1.size }))")
                    Spacer()
                    Button {
                        let nodes = rows.filter { selection.contains($0.id) }
                        appState.enqueue(nodes.map { CleanupItem(node: $0, source: .largeFiles, reason: "Large file (\(Format.bytes($0.size)))") })
                    } label: { Label("Add \(selection.count) to Clean", systemImage: "plus.circle") }
                    .buttonStyle(.primary)
                    .disabled(selection.isEmpty)
                }

                HStack(spacing: 10) {
                    ChipPicker(options: sizeOptions, selection: $minMB)
                    Divider().frame(height: 18)
                    Picker("Category", selection: categoryBinding) {
                        Text("All categories").tag(FileCategory?.none)
                        ForEach(FileCategory.allCases) { Text($0.label).tag(FileCategory?.some($0)) }
                    }
                    .frame(width: 170)
                    Toggle("Hide protected", isOn: $hideProtected)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 12))
                    Spacer()
                    TextField("Search names and paths", text: $search)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 240)
                }

                Table(rows, selection: $selection, sortOrder: $sortOrder) {
                    TableColumn("") { node in
                        QueueToggle(appState: appState, node: node, source: .largeFiles, reason: "Large file (\(Format.bytes(node.size)))")
                    }
                    .width(24)
                    TableColumn("Name", value: \.name) { node in
                        HStack(spacing: 8) {
                            TypeIconView(ext: node.fileExtension, isDirectory: false, size: 16)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(node.name).foregroundStyle(theme.ink).lineLimit(1)
                                Text(Format.tildePath(node.parent?.path ?? ""))
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(theme.muted)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                    .width(min: 260, ideal: 420)
                    TableColumn("Size", value: \.size) { node in
                        Text(Format.bytes(node.size))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(theme.ink)
                    }
                    .width(90)
                    TableColumn("Category") { node in
                        HStack(spacing: 5) {
                            Circle().fill(theme.color(for: node.category)).frame(width: 7, height: 7)
                            Text(node.category.label).foregroundStyle(theme.body)
                        }
                    }
                    .width(130)
                    TableColumn("Modified", value: \.sortableModified) { node in
                        Text(Format.shortDate(node.modified)).foregroundStyle(theme.muted)
                    }
                    .width(100)
                    TableColumn("Last opened", value: \.sortableAccessed) { node in
                        Text(Format.daysAgo(node.accessed)).foregroundStyle(theme.muted)
                    }
                    .width(110)
                    TableColumn("Safety") { node in
                        SafetyBadge(level: SafetyPolicy.assess(path: node.path, insidePackage: node.isInsidePackage))
                    }
                    .width(90)
                }
                .contextMenu(forSelectionType: FileNode.ID.self) { ids in
                    if let node = rows.first(where: { ids.contains($0.id) }) {
                        Button("Reveal in Finder") { TrashService.reveal(node.url) }
                        Button("Quick Look") { previewURL = node.url }
                        Button("Copy Path") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(node.path, forType: .string)
                        }
                        Divider()
                        Button("Show in Sunburst") { appState.showInSunburst(node) }
                        Button("Show in Folders") { appState.showInFolders(node) }
                        Divider()
                        Button("Add \(ids.count) to Review & Clean") {
                            appState.enqueue(rows.filter { ids.contains($0.id) }.map { CleanupItem(node: $0, source: .largeFiles, reason: "Large file (\(Format.bytes($0.size)))") })
                        }
                    }
                } primaryAction: { ids in
                    if let node = rows.first(where: { ids.contains($0.id) }) { previewURL = node.url }
                }
                .scrollContentBackground(.hidden)
                .background(theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(theme.line))
                .quickLookPreview($previewURL)
            }
            .padding(24)
        }
    }

    private var categoryBinding: Binding<FileCategory?> {
        Binding(get: { appState.largeFileCategoryFilter }, set: { appState.largeFileCategoryFilter = $0 })
    }

    private func filtered(_ snapshot: ScanSnapshot) -> [FileNode] {
        let floor = Int64(minMB * 1_048_576)
        let needle = search.lowercased()
        var rows = snapshot.largeFiles.filter { node in
            guard !node.removed, node.size >= floor else { return false }
            if let cat = appState.largeFileCategoryFilter, node.category != cat { return false }
            if hideProtected, SafetyPolicy.assess(path: node.path, insidePackage: node.isInsidePackage) == .protected { return false }
            if !needle.isEmpty, !node.name.lowercased().contains(needle), !node.path.lowercased().contains(needle) { return false }
            return true
        }
        rows.sort(using: sortOrder)
        return rows
    }
}

extension FileNode {
    var sortableModified: Date { modified ?? .distantPast }
    var sortableAccessed: Date { accessed ?? .distantPast }
}
