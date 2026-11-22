import Foundation
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

    init(sendPaste: @escaping () -> Void = PasteSender.sendCommandV) {
        self.sendPaste = sendPaste
    }

    /// Shows the system Accessibility prompt if Pastu is not trusted yet and has not asked during this launch.
    /// The system dialog has a button that opens the right Settings pane.
    func requestAccessibilityIfNeeded() {
        guard !PasteSender.isTrusted, !didPromptForAccessibility else { return }
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

        guard PasteSender.isTrusted else {
            // The clip is already on the clipboard, so a manual ⌘V still works.
            requestAccessibilityIfNeeded()
            return
        }
        Task { @MainActor in
            // Give the panel a moment to disappear so the key event reaches the previous app.
            try? await Task.sleep(for: .milliseconds(80))
            self.sendPaste()
        }
    }
}
