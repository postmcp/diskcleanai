import SwiftUI

/// "A new version is available" — notes, progress and the install button.
struct UpdateSheet: View {
    @Environment(UpdateChecker.self) private var updates
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image("Mascot").resizable().interpolation(.high).frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text(headline).font(.system(size: 17, weight: .semibold)).foregroundStyle(theme.ink)
                    Text(subheadline).font(.system(size: 12)).foregroundStyle(theme.muted)
                }
                Spacer()
            }

            if let release = updates.availableRelease, !release.notes.isEmpty {
                ScrollView {
                    Text(Self.renderNotes(release.notes))
                        .font(.system(size: 12.5))
                        .foregroundStyle(theme.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(12)
                }
                .frame(maxHeight: 200)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(theme.surface))
            }

            switch updates.phase {
            case .downloading(_, let fraction):
                ProgressView(value: fraction).progressViewStyle(.linear)
                Text("Downloading… \(Int(fraction * 100))%").font(.system(size: 11.5)).foregroundStyle(theme.muted)
            case .installing:
                ProgressView().controlSize(.small)
                Text("Installing…").font(.system(size: 11.5)).foregroundStyle(theme.muted)
            case .readyToRelaunch:
                Label("Installed. Relaunching…", systemImage: "checkmark.circle.fill").foregroundStyle(theme.success)
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle").font(.system(size: 12)).foregroundStyle(theme.danger)
            default:
                EmptyView()
            }

            HStack {
                if let release = updates.availableRelease, case .available = updates.phase {
                    Button("Skip This Version") { updates.skip(release) }.buttonStyle(.plain).foregroundStyle(theme.muted)
                    Link("View on GitHub", destination: release.pageURL).font(.system(size: 12)).padding(.leading, 8)
                }
                Spacer()
                if updates.isWorking {
                    Button("Cancel") { updates.cancel() }.buttonStyle(.secondary)
                } else {
                    Button("Later") { updates.showSheet = false }.buttonStyle(.secondary).keyboardShortcut(.cancelAction)
                }
                if let release = updates.availableRelease, !updates.isWorking, !isDone {
                    Button(release.url == nil ? "Open Release Page" : "Download & Install") { updates.downloadAndInstall(release) }
                        .buttonStyle(.primary)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(22)
        .frame(width: 480)
        .background(theme.background)
    }

    /// GitHub release notes are Markdown; render the inline parts and keep the line breaks.
    private static func renderNotes(_ notes: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: notes, options: options)) ?? AttributedString(notes)
    }

    private var isDone: Bool {
        if case .readyToRelaunch = updates.phase { return true }
        return false
    }

    private var headline: String {
        switch updates.phase {
        case .checking: return "Checking for updates…"
        case .upToDate: return "You're up to date"
        case .failed: return "Update problem"
        default:
            if let r = updates.availableRelease { return "Disk Clean AI \(r.version) is available" }
            return "Check for updates"
        }
    }

    private var subheadline: String {
        switch updates.phase {
        case .upToDate: return "Disk Clean AI \(AppConfig.versionString) is the newest version."
        case .checking: return "Looking at the latest release on GitHub."
        default:
            if let r = updates.availableRelease {
                var parts = ["You have \(AppConfig.version)"]
                if let size = r.size { parts.append(Format.bytes(size)) }
                return parts.joined(separator: " · ")
            }
            return "Version \(AppConfig.versionString)"
        }
    }
}
