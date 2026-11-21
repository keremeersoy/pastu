import AppKit

/// Borderless floating panel that can take keyboard focus WITHOUT activating Pastu,
/// so the app the user was typing in keeps its focus (needed for pasting back later).
final class ClipPanel: NSPanel {
    var onCancel: (() -> Void)?
    /// ⌘⌫. Handled here because the search field's text editor consumes Backspace before SwiftUI sees it.
    var onDeleteSelected: (() -> Void)?

    init(size: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let backspaceKeyCode: UInt16 = 51
        if event.keyCode == backspaceKeyCode,
           event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command {
            onDeleteSelected?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    /// Esc.
    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
