import ApplicationServices
import Carbon.HIToolbox

/// Sends ⌘V to whichever app is frontmost. Needs the Accessibility permission.
enum PasteSender {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt that takes the user to Privacy & Security > Accessibility.
    static func requestTrust() {
        // The literal avoids touching the non-Sendable kAXTrustedCheckOptionPrompt global.
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    static func sendCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        for keyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: keyDown)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
    }
}
