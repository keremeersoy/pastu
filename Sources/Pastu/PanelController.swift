import AppKit
import PastuCore
import SwiftUI

/// Owns the panel: shows it centered on the screen with the mouse, hides it on Esc / Return / click-away.
@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private static let size = NSSize(width: 640, height: 420)

    private let model: ClipListModel
    private let panel = ClipPanel(size: PanelController.size)

    var isVisible: Bool { panel.isVisible }

    init(model: ClipListModel) {
        self.model = model
        super.init()
        panel.delegate = self
        panel.onCancel = { [weak self] in self?.hide() }
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        model.query = ""
        model.refresh()
        // A fresh view each time resets focus and scroll position.
        panel.contentView = NSHostingView(rootView: PanelView(model: model, onSubmit: { [weak self] in
            // Pasting the selection comes in the next step; for now Return just closes the panel.
            self?.hide()
        }))
        panel.setFrameOrigin(origin(on: screenUnderMouse()))
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    private func screenUnderMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    }

    private func origin(on screen: NSScreen?) -> NSPoint {
        guard let frame = screen?.visibleFrame else { return .zero }
        return NSPoint(
            x: frame.midX - Self.size.width / 2,
            y: frame.minY + frame.height * 0.62 - Self.size.height / 2
        )
    }
}
