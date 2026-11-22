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

    /// Called after a right click (or ⌃-click) was handled, with its context menu closed again. The argument says
    /// whether a menu item was chosen (rather than the menu being dismissed).
    var onContextClickEnded: ((_ choseMenuItem: Bool) -> Void)?
    /// True while a right click is being handled. Its context menu runs its tracking loop synchronously inside
    /// `sendEvent`, so this spans the whole time the menu is open.
    private(set) var isHandlingContextClick = false

    override func sendEvent(_ event: NSEvent) {
        let isContextClick = event.type == .rightMouseDown
            || (event.type == .leftMouseDown && event.modifierFlags.contains(.control))
        guard isContextClick else { return super.sendEvent(event) }
        handlingContextClick { super.sendEvent(event) }
    }

    /// Runs `body` as a context click: losing key status inside it is the menu's doing, not the user leaving.
    /// AppKit sends a chosen item's action before the menu call returns, so it is seen here.
    func handlingContextClick(_ body: () -> Void) {
        var choseMenuItem = false
        let observer = NotificationCenter.default.addObserver(
            forName: NSMenu.didSendActionNotification, object: nil, queue: nil
        ) { _ in
            MainActor.assumeIsolated { choseMenuItem = true }
        }
        isHandlingContextClick = true
        body()
        isHandlingContextClick = false
        NotificationCenter.default.removeObserver(observer)
        onContextClickEnded?(choseMenuItem)
    }

    /// Esc.
    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
