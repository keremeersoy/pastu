import SwiftUI

struct AppIconView: View {
    let bundleIdentifier: String?
    let size: CGFloat
    /// On the selected row's accent fill the fallback symbol turns white, like the row's other symbols.
    var isOnAccent = false

    var body: some View {
        Group {
            if let icon = AppLookup.icon(for: bundleIdentifier) {
                Image(nsImage: icon).resizable()
            } else {
                Image(systemName: "doc.text").resizable().scaledToFit()
                    .foregroundStyle(isOnAccent ? AnyShapeStyle(.white.opacity(0.8)) : AnyShapeStyle(.secondary))
                    .padding(3)
            }
        }
        .frame(width: size, height: size)
    }
}
