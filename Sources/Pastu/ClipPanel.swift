import AppKit

/// Borderless floating panel that can take keyboard focus WITHOUT activating Pastu,
/// so the app the user was typing in keeps its focus (needed for pasting back later).
final class ClipPanel: NSPanel {
    var onCancel: (() -> Void)?
    /// ⌘⌫. Handled here because the search field's text editor consumes Backspace before SwiftUI sees it.
    var onDeleteSelected: (() -> Void)?

    /// ⌘↑ and ⌘↓. Handled here because the search field's text editor moves its caret to the start or end of the
    /// text before SwiftUI sees these keys.
    var onMoveToStart: (() -> Void)?
    var onMoveToEnd: (() -> Void)?

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

    /// SwiftUI focuses the search field when the panel's view appears, but rarely that request does nothing and the
    /// key panel is left with no focused view: typing would go nowhere. Checked one run-loop turn after becoming key,
    /// because SwiftUI applies its own request in between.
    override func becomeKey() {
        super.becomeKey()
        DispatchQueue.main.async { [weak self] in self?.focusSearchFieldIfNothingIsFocused() }
    }

    /// Touches only a panel without any focused view (the window is its own first responder), so it never takes
    /// focus from another view, and never key status or activation from another window.
    private func focusSearchFieldIfNothingIsFocused() {
        guard firstResponder === self, let contentView, let field = Self.editableTextField(in: contentView) else { return }
        makeFirstResponder(field)
    }

    /// The search field is the panel's only editable text field.
    private static func editableTextField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField, field.isEditable { return field }
        for subview in view.subviews {
            if let field = editableTextField(in: subview) { return field }
        }
        return nil
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let backspaceKeyCode: UInt16 = 51
        if event.keyCode == backspaceKeyCode,
           event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command {
            onDeleteSelected?()
            return true
        }
        let upArrowKeyCode: UInt16 = 126, downArrowKeyCode: UInt16 = 125
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.numericPad, .function]) == .command {
            if event.keyCode == upArrowKeyCode { onMoveToStart?(); return true }
            if event.keyCode == downArrowKeyCode { onMoveToEnd?(); return true }
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
