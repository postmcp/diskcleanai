import SwiftUI

/// First-run and no-scan state.
struct WelcomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Image("Mascot")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 140, height: 140)
                    .shadow(color: theme.brand.opacity(0.25), radius: 20, y: 10)

                VStack(spacing: 10) {
                    Text("See what's filling up your Mac.")
                        .font(.system(size: 30, weight: .bold))
                        .tracking(-0.8)
                        .foregroundStyle(theme.ink)
                    Text("Scan a drive or folder. Everything runs on this Mac — nothing is uploaded, and nothing is deleted without your approval.")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.body)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 520)
                }

                HStack(spacing: 10) {
                    Button {
                        appState.startScan(URL(fileURLWithPath: "/"))
                    } label: {
                        Label("Scan \(appState.volumes.first(where: \.isRoot)?.name ?? "Macintosh HD")", systemImage: "internaldrive")
                    }
                    .buttonStyle(.primaryLarge)
                    .keyboardShortcut(.defaultAction)

                    Button {
                        appState.startScan(FileManager.default.homeDirectoryForCurrentUser)
                    } label: {
                        Label("Scan Home Folder", systemImage: "house")
                    }
                    .buttonStyle(.secondaryLarge)

                    Button("Choose Folder…") { appState.chooseFolder() }
                        .buttonStyle(.secondaryLarge)
                }

                if !appState.hasFullDiskAccess {
                    FullDiskAccessBanner()
                        .frame(maxWidth: 640)
                }

                HStack(spacing: 14) {
                    feature("Large files", "doc.text.magnifyingglass", "Every file sorted by size.")
                    feature("Duplicates", "doc.on.doc", "Byte-for-byte copies, side by side.")
                    feature("Unused apps", "app.badge", "Apps you haven't opened in months.")
                    feature("Trash only", "arrow.uturn.backward", "A wrong click is one undo away.")
                }
                .frame(maxWidth: 820)
            }
            .padding(.vertical, 48)
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity)
        }
    }

    private func feature(_ title: String, _ icon: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.brand)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.ink)
            Text(body)
                .font(.system(size: 11.5))
                .foregroundStyle(theme.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }
}

struct FullDiskAccessBanner: View {
    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.system(size: 18))
                .foregroundStyle(theme.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text("Full Disk Access is off")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Text("Without it, macOS hides Mail, Messages, Safari and some Library folders from the scan. Enable Disk Clean AI under Privacy & Security, then rescan.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(theme.body)
            }
            Spacer()
            Button("Open System Settings") { FullDiskAccess.openSystemSettings() }
                .buttonStyle(.secondary)
            Button {
                appState.hasFullDiskAccess = FullDiskAccess.isGranted()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.secondary)
            .help("Check again")
        }
        .card(padding: 12)
    }
}

struct ScanningView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme

    var body: some View {
        let p = appState.progress
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .stroke(theme.line, lineWidth: 10)
                    .frame(width: 120, height: 120)
                Circle()
                    .trim(from: 0, to: 0.28)
                    .stroke(theme.brand, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(rotation))
                    .animation(.linear(duration: 1.1).repeatForever(autoreverses: false), value: rotation)
                    .onAppear { rotation = 360 }
                VStack(spacing: 2) {
                    Text(Format.bytes(p.bytes))
                        .font(.system(size: 18, weight: .bold))
                        .tracking(-0.4)
                        .foregroundStyle(theme.ink)
                    Text("scanned")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(theme.muted)
                }
            }
            VStack(spacing: 6) {
                Text("Scanning \(Format.tildePath(appState.scanRoot.path))")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Text("\(Format.count(p.files)) files · \(Format.count(p.directories)) folders · \(Format.duration(p.elapsed))")
                    .font(.system(size: 12.5))
                    .foregroundStyle(theme.body)
                Text(Format.tildePath(p.currentPath))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(theme.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 560)
            }
            Button("Stop Scan") { appState.cancelScan() }
                .buttonStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @State private var rotation: Double = 0
}
