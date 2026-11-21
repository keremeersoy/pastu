import AppKit
import PastuCore
import SwiftUI

/// Owns the panel: shows it centered on the screen with the mouse, hides it on Esc / Return / click-away.
@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private static let size = NSSize(width: 640, height: 420)

    private let model: ClipListModel
    private let onSelect: (StoredClip) -> Void
    private let panel = ClipPanel(size: PanelController.size)

    var isVisible: Bool { panel.isVisible }

    /// - Parameter onSelect: called after the panel closed, with the clip the user picked.
    init(model: ClipListModel, onSelect: @escaping (StoredClip) -> Void) {
        self.model = model
        self.onSelect = onSelect
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
            self?.submit()
        }))
        panel.setFrameOrigin(origin(on: screenUnderMouse()))
        panel.makeKeyAndOrderFront(nil)
    }

    /// Closes the panel, then hands the selected clip over (so focus is back in the previous app).
    private func submit() {
        let clip = model.selectedClip
        hide()
        if let clip { onSelect(clip) }
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
