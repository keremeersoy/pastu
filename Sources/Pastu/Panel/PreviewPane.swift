import PastuCore
import SwiftUI

struct PreviewPane: View {
    let clip: StoredClip?
    let imageData: (Int64) -> Data?

    var body: some View {
        if let clip {
            let preview = clip.kind == .image ? (text: "", hiddenCharacters: 0) : ClipFormatting.previewText(clip.text)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    AppIconView(bundleIdentifier: clip.sourceBundleIdentifier, size: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(AppLookup.name(for: clip.sourceBundleIdentifier) ?? "Unknown app")
                            .font(.callout.weight(.medium))
                        Text(ClipFormatting.relativeTime(from: clip.lastCopiedAt, to: Date()))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if clip.kind == .image {
                    picturePreview(for: clip)
                } else {
                    ScrollView {
                        Text(preview.text)
                            .font(.system(.callout, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if preview.hiddenCharacters > 0 {
                            Text("… \(preview.hiddenCharacters) more characters")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 6)
                        }
                    }
                }

                Text(details(for: clip))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            Text("Select a clip to preview")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func picturePreview(for clip: StoredClip) -> some View {
        if let image = ImageCache.shared.fullImage(for: clip.id, load: imageData) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Label("Picture not available", systemImage: "photo")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func details(for clip: StoredClip) -> String {
        let stats: String
        if clip.kind == .image {
            let picture = ImageCache.shared.info(for: clip.id, load: imageData)
            stats = picture.map { "\($0.width)×\($0.height) · \(ClipFormatting.fileSize($0.byteCount))" } ?? "Image"
        } else {
            stats = ClipFormatting.stats(clip.text)
        }
        return clip.copyCount > 1 ? "\(stats) · copied \(clip.copyCount) times" : stats
    }
}
