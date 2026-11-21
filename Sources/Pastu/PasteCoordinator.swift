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

    /// Shows the system Accessibility prompt if Pastu is not trusted yet and has not asked during this launch.
    /// The system dialog has a button that opens the right Settings pane.
    func requestAccessibilityIfNeeded() {
        guard !PasteSender.isTrusted, !didPromptForAccessibility else { return }
        didPromptForAccessibility = true
        PasteSender.requestTrust()
    }

    /// Puts the clip on the pasteboard and sends ⌘V to the app the user came from.
    func paste(_ clip: StoredClip) {
        // Text or picture, written without Pastu recapturing its own write. Nothing to paste if the picture is gone.
        guard let store, let monitor, ClipPasteboardWriter.copy(clip, from: store, using: monitor) else { return }
        try? store.markUsed(id: clip.id)

        guard PasteSender.isTrusted else {
            // The clip is already on the clipboard, so a manual ⌘V still works.
            requestAccessibilityIfNeeded()
            return
        }
        Task { @MainActor in
            // Give the panel a moment to disappear so the key event reaches the previous app.
            try? await Task.sleep(for: .milliseconds(80))
            PasteSender.sendCommandV()
        }
    }
}
