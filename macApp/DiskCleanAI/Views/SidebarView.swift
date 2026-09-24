import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme
    @AppStorage(Pref.sidebarVolumeBar) private var showVolumeBar = true
    @AppStorage("sidebar.quickWinsExpanded") private var quickWinsExpanded = true

    var body: some View {
        @Bindable var appState = appState
        VStack(spacing: 0) {
            List {
                Section {
                    ForEach(SidebarItem.allCases) { item in
                        row(item)
                    }
                }
                if let snapshot = appState.snapshot, !snapshot.quickWins.isEmpty {
                    Section(isExpanded: $quickWinsExpanded) {
                        ForEach(snapshot.quickWins.prefix(6)) { win in
                            quickWinRow(win)
                        }
                    } header: {
                        HStack {
                            Text("Quick wins")
                            Spacer()
                            Text(Format.bytes(snapshot.quickWins.reduce(0) { $0 + $1.bytes })).font(.system(size: 10.5)).foregroundStyle(theme.muted)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            if showVolumeBar {
                VolumeCard()
                    .padding(12)
            }
        }
        .background(theme.surface)
    }

    private func quickWinRow(_ win: QuickWin) -> some View {
        Button { appState.showQuickWin(win) } label: {
            HStack(spacing: 8) {
                Image(systemName: win.systemImage).font(.system(size: 12)).foregroundStyle(theme.chartColor(win.chartIndex)).frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(win.label).font(.system(size: 12, weight: .medium)).foregroundStyle(theme.ink)
                    Text("\(win.count) item\(win.count == 1 ? "" : "s")").font(.system(size: 10.5)).foregroundStyle(theme.muted)
                }
                Spacer()
                Text(Format.bytes(win.bytes)).font(.system(size: 11.5, weight: .medium)).foregroundStyle(theme.body)
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)).foregroundStyle(theme.muted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func row(_ item: SidebarItem) -> some View {
        let selected = appState.selection == item
        return HStack(spacing: 10) {
            Image(systemName: item.systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(selected ? Color.white : theme.brand)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(selected ? Color.white : theme.ink)
                Text(item.subtitle).font(.system(size: 10.5)).foregroundStyle(selected ? Color.white.opacity(0.8) : theme.muted).lineLimit(1)
            }
            Spacer()
            if item == .cleanup, !appState.queue.isEmpty {
                Text("\(appState.queue.count)")
                    .font(.system(size: 10.5, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1.5)
                    .foregroundStyle(selected ? theme.brand : Color.white)
                    .background(Capsule().fill(selected ? Color.white : theme.brand))
            }
            if item == .aiAdvisor, appState.ai.isRunning {
                ProgressView().controlSize(.mini)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(selected ? theme.brand : Color.clear))
        .contentShape(Rectangle())
        .onTapGesture { appState.selection = item }
        .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
        .listRowSeparator(.hidden)
    }
}

/// The used/total readout at the bottom of the sidebar, like the landing mockup.
struct VolumeCard: View {
    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme

    var body: some View {
        // Items we moved to the Trash count as free right away; the real number only
        // catches up once the Trash is emptied.
        let pending = appState.pendingTrashBytes
        let volume = (appState.snapshot?.volume ?? appState.volumes.first(where: \.isRoot))?.reclaiming(pending)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(volume?.name ?? "Macintosh HD")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                Spacer()
                if let volume {
                    Text("\(Format.bytes(volume.usedCapacity)) / \(Format.bytes(volume.totalCapacity))")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(theme.muted)
                        .contentTransition(.numericText())
                }
            }
            if let snapshot = appState.snapshot, let volume, volume.totalCapacity > 0 {
                let total = Double(volume.totalCapacity)
                CategoryBar(segments: snapshot.categoryBreakdown.map { ($0.category, Double($0.bytes) / total) })
                freeLine(volume, pending: pending)
            } else if let volume {
                SizeBar(fraction: volume.usedFraction, color: theme.brand)
                freeLine(volume, pending: pending)
            }
        }
        .card(padding: 12, radius: 12)
        .animation(.easeOut(duration: 0.4), value: pending)
    }

    private func freeLine(_ volume: VolumeInfo, pending: Int64) -> some View {
        HStack(spacing: 4) {
            Text("\(Format.bytes(volume.availableCapacity)) free")
                .contentTransition(.numericText())
            if pending > 0 {
                Text("· \(Format.bytes(pending)) in Trash")
                    .foregroundStyle(theme.success)
                    .help("Moved there by this app. Empty the Trash to actually release the space.")
            }
        }
        .font(.system(size: 10.5))
        .foregroundStyle(theme.muted)
        .lineLimit(1)
    }
}
