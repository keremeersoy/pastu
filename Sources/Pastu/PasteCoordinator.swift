import AppKit
import PastuCore

/// Pastes a clip chosen in the panel: puts it on the pasteboard, then sends ⌘V to the app the user came from.
/// Owns the "ask for Accessibility once per launch" rule, so the launch prompt and the paste path cannot drift apart.
@MainActor
final class PasteCoordinator {
    /// Set once the database is open; without them there is nothing to paste.
    var store: ClipStore?
    var monitor: ClipboardMonitor?

    private var didPromptForAccessibility = false
    /// Sends ⌘V to the frontmost app; replaceable so tests can check that "Copy" never pastes.
    private let sendPaste: () -> Void
    private let isTrusted: () -> Bool
    private let isPastuActive: () -> Bool
    private let hidePastu: () -> Void

    init(
        sendPaste: @escaping () -> Void = PasteSender.sendCommandV,
        isTrusted: @escaping () -> Bool = { PasteSender.isTrusted },
        isPastuActive: @escaping () -> Bool = { NSApp.isActive },
        hidePastu: @escaping () -> Void = { NSApp.hide(nil) }
    ) {
        self.sendPaste = sendPaste
        self.isTrusted = isTrusted
        self.isPastuActive = isPastuActive
        self.hidePastu = hidePastu
    }

    /// Shows the system Accessibility prompt if Pastu is not trusted yet and has not asked during this launch.
    /// The system dialog has a button that opens the right Settings pane.
    func requestAccessibilityIfNeeded() {
        guard !isTrusted(), !didPromptForAccessibility else { return }
        didPromptForAccessibility = true
        PasteSender.requestTrust()
    }

    /// Puts the clip on the pasteboard and moves it to the top of the history, without sending ⌘V.
    /// Used by the row menu's "Copy", and as the first half of `paste(_:)`. Needs no Accessibility permission.
    /// Returns false when there was nothing to write (no database yet, or the picture's bytes are gone).
    @discardableResult
    func copy(_ clip: StoredClip) -> Bool {
        // Text or picture, written without Pastu recapturing its own write.
        guard let store, let monitor, ClipPasteboardWriter.copy(clip, from: store, using: monitor) else { return false }
        try? store.markUsed(id: clip.id)
        return true
    }

    /// Puts the clip on the pasteboard and sends ⌘V to the app the user came from.
    func paste(_ clip: StoredClip) {
        guard copy(clip) else { return }

        guard isTrusted() else {
            // The clip is already on the clipboard, so a manual ⌘V still works.
            requestAccessibilityIfNeeded()
            return
        }
        // The panel never activates Pastu, but its alert or About window may have left it active, and then ⌘V would go
        // to Pastu. Hiding hands activation to the app behind it.
        if isPastuActive() { hidePastu() }
        Task { @MainActor in
            // Give the panel a moment to disappear so the key event reaches the previous app.
            try? await Task.sleep(for: .milliseconds(80))
            self.sendPaste()
        }
    }

    /// Pastes queued clips one after another: each goes on the pasteboard and ⌘V is sent, then the next. Text clips
    /// carry the separator that follows them. Without the Accessibility permission nothing can be pasted for the
    /// user, so the text of the queue is copied as one piece instead and the permission is requested.
    func pasteQueue(
        _ steps: [(clip: StoredClip, suffix: String)],
        startDelay: Duration = .milliseconds(80), stepDelay: Duration = .milliseconds(180)
    ) async {
        guard !steps.isEmpty else { return }
        guard isTrusted() else {
            let combined = steps.filter { $0.clip.kind != .image }.map { $0.clip.text + $0.suffix }.joined()
            monitor?.copyToPasteboard(combined)
            requestAccessibilityIfNeeded()
            return
        }
        if isPastuActive() { hidePastu() }
        // Give the panel a moment to disappear so the key events reach the previous app.
        try? await Task.sleep(for: startDelay)
        for step in steps {
            guard put(step.clip, suffix: step.suffix) else { continue }
            sendPaste()
            // The target app reads the pasteboard when it handles ⌘V; the next clip must not replace it before that.
            try? await Task.sleep(for: stepDelay)
        }
    }

    /// Writes one queued clip, with its separator when it is text, and moves it up the history.
    private func put(_ clip: StoredClip, suffix: String) -> Bool {
        guard let store, let monitor else { return false }
        if clip.kind == .image {
            guard ClipPasteboardWriter.copy(clip, from: store, using: monitor) else { return false }
        } else {
            monitor.copyToPasteboard(clip.text + suffix)
        }
        try? store.markUsed(id: clip.id)
        return true
    }
}
