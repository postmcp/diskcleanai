import SwiftUI

struct AgeStats {
    var buckets: [Int64] = Array(repeating: 0, count: 6)
    var total: Int64 = 0
    /// Bytes per (year, month) by last-modified date.
    var monthly: [Int: [Int64]] = [:]
    var bigUntouched: [FileNode] = []

    static func compute(_ focus: FileNode) -> AgeStats {
        var stats = AgeStats()
        let calendar = Calendar.current
        let now = Date()
        focus.forEachFile { node in
            stats.total += node.size
            stats.buckets[NodeColorer.ageBucket(node.modified)] += node.size
            if let m = node.modified {
                let c = calendar.dateComponents([.year, .month], from: m)
                if let y = c.year, let mo = c.month, y > 1990 {
                    var row = stats.monthly[y] ?? Array(repeating: 0, count: 12)
                    row[mo - 1] += node.size
                    stats.monthly[y] = row
                }
                if node.size >= 20 * 1_048_576, now.timeIntervalSince(m) > 365 * 86_400, !node.isInsidePackage,
                   SafetyPolicy.assess(path: node.path, insidePackage: false) != .protected {
                    stats.bigUntouched.append(node)
                }
            }
        }
        stats.bigUntouched.sort { $0.size > $1.size }
        if stats.bigUntouched.count > 40 { stats.bigUntouched.removeLast(stats.bigUntouched.count - 40) }
        return stats
    }
}

/// Where the bytes sit on a timeline: age buckets, a modified-month heat grid and big untouched files.
struct AgeMapView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme
    let focus: FileNode
    @State private var stats: AgeStats?
    @State private var computingFor: ObjectIdentifier?

    var body: some View {
        Group {
            if let stats {
                HStack(alignment: .top, spacing: 14) {
                    ScrollView {
                        VStack(spacing: 14) {
                            bucketsCard(stats)
                            heatCard(stats)
                        }
                    }
                    untouchedCard(stats)
                        .frame(width: 360)
                }
            } else {
                ProgressState(title: "Dating \(Format.count(focus.fileCount)) files…", detail: Format.tildePath(focus.path))
            }
        }
        .task(id: focus.id) {
            stats = nil
            let f = focus
            let result = await Task.detached(priority: .userInitiated) { AgeStats.compute(f) }.value
            stats = result
        }
    }

    private func bucketsCard(_ stats: AgeStats) -> some View {
        let colorer = NodeColorer(theme: theme, mode: .byAge, focus: focus)
        let maxBytes = max(stats.buckets.max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Eyebrow(text: "How old are these bytes?")
                Spacer()
                Text(Format.bytes(stats.total)).font(.system(size: 11.5, weight: .medium)).foregroundStyle(theme.muted)
            }
            ForEach(0..<6, id: \.self) { i in
                HStack(spacing: 12) {
                    Text(NodeColorer.ageBucketLabels[i]).font(.system(size: 12.5)).foregroundStyle(theme.ink).frame(width: 110, alignment: .leading)
                    SizeBar(fraction: Double(stats.buckets[i]) / Double(maxBytes), color: colorer.ageColor(bucket: i), height: 12)
                    Text(Format.bytes(stats.buckets[i])).font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.ink).frame(width: 74, alignment: .trailing)
                    Text(Format.percent(stats.total > 0 ? Double(stats.buckets[i]) / Double(stats.total) : 0)).font(.system(size: 11)).foregroundStyle(theme.muted).frame(width: 46, alignment: .trailing)
                }
            }
        }
        .card()
    }

    private func heatCard(_ stats: AgeStats) -> some View {
        let years = stats.monthly.keys.sorted(by: >).prefix(8)
        let peak = stats.monthly.values.flatMap { $0 }.max() ?? 1
        let months = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
        return VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "Bytes by last-modified month")
            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                GridRow {
                    Text("").frame(width: 40)
                    ForEach(0..<12, id: \.self) { m in
                        Text(months[m]).font(.system(size: 10.5, weight: .medium)).foregroundStyle(theme.muted).frame(maxWidth: .infinity)
                    }
                }
                ForEach(Array(years), id: \.self) { year in
                    GridRow {
                        Text(String(year)).font(.system(size: 11, weight: .medium)).foregroundStyle(theme.body).frame(width: 40, alignment: .leading)
                        ForEach(0..<12, id: \.self) { m in
                            let bytes = stats.monthly[year]?[m] ?? 0
                            let level = bytes == 0 ? 0.0 : max(0.15, sqrt(Double(bytes) / Double(peak)))
                            ZStack {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(bytes == 0 ? theme.surface : theme.brand.opacity(0.18 + 0.82 * level))
                                if stats.total > 0, Double(bytes) / Double(stats.total) >= 0.05 {
                                    Text(Format.bytes(bytes)).font(.system(size: 8.5, weight: .semibold)).foregroundStyle(level > 0.55 ? Color.white : theme.ink).lineLimit(1).minimumScaleFactor(0.6)
                                }
                            }
                            .frame(height: 38)
                            .help("\(months[m]) \(year): \(Format.bytes(bytes))")
                        }
                    }
                }
            }
            HStack {
                Text("less").font(.system(size: 10.5)).foregroundStyle(theme.muted)
                ForEach([0.18, 0.4, 0.6, 0.8, 1.0], id: \.self) { l in
                    RoundedRectangle(cornerRadius: 3).fill(theme.brand.opacity(l)).frame(width: 18, height: 10)
                }
                Text("more").font(.system(size: 10.5)).foregroundStyle(theme.muted)
                Spacer()
                Text("Busiest month: \(Format.bytes(peak))").font(.system(size: 10.5)).foregroundStyle(theme.muted)
            }
        }
        .card()
    }

    private func untouchedCard(_ stats: AgeStats) -> some View {
        let total = stats.bigUntouched.reduce(0) { $0 + $1.size }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Eyebrow(text: "Big & untouched")
                Spacer()
                Text("over a year old").font(.system(size: 11)).foregroundStyle(theme.muted)
            }
            Text("\(Format.bytes(total)) across \(stats.bigUntouched.count) items").font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.brand)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(stats.bigUntouched) { node in
                        HStack(spacing: 8) {
                            FileIconView(url: node.url, isDirectory: false, size: 18)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(node.name).font(.system(size: 12, weight: .medium)).foregroundStyle(theme.ink).lineLimit(1).truncationMode(.middle)
                                Text(Format.daysAgo(node.modified)).font(.system(size: 10.5)).foregroundStyle(theme.muted)
                            }
                            Spacer()
                            Text(Format.bytes(node.size)).font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.ink)
                            QueueToggle(appState: appState, node: node, source: .largeFiles, reason: "Not modified for over a year (\(Format.bytes(node.size)))")
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .onTapGesture { appState.selectedNode = node }
                        .fileContextMenu(url: node.url, node: node, source: .largeFiles, reason: "Not modified for over a year", appState: appState)
                        Divider().overlay(theme.line)
                    }
                }
            }
            Button {
                appState.enqueue(stats.bigUntouched.prefix(13).map { CleanupItem(node: $0, source: .largeFiles, reason: "Not modified for over a year (\(Format.bytes($0.size)))") })
            } label: { Label("Stage top \(min(stats.bigUntouched.count, 13)) for cleanup", systemImage: "trash").frame(maxWidth: .infinity) }
            .buttonStyle(.secondary)
            .disabled(stats.bigUntouched.isEmpty)
        }
        .card()
    }
}
