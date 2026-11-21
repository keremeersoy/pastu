import AppKit
import SwiftUI

/// The macOS 15 shell: a behind-window blur, the system look for floating panels before Liquid Glass.
/// SwiftUI's `.regularMaterial` blends within the window only, so the desktop would not show through.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        // The panel never activates Pastu, so an "active window" state would leave the blur dimmed.
        view.state = .active
        update(view)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        update(view)
    }

    private func update(_ view: NSVisualEffectView) {
        view.material = material
        // A SwiftUI clip shape does not reach the window-server blur; a mask image does.
        view.maskImage = Self.roundedMask(radius: cornerRadius)
    }

    /// A stretchable rounded-rectangle mask: only the corners are fixed, the middle stretches.
    static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}
