import SwiftUI

/// One screen, many patterns: the scanned tree drawn as folder cards, sunburst,
/// treemap, bubbles, mind map, icicle, ranked list, age map or outline table.
struct ExploreView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme
    @State private var filter = ""

    var body: some View {
        @Bindable var appState = appState
        if let snapshot = appState.snapshot {
            let focus = appState.focusNode ?? snapshot.root
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    header(focus)
                    modeBar(focus)
                    content(focus, snapshot: snapshot)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if appState.exploreMode.usesColorMode {
                        legend(focus)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider().overlay(theme.line)

                InspectorPanel(focus: focus)
                    .frame(width: 320)
                    .background(theme.surface)
            }
        }
    }

    // MARK: Header

    private func header(_ focus: FileNode) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(focus.displayName)
                .font(.system(size: 24, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(theme.ink)
                .lineLimit(1)
            Text(Format.bytes(focus.size))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.body)
            Text("·  \(Format.count(focus.fileCount)) files  ·  \(Format.count(focus.dirCount)) folders")
                .font(.system(size: 12.5))
                .foregroundStyle(theme.muted)
            Spacer()
            if focus.parent != nil {
                Button { appState.focusParent() } label: { Label("Up", systemImage: "arrow.up") }
                    .buttonStyle(.secondary)
                    .keyboardShortcut(.upArrow, modifiers: .command)
            }
            Button { TrashService.reveal(focus.url) } label: { Image(systemName: "arrow.up.forward.square") }
                .buttonStyle(.secondary)
                .help("Reveal in Finder")
            Button { appState.startScan() } label: { Label("Rescan", systemImage: "arrow.clockwise") }
                .buttonStyle(.secondary)
        }
    }

    private func modeBar(_ focus: FileNode) -> some View {
        @Bindable var appState = appState
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                HStack(spacing: 2) {
                    ForEach(ExploreMode.allCases) { mode in
                        let selected = appState.exploreMode == mode
                        Button {
                            appState.exploreMode = mode
                            appState.quickWin = nil
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: mode.systemImage).font(.system(size: 12, weight: .medium))
                                if selected { Text(mode.title).font(.system(size: 12, weight: .semibold)).lineLimit(1) }
                            }
                            .fixedSize()
                            .padding(.horizontal, selected ? 11 : 8)
                            .padding(.vertical, 6)
                            .foregroundStyle(selected ? Color.white : theme.body)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(selected ? theme.ink : Color.clear))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(mode.title + " — " + mode.blurb)
                    }
                }
                .padding(3)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(theme.card))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(theme.line))
                .fixedSize()

                Text(appState.quickWin.map { "Quick win: \($0.label)" } ?? appState.exploreMode.blurb)
                    .font(.system(size: 11.5))
                    .foregroundStyle(theme.muted)
                    .lineLimit(1)
                    .layoutPriority(-1)

                Spacer(minLength: 0)

                if [.folders, .list, .topSizes].contains(appState.exploreMode) {
                    TextField("Filter by name…", text: $filter)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                }
            }

            HStack(spacing: 10) {
                Breadcrumb(nodes: focus.ancestry) { appState.focusNode = $0; appState.selectedNode = nil }
                    .layoutPriority(-1)
                Spacer(minLength: 0)
                if appState.exploreMode.usesColorMode {
                    HStack(spacing: 2) {
                        ForEach(ColorMode.allCases) { mode in
                            let selected = appState.colorMode == mode
                            Button { appState.colorMode = mode } label: {
                                Label(mode.title, systemImage: mode.systemImage)
                                    .font(.system(size: 11.5, weight: selected ? .semibold : .medium))
                                    .lineLimit(1)
                                    .fixedSize()
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .foregroundStyle(selected ? theme.ink : theme.body)
                                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(selected ? theme.surface : Color.clear))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(3)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(theme.line))
                    .fixedSize()
                }
                if appState.exploreMode.usesDepth {
                    HStack(spacing: 6) {
                        Image(systemName: "circle.dotted.and.circle").font(.system(size: 11)).foregroundStyle(theme.muted)
                        Slider(value: Binding(get: { Double(appState.exploreDepth) }, set: { appState.exploreDepth = Int($0.rounded()) }), in: 2...8, step: 1)
                            .frame(width: 90)
                        Text("\(appState.exploreDepth)").font(.system(size: 11.5, weight: .semibold, design: .monospaced)).foregroundStyle(theme.body).frame(width: 14)
                    }
                    .fixedSize()
                    .help("How many levels to draw")
                }
            }
        }
    }

    private func legend(_ focus: FileNode) -> some View {
        let colorer = NodeColorer(theme: theme, mode: appState.colorMode, focus: focus)
        return HStack(spacing: 14) {
            ForEach(Array(colorer.legend.enumerated()), id: \.offset) { _, entry in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2.5).fill(entry.color).frame(width: 10, height: 10)
                    Text(entry.label).font(.system(size: 11.5, weight: .medium)).foregroundStyle(theme.body).lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Content

    @ViewBuilder
    private func content(_ focus: FileNode, snapshot: ScanSnapshot) -> some View {
        let colorer = NodeColorer(theme: theme, mode: appState.colorMode, focus: focus)
        let filtered = filter.isEmpty ? nil : filter
        switch appState.exploreMode {
        case .folders:
            FolderCardsView(focus: focus, colorer: colorer, filter: filtered)
        case .sunburst:
            SunburstView(focus: focus, rings: appState.exploreDepth, colorer: colorer, selected: appState.selectedNode,
                         onSelect: { node in appState.selectedNode = node }, onFocus: { node in withAnimation(.easeInOut(duration: 0.2)) { appState.focus(node) } })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .treemap:
            TreemapView(focus: focus, colorer: colorer)
        case .bubbles:
            BubblesView(focus: focus, colorer: colorer)
        case .mindMap:
            MindMapView(focus: focus, colorer: colorer, depth: appState.exploreDepth)
        case .icicle:
            IcicleView(focus: focus, colorer: colorer, depth: appState.exploreDepth)
        case .topSizes:
            TopSizesView(focus: focus, snapshot: snapshot, filter: filtered)
        case .ageMap:
            AgeMapView(focus: focus)
        case .list:
            ExploreListView(focus: focus, filter: filtered)
        }
    }
}

/// Hover card shared by the canvas patterns.
struct NodeTooltip: View {
    @Environment(\.theme) private var theme
    let node: FileNode
    let focus: FileNode

    var body: some View {
        let fraction = focus.size > 0 ? Double(node.size) / Double(focus.size) : 0
        VStack(alignment: .leading, spacing: 3) {
            Text(node.name).font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.ink).lineLimit(1)
            Text("\(Format.bytes(node.size)) · \(Format.percent(fraction))" + (node.isContainer ? " · \(Format.count(node.fileCount)) files" : ""))
                .font(.system(size: 11)).foregroundStyle(theme.body)
            Text(Format.tildePath(node.path)).font(.system(size: 10, design: .monospaced)).foregroundStyle(theme.muted).lineLimit(1).truncationMode(.middle)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: 300, alignment: .leading)
        .fixedSize()
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(theme.card).shadow(color: .black.opacity(0.2), radius: 10, y: 4))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(theme.line))
        .allowsHitTesting(false)
    }

    static func clamp(_ p: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: min(max(p.x + 20, 150), max(size.width - 150, 150)), y: min(max(p.y - 44, 30), max(size.height - 30, 30)))
    }
}

/// Click = select for the inspector, double-click = drill in. Shared by canvas patterns.
struct CanvasInteraction: ViewModifier {
    @Environment(AppState.self) private var appState
    let hitTest: (CGPoint) -> FileNode?

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { point in
                if let node = hitTest(point) { appState.focus(node) }
            }
            .onTapGesture(count: 1) { point in
                appState.selectedNode = hitTest(point)
            }
    }
}
