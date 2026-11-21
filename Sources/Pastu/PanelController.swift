import AppKit
import PastuCore
import SwiftUI

/// Owns the panel: shows it centered on the screen with the mouse, hides it on Esc / Return / click-away.
@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private static let size = NSSize(width: PanelMetrics.size.width, height: PanelMetrics.size.height)

    private let model: ClipListModel
    private let onSelect: (StoredClip) -> Void
    private let canAutoPaste: () -> Bool
    private let ignoredApps: IgnoredApps
    private let imageData: (Int64) -> Data?
    let panel = ClipPanel(size: PanelController.size)

    var isVisible: Bool { panel.isVisible }

    /// - Parameter onSelect: called after the panel closed, with the clip the user picked.
    /// - Parameter canAutoPaste: whether Pastu may send ⌘V (Accessibility permission); shown in the footer.
    init(
        model: ClipListModel,
        canAutoPaste: @escaping () -> Bool,
        ignoredApps: IgnoredApps = IgnoredApps(),
        imageData: @escaping (Int64) -> Data? = { _ in nil },
        onSelect: @escaping (StoredClip) -> Void
    ) {
        self.model = model
        self.canAutoPaste = canAutoPaste
        self.ignoredApps = ignoredApps
        self.imageData = imageData
        self.onSelect = onSelect
        super.init()
        panel.delegate = self
        panel.onCancel = { [weak self] in self?.hide() }
        panel.onDeleteSelected = { [weak self] in self?.model.deleteSelected() }
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        model.query = ""
        model.refresh()
        // A fresh view each time resets focus and scroll position.
        panel.contentView = NSHostingView(rootView: PanelView(
            model: model,
            canAutoPaste: canAutoPaste(),
            onSubmit: { [weak self] in self?.submit() },
            onIgnoreApp: { [weak self] in self?.ignoreSelectedApp() },
            imageData: imageData
        ))
        // The shadow of a borderless, transparent window is traced from its drawn pixels: draw the
        // rounded shell first, then recompute the shadow so it follows the corners, not the square frame.
        panel.displayIfNeeded()
        panel.invalidateShadow()
        panel.setFrameOrigin(origin(on: screenUnderMouse()))
        appear()
    }

    /// A short fade-in of the whole window (shadow included), skipped with Reduce Motion.
    private func appear() {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            panel.alphaValue = 1
            panel.makeKeyAndOrderFront(nil)
            return
        }
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    /// ⌘I: stop recording copies from the selected clip's source app, and say so in the footer.
    private func ignoreSelectedApp() {
        guard let clip = model.selectedClip else { return }
        guard let id = clip.sourceBundleIdentifier else {
            model.notice = "Source app unknown, so there is nothing to ignore"
            return
        }
        let name = AppLookup.name(for: id) ?? id
        model.notice = ignoredApps.add(id)
            ? "Ignoring \(name): its future copies are not recorded or read"
            : "\(name) is already ignored"
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
