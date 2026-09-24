import SwiftUI

struct AIAdvisorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme
    @AppStorage(Pref.model) private var model = Pref.defaultModel
    @State private var showPayload = false
    @State private var confidenceFilter: AISuggestion.Confidence?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                SectionTitle(title: "AI Advisor", subtitle: "Sends names, sizes, kinds and dates — never file contents — to the model you choose on OpenRouter.")
                Spacer()
                Button {
                    if !appState.hasAPIKey { openSettings() } else { appState.runAIAnalysis() }
                } label: {
                    Label(appState.hasAPIKey ? (appState.ai.value == nil ? "Analyze with AI" : "Analyze Again") : "Add OpenRouter Key…", systemImage: "sparkles")
                }
                .buttonStyle(.primary)
                .disabled(appState.ai.isRunning)
            }

            HStack(spacing: 10) {
                Label(model, systemImage: "cpu").font(.system(size: 11.5, design: .monospaced)).foregroundStyle(theme.body)
                Button("Change…") { openSettings() }.buttonStyle(.plain).font(.system(size: 11.5, weight: .medium)).foregroundStyle(theme.brand)
                Divider().frame(height: 14)
                Label(appState.hasAPIKey ? "Key in Keychain" : "No key yet", systemImage: appState.hasAPIKey ? "key.fill" : "key")
                    .font(.system(size: 11.5)).foregroundStyle(appState.hasAPIKey ? theme.success : theme.warning)
                Divider().frame(height: 14)
                Text(inputsSummary).font(.system(size: 11.5)).foregroundStyle(theme.muted)
                Spacer()
                if appState.aiPayloadPreview != nil {
                    Toggle("Show what was sent", isOn: $showPayload).toggleStyle(.checkbox).font(.system(size: 11.5))
                }
            }

            if showPayload, let payload = appState.aiPayloadPreview {
                ScrollView {
                    Text(payload).font(.system(size: 10.5, design: .monospaced)).foregroundStyle(theme.body).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                }
                .frame(height: 200)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(theme.line))
            }

            switch appState.ai {
            case .idle:
                EmptyState(systemImage: "sparkles", title: appState.snapshot == nil ? "Scan first, then ask" : "Ready to review your scan",
                           message: appState.snapshot == nil
                           ? "Run a scan so the advisor has large files, downloads, caches and apps to reason about. Duplicates and apps you've already analysed are included too."
                           : "The model gets the biggest files, well-known cache folders, old downloads, unused apps and duplicate groups, and explains what is safe to remove and why. A typical run costs a few cents.",
                           actionTitle: appState.snapshot == nil ? "Scan Startup Disk" : nil) { appState.startScan(URL(fileURLWithPath: "/")) }
            case .running:
                ProgressState(title: "Asking \(model)…", detail: "Waiting for OpenRouter")
            case .failed(let message):
                EmptyState(systemImage: "exclamationmark.triangle", title: "The request failed", message: message, actionTitle: appState.hasAPIKey ? "Try Again" : "Open Settings") {
                    if appState.hasAPIKey { appState.runAIAnalysis() } else { openSettings() }
                }
            case .done(let analysis):
                results(analysis)
            }
        }
        .padding(24)
        .onAppear { appState.refreshKeyStatus() }
    }

    private var inputsSummary: String {
        var parts: [String] = []
        if let s = appState.snapshot { parts.append("\(min(s.largeFiles.count, 60)) large files") }
        if let d = appState.downloads.value { parts.append("\(min(d.children.count, 60)) downloads") }
        if let a = appState.apps.value { parts.append("\(a.filter { $0.isUnused(days: 60) }.count) unused apps") }
        if let g = appState.duplicates.value { parts.append("\(min(g.count, 25)) duplicate groups") }
        return parts.isEmpty ? "Nothing scanned yet" : "Inputs: " + parts.joined(separator: ", ")
    }

    private func results(_ analysis: AIAnalysis) -> some View {
        let rows = analysis.suggestions.filter { confidenceFilter == nil || $0.confidence == confidenceFilter }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("You can free up ").font(.system(size: 18, weight: .semibold)).foregroundStyle(theme.ink)
                    + Text(Format.bytes(analysis.reclaimable)).font(.system(size: 18, weight: .bold)).foregroundStyle(theme.brand)
                    Text(analysis.summary).font(.system(size: 12.5)).foregroundStyle(theme.body)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(Format.usd(analysis.cost)) · \(Format.tokens(analysis.promptTokens + analysis.completionTokens)) tokens")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(theme.ink)
                    Text("\(analysis.model) · \(Format.relativeDate(analysis.createdAt))").font(.system(size: 11)).foregroundStyle(theme.muted)
                }
            }
            .card()

            HStack(spacing: 10) {
                ChipPicker(options: [(AISuggestion.Confidence?.none, "All"), (.high, "High confidence"), (.medium, "Medium"), (.low, "Low")], selection: $confidenceFilter)
                Spacer()
                Button {
                    enqueue(analysis.suggestions.filter { $0.confidence == .high && $0.action == .trash && $0.exists })
                } label: { Label("Add all high-confidence", systemImage: "plus.circle") }
                .buttonStyle(.secondary)
                Button {
                    enqueue(rows.filter(\.exists))
                } label: { Label("Add \(rows.filter(\.exists).count) shown", systemImage: "plus.circle.fill") }
                .buttonStyle(.primary)
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(rows) { suggestion in
                        suggestionRow(suggestion)
                    }
                    if rows.isEmpty {
                        Text("No suggestions match this filter.").font(.system(size: 12)).foregroundStyle(theme.muted).padding(24)
                    }
                }
            }
        }
    }

    private func suggestionRow(_ s: AISuggestion) -> some View {
        let url = URL(fileURLWithPath: s.path)
        let queued = appState.isQueued(url)
        let level = SafetyPolicy.assess(path: s.path, insidePackage: false)
        return HStack(alignment: .top, spacing: 12) {
            FileIconView(url: url, isDirectory: s.isDirectory, size: 28)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(url.lastPathComponent).font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.ink).lineLimit(1)
                    Badge(text: s.confidence.label, color: s.confidence == .high ? theme.success : (s.confidence == .medium ? theme.warning : theme.muted))
                    Badge(text: s.action == .trash ? "Trash" : "Review first", color: s.action == .trash ? theme.brand : theme.warning)
                    if let cat = s.category { Badge(text: cat.capitalized, color: theme.muted) }
                    SafetyBadge(level: level)
                    if !s.exists { Badge(text: "Not found", color: theme.danger) }
                }
                Text(Format.tildePath(s.path)).font(.system(size: 11, design: .monospaced)).foregroundStyle(theme.muted).lineLimit(1).truncationMode(.middle)
                Text(s.reason).font(.system(size: 12)).foregroundStyle(theme.body)
            }
            Spacer()
            Text(s.exists ? Format.bytes(s.size) : "—").font(.system(size: 12.5, weight: .semibold, design: .monospaced)).foregroundStyle(theme.ink)
            Button { TrashService.reveal(url) } label: { Image(systemName: "magnifyingglass") }.buttonStyle(.secondary).help("Reveal in Finder").disabled(!s.exists)
            Button {
                if queued { appState.dequeue(url) } else { enqueue([s]) }
            } label: {
                Image(systemName: queued ? "checkmark.circle.fill" : "plus.circle").font(.system(size: 16)).foregroundStyle(queued ? theme.brand : theme.muted)
            }
            .buttonStyle(.plain)
            .disabled(!s.exists || level == .protected)
        }
        .card(padding: 12)
        .fileContextMenu(url: url, node: appState.snapshot?.root.node(atPath: s.path), source: .ai, reason: s.reason, appState: appState)
    }

    private func enqueue(_ suggestions: [AISuggestion]) {
        appState.enqueue(suggestions.filter(\.exists).map {
            CleanupItem(url: URL(fileURLWithPath: $0.path), size: $0.size, source: .ai, reason: $0.reason, isDirectory: $0.isDirectory, approved: $0.action == .trash)
        })
    }

    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
