import SwiftUI
import AppKit

// MARK: - Text helpers

struct SectionTitle: View {
    @Environment(\.theme) private var theme
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(theme.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(theme.muted)
            }
        }
    }
}

struct Eyebrow: View {
    @Environment(\.theme) private var theme
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(1)
            .foregroundStyle(theme.muted)
    }
}

struct Badge: View {
    let text: String
    let color: Color
    var filled = false

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .foregroundStyle(filled ? .white : color)
            .background(Capsule().fill(filled ? color : color.opacity(0.14)))
    }
}

struct SafetyBadge: View {
    @Environment(\.theme) private var theme
    let level: SafetyLevel

    var body: some View {
        let color: Color = level == .safe ? theme.success : (level == .caution ? theme.warning : theme.danger)
        Label(level.label, systemImage: level.systemImage)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(color)
            .help(help)
    }

    private var help: String {
        switch level {
        case .safe: return "Common user data or disposable cache. Safe to move to the Trash."
        case .caution: return "Lives in a library or system folder. Look before you remove it."
        case .protected: return "Part of macOS, an app bundle, or personal data the app never touches."
        }
    }
}

// MARK: - Stat tiles and bars

struct StatTile: View {
    @Environment(\.theme) private var theme
    let label: String
    let value: String
    var detail: String? = nil
    var color: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(theme.muted)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(color ?? theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let detail {
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.body)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }
}

struct SizeBar: View {
    @Environment(\.theme) private var theme
    let fraction: Double
    var color: Color? = nil
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.line)
                Capsule().fill(color ?? theme.brand)
                    .frame(width: max(geo.size.width * min(max(fraction, 0), 1), fraction > 0 ? 3 : 0))
            }
        }
        .frame(height: height)
    }
}

/// Segmented bar of categories, as in the sidebar volume card.
struct CategoryBar: View {
    @Environment(\.theme) private var theme
    let segments: [(category: FileCategory, fraction: Double)]
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(segments, id: \.category) { seg in
                    Rectangle()
                        .fill(theme.color(for: seg.category))
                        .frame(width: max(geo.size.width * seg.fraction, 0))
                }
                Spacer(minLength: 0)
            }
            .background(theme.line)
            .clipShape(Capsule())
        }
        .frame(height: height)
    }
}

// MARK: - Icons

struct FileIconView: View {
    let url: URL
    let isDirectory: Bool
    var size: CGFloat = 18

    var body: some View {
        Image(nsImage: ThumbnailLoader.icon(for: url, isDirectory: isDirectory))
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
    }
}

struct TypeIconView: View {
    let ext: String
    let isDirectory: Bool
    var size: CGFloat = 18

    var body: some View {
        Image(nsImage: ThumbnailLoader.typeIcon(extension: ext, isDirectory: isDirectory))
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
    }
}

/// Async thumbnail for image files with an icon fallback.
struct ThumbnailView: View {
    @Environment(\.theme) private var theme
    let url: URL
    var maxPixel: Int = 320
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(theme.surface)
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                FileIconView(url: url, isDirectory: false, size: 32)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .task(id: url) {
            image = await ThumbnailLoader.shared.thumbnail(for: url, maxPixel: maxPixel)
        }
    }
}

// MARK: - Empty and progress states

