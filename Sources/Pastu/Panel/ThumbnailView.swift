import SwiftUI

struct ThumbnailView: View {
    let info: ImageCache.Info?

    var body: some View {
        Group {
            if let info {
                Image(nsImage: info.thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo").foregroundStyle(.secondary)
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.quaternary))
    }
}
