import SwiftUI

/// A picture clip's thumbnail in the row's 28pt leading slot.
struct ThumbnailView: View {
    let info: ImageCache.Info?
    /// On the selected row's accent fill the placeholder symbol turns white, like the row's other symbols.
    var isOnAccent = false

    var body: some View {
        Group {
            if let info {
                Image(nsImage: info.thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(isOnAccent ? AnyShapeStyle(.white.opacity(0.8)) : AnyShapeStyle(.secondary))
            }
        }
        .frame(width: 28, height: 22)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(.quaternary))
    }
}