struct EmptyState: View {
    @Environment(\.theme) private var theme
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(theme.brandSoft).frame(width: 64, height: 64)
                Image(systemName: systemImage)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(theme.brand)
            }
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(theme.ink)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(theme.body)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.primaryLarge)
                    .padding(.top, 6)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ProgressState: View {
    @Environment(\.theme) private var theme
    let title: String
    let detail: String
    var fraction: Double? = nil
    var cancel: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            if let fraction {
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
                    .frame(width: 320)
            } else {
                ProgressView()
                    .controlSize(.large)
            }
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.ink)
            Text(detail)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(theme.muted)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 520)
            if let cancel {
                Button("Stop", action: cancel)
                    .buttonStyle(.secondary)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Toast

struct ToastView: View {
    @Environment(\.theme) private var theme
    @Environment(AppState.self) private var appState
    let toast: Toast

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(toast.message)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(theme.ink)
                .lineLimit(2)
            if let actionTitle = toast.actionTitle {
                Button(actionTitle) {
                    if actionTitle == "Undo" { appState.undoLastCleanup() }
                    appState.toast = nil
                }
                .buttonStyle(.secondary)
            }
            Button {
                appState.toast = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.muted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.card)
                .shadow(color: .black.opacity(theme.isDark ? 0.5 : 0.15), radius: 18, y: 8)
        )
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(theme.line))
        .frame(maxWidth: 560)
    }

    private var icon: String {
        switch toast.style {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch toast.style {
        case .info: return theme.brand
        case .success: return theme.success
        case .warning: return theme.warning
        }
    }
}

// MARK: - Filter chips

struct ChipPicker<T: Hashable>: View {
    @Environment(\.theme) private var theme
    let options: [(T, String)]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.0) { option in
                let selected = option.0 == selection
                Button {
                    selection = option.0
                } label: {
                    Text(option.1)
                        .font(.system(size: 11.5, weight: selected ? .semibold : .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .foregroundStyle(selected ? theme.brand : theme.body)
                        .background(Capsule().fill(selected ? theme.brandSoft : theme.surface))
                        .overlay(Capsule().stroke(selected ? theme.brand.opacity(0.4) : theme.line))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Breadcrumb

struct Breadcrumb: View {
    @Environment(\.theme) private var theme
    let nodes: [FileNode]
    let onSelect: (FileNode) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(theme.muted)
                    }
                    Button {
                        onSelect(node)
                    } label: {
                        Text(node.displayName)
                            .font(.system(size: 12, weight: index == nodes.count - 1 ? .semibold : .medium))
                            .foregroundStyle(index == nodes.count - 1 ? theme.ink : theme.body)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Small helpers

/// Table cells on macOS can be hosted without the app's environment objects, so the
/// state is passed in explicitly instead of read from `@Environment`.
struct QueueToggle: View {
    @Environment(\.theme) private var theme
    let appState: AppState
    let node: FileNode
    let source: CleanupSource
    let reason: String

    var body: some View {
        let queued = appState.isQueued(node)
        let level = SafetyPolicy.assess(path: node.path, insidePackage: node.isInsidePackage)
        Button {
            appState.toggle(node: node, source: source, reason: reason)
        } label: {
            Image(systemName: queued ? "checkmark.circle.fill" : "plus.circle")
                .font(.system(size: 15))
                .foregroundStyle(queued ? theme.brand : theme.muted)
        }
        .buttonStyle(.plain)
        .disabled(level == .protected)
        .help(level == .protected ? "Protected path" : (queued ? "Remove from Review & Clean" : "Add to Review & Clean"))
    }
}

extension View {
    /// Standard context menu for anything that maps to a path on disk.
    func fileContextMenu(url: URL, node: FileNode? = nil, source: CleanupSource, reason: String, appState: AppState) -> some View {
        contextMenu {
            Button("Reveal in Finder") { TrashService.reveal(url) }
            Button("Open") { TrashService.open(url) }
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.path, forType: .string)
            }
            if let node {
                Divider()
                Button("Show in Sunburst") { appState.showInSunburst(node) }
                Button("Show in Folders") { appState.showInFolders(node) }
            }
            Divider()
            if appState.isQueued(url) {
                Button("Remove from Review & Clean") { appState.dequeue(url) }
            } else if let node {
                Button("Add to Review & Clean") { appState.enqueue(node: node, source: source, reason: reason) }
            } else {
                Button("Add to Review & Clean") {
                    var isDir: ObjCBool = false
                    FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                    let size = isDir.boolValue ? AppInventory.directorySize(url) : Int64((try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?.totalFileAllocatedSize ?? 0)
                    appState.enqueue(CleanupItem(url: url, size: size, source: source, reason: reason, isDirectory: isDir.boolValue))
                }
            }
        }
    }
}
