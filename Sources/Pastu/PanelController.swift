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
    private let isPaused: () -> Bool
    private let onResume: () -> Void
    private let openAccessibilitySettings: () -> Void
    private let onCopy: (StoredClip) -> Void
    let panel = ClipPanel(size: PanelController.size)
    /// Watches ⌘ only while the panel is visible (started in `show`, stopped in `hide`).
    let commandKeys = CommandKeyMonitor()
    /// Where the mouse is, in screen coordinates; replaceable so tests can dismiss a menu "outside" the panel.
    var mouseLocation: () -> NSPoint = { NSEvent.mouseLocation }

    var isVisible: Bool { panel.isVisible }

    /// - Parameter onSelect: called after the panel closed, with the clip the user picked.
    /// - Parameter canAutoPaste: whether Pastu may send ⌘V (Accessibility permission); a banner says so if not.
    /// - Parameter isPaused: whether recording is paused; read each time the panel opens.
    /// - Parameter onResume: the paused banner's "Resume" button.
    /// - Parameter openAccessibilitySettings: the Accessibility banner's "Enable…" button; the panel hides first.
    /// - Parameter onCopy: the row menu's "Copy"; called after the panel closed, like `onSelect` but without ⌘V.
    init(
        model: ClipListModel,
        canAutoPaste: @escaping () -> Bool,
        ignoredApps: IgnoredApps = IgnoredApps(),
        imageData: @escaping (Int64) -> Data? = { _ in nil },
        isPaused: @escaping () -> Bool = { false },
        onResume: @escaping () -> Void = {},
        openAccessibilitySettings: @escaping () -> Void = SystemSettings.openAccessibility,
        onCopy: @escaping (StoredClip) -> Void = { _ in },
        onSelect: @escaping (StoredClip) -> Void
    ) {
        self.model = model
        self.canAutoPaste = canAutoPaste
        self.ignoredApps = ignoredApps
        self.imageData = imageData
        self.isPaused = isPaused
        self.onResume = onResume
        self.openAccessibilitySettings = openAccessibilitySettings
        self.onCopy = onCopy
        self.onSelect = onSelect
        super.init()
        panel.delegate = self
        panel.onCancel = { [weak self] in
            // An open shortcuts overlay is dismissed first, then a non-empty search is cleared; only then it closes.
            if model.showsShortcuts {
                model.showsShortcuts = false
            } else if model.escape() == .close {
                self?.hide()
            }
        }
        panel.onDeleteSelected = { [weak self] in
            guard let self, let id = model.selectedClip?.id else { return }
            model.deleteSelected()
            PanelCaches.forget(id, model: model)
        }
        panel.onMoveToStart = { model.moveToStart() }
        panel.onMoveToEnd = { model.moveToEnd() }
        panel.onContextClickEnded = { [weak self] chose in self?.contextClickEnded(choseMenuItem: chose) }
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        model.resetForShow()
        PanelCaches.retainOnly(Set(model.clips.map(\.id)))
        // A fresh view each time resets focus and scroll position.
        panel.contentView = NSHostingView(rootView: PanelView(
            model: model,
            canAutoPaste: canAutoPaste(),
            isPaused: isPaused(),
            onSubmit: { [weak self] in self?.submit() },
            onIgnoreApp: { [weak self] in self?.ignoreSelectedApp() },
            onCopyOnly: { [weak self] in self?.copySelected() },
            onResume: onResume,
            onOpenAccessibilitySettings: { [weak self] in
                // Hide first: the floating panel would otherwise cover System Settings.
                self?.hide()
                self?.openAccessibilitySettings()
            },
            imageData: imageData,
            commandKeys: commandKeys
        ))
        // The shadow of a borderless, transparent window is traced from its drawn pixels: draw the
        // rounded shell first, then recompute the shadow so it follows the corners, not the square frame.
        panel.displayIfNeeded()
        panel.invalidateShadow()
        panel.setFrameOrigin(origin(on: screenUnderMouse()))
        commandKeys.start()
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

    /// The row menu's "Copy": the same as `submit` but the clip only goes on the clipboard.
    private func copySelected() {
        let clip = model.selectedClip
        hide()
        if let clip { onCopy(clip) }
    }

    func hide() {
        commandKeys.stop()
        panel.orderOut(nil)
        PanelCaches.panelDidHide(model: model)
    }

    /// Clicking away closes the panel. A row's context menu is the exception: if its tracking loop takes key status,
    /// closing here would throw away a Pin, Delete or Ignore the user is about to choose.
    func windowDidResignKey(_ notification: Notification) {
        guard !panel.isHandlingContextClick else { return }
        hide()
    }

    /// A row menu closed and the panel lost key status during it (the resign was held back). If the user chose an
    /// item, or dismissed the menu with the mouse over the panel, they are still working in the panel: take key
    /// status back so typing goes to the search field (`makeKey` on the non-activating panel does not activate
    /// Pastu). Otherwise they dismissed it by clicking elsewhere, maybe in another app: do the resign that was held
    /// back and close, never re-key, or that app's keystrokes would land in Pastu's search field.
    private func contextClickEnded(choseMenuItem: Bool) {
        guard panel.isVisible, !panel.isKeyWindow else { return }
        if choseMenuItem || NSMouseInRect(mouseLocation(), panel.frame, false) {
            panel.makeKey()
        } else {
            hide()
        }
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
