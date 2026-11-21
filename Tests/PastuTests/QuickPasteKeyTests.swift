import AppKit
import SwiftUI
import Testing
@testable import Pastu
@testable import PastuCore

/// Drives the real panel with real key events through NSApplication.sendEvent,
/// the same path macOS uses for the user's keystrokes.
@MainActor
@Suite(.serialized) struct QuickPasteKeyTests {
    private struct Harness {
        let panel: ClipPanel
        let model: ClipListModel
        var submitted: [String?]
    }

    private func keyEvent(_ character: String, keyCode: UInt16, modifiers: NSEvent.ModifierFlags, window: NSWindow) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: modifiers,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil,
            characters: character, charactersIgnoringModifiers: character,
            isARepeat: false, keyCode: keyCode
        )!
    }

    private func pump(_ seconds: Double = 0.4) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    /// Covers our own handling only. It cannot prove how macOS routes real keystrokes to an
    /// inactive app: NSApp.sendEvent delivers to the window regardless of activation.
    @Test func commandTwoSubmitsTheSecondRow() async throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)

        let store = try ClipStore()
        for (i, text) in ["oldest", "middle", "newest"].enumerated() {
            try store.insert(CapturedClip(text: text, sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: Double(i))))
        }
        let model = ClipListModel(store: store)
        var submitted: [String?] = []

        let panel = ClipPanel(size: NSSize(width: 780, height: 460))
        panel.contentView = NSHostingView(rootView: PanelView(model: model, onSubmit: {
            submitted.append(model.selectedClip?.text)
        }))
        panel.makeKeyAndOrderFront(nil)
        await pump()
        defer { panel.orderOut(nil) }

        // Rows are newest first: ⌘1 = "newest", ⌘2 = "middle".
        NSApp.sendEvent(keyEvent("2", keyCode: 19, modifiers: .command, window: panel))
        await pump(0.2)
        #expect(submitted == ["middle"])
    }
}
