import SwiftUI
import QuickLook

struct SimilarPhotosView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme
    @AppStorage(Pref.photoThreshold) private var threshold = 8
    @State private var previewURL: URL?

    var body: some View {
        switch appState.similarPhotos {
        case .idle:
            VStack(spacing: 16) {
                EmptyState(systemImage: "photo.on.rectangle.angled", title: "Find similar photos",
                           message: "Near-identical shots are grouped with a perceptual hash of each image's thumbnail. Photos inside the Photos library and app bundles are left alone; the best copy in each group is suggested to keep.",
                           actionTitle: "Find Similar Photos") { appState.findSimilarPhotos() }
                HStack(spacing: 8) {
                    Text("Sensitivity").font(.system(size: 12)).foregroundStyle(theme.body)
                    ChipPicker(options: [(4, "Strict"), (8, "Balanced"), (12, "Loose")], selection: $threshold)
                }
                .padding(.bottom, 40)
            }
        case .running:
            let p = appState.photoProgress
            ProgressState(title: "Comparing photos…", detail: p.total > 0 ? "\(Format.count(p.done)) of \(Format.count(p.total)) images hashed" : "Collecting image files",
                          fraction: p.total > 0 ? Double(p.done) / Double(p.total) : nil) { appState.cancelSimilarPhotos() }
        case .failed(let message):
            EmptyState(systemImage: "exclamationmark.triangle", title: "Photo comparison failed", message: message, actionTitle: "Try Again") { appState.findSimilarPhotos() }
        case .done(let groups):
            if groups.isEmpty {
                EmptyState(systemImage: "checkmark.seal", title: "No similar photos", message: "No groups of near-identical images were found in the scan.", actionTitle: "Search Again") { appState.findSimilarPhotos() }
            } else {
                results(groups)
            }
        }
    }

    private func results(_ groups: [SimilarPhotoGroup]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(title: "Similar Photos", subtitle: "\(groups.count) groups · \(Format.bytes(groups.reduce(0) { $0 + $1.reclaimable })) if you keep the best of each")
                Spacer()
                Button {
                    appState.enqueue(groups.flatMap(\.extras).map { CleanupItem(node: $0.node, source: .similarPhotos, reason: "Near-duplicate photo") })
                } label: { Label("Add All Extras to Clean", systemImage: "plus.circle") }
                .buttonStyle(.primary)
                Button { appState.findSimilarPhotos() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.secondary).help("Search again")
            }
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(groups) { group in
                        groupCard(group)
                    }
                }
            }
            .quickLookPreview($previewURL)
        }
        .padding(24)
    }

    private func groupCard(_ group: SimilarPhotoGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(group.photos.count) similar · \(Format.bytes(group.reclaimable)) reclaimable")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Spacer()
                Button {
                    appState.enqueue(group.extras.map { CleanupItem(node: $0.node, source: .similarPhotos, reason: "Near-duplicate of \(group.photos[0].node.name)") })
                } label: { Label("Add extras", systemImage: "plus.circle") }
                .buttonStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Array(group.photos.enumerated()), id: \.element.id) { index, photo in
                        photoCard(photo, isBest: index == 0)
                    }
                }
            }
        }
        .card()
    }

    private func photoCard(_ photo: PhotoEntry, isBest: Bool) -> some View {
        let queued = appState.isQueued(photo.node)
        return VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                ThumbnailView(url: photo.node.url, maxPixel: 320)
                    .frame(width: 168, height: 126)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(queued ? theme.brand : (isBest ? theme.success : Color.clear), lineWidth: 2))
                    .onTapGesture { previewURL = photo.node.url }
                if isBest { Badge(text: "Keep", color: theme.success, filled: true).padding(6) }
                else if queued { Badge(text: "Queued", color: theme.brand, filled: true).padding(6) }
            }
            Text(photo.node.name).font(.system(size: 11.5, weight: .medium)).foregroundStyle(theme.ink).lineLimit(1).frame(width: 168, alignment: .leading)
            Text("\(photo.pixelWidth)×\(photo.pixelHeight) · \(Format.bytes(photo.node.size))").font(.system(size: 10.5)).foregroundStyle(theme.muted)
            HStack(spacing: 6) {
                Button { previewURL = photo.node.url } label: { Image(systemName: "eye") }.buttonStyle(.secondary)
                Button { TrashService.reveal(photo.node.url) } label: { Image(systemName: "magnifyingglass") }.buttonStyle(.secondary)
                Spacer()
                QueueToggle(appState: appState, node: photo.node, source: .similarPhotos, reason: "Near-duplicate photo")
            }
            .frame(width: 168)
        }
        .fileContextMenu(url: photo.node.url, node: photo.node, source: .similarPhotos, reason: "Near-duplicate photo", appState: appState)
    }
}
