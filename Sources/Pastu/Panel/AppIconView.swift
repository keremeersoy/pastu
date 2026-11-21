import SwiftUI

struct AppIconView: View {
    let bundleIdentifier: String?
    let size: CGFloat

    var body: some View {
        Group {
            if let icon = AppLookup.icon(for: bundleIdentifier) {
                Image(nsImage: icon).resizable()
            } else {
                Image(systemName: "doc.text").resizable().scaledToFit().foregroundStyle(.secondary).padding(3)
            }
        }
        .frame(width: size, height: size)
    }
}
