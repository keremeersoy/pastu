import PastuCore
import SwiftUI

struct ClipRow: View {
    let clip: StoredClip
    let isSelected: Bool
    let shortcutDigit: Int?
    let imageData: (Int64) -> Data?

    var body: some View {
        let picture = clip.kind == .image ? ImageCache.shared.info(for: clip.id, load: imageData) : nil
        HStack(spacing: 10) {
            if clip.kind == .image {
                ThumbnailView(info: picture)
            } else {
                AppIconView(bundleIdentifier: clip.sourceBundleIdentifier, size: 22)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title(picture))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if clip.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
            if let shortcutDigit {
                Text("⌘\(shortcutDigit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.35) : .clear)
        )
    }

    private func title(_ picture: ImageCache.Info?) -> String {
        guard clip.kind == .image else { return ClipFormatting.rowTitle(clip.text) }
        guard let picture else { return "Image" }
        return "Image · \(picture.width)×\(picture.height)"
    }

    private var subtitle: String {
        let time = ClipFormatting.relativeTime(from: clip.lastCopiedAt, to: Date())
        guard let app = AppLookup.name(for: clip.sourceBundleIdentifier) else { return time }
        return "\(app) · \(time)"
    }
}
