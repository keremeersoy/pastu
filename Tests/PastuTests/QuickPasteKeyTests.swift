import AppKit
import SwiftUI
import Testing
@testable import Pastu
@testable import PastuCore

/// Drives the real panel with real key events through NSApplication.sendEvent,
/// the same path macOS uses for the user's keystrokes.
extension ShellTests {
@MainActor
@Suite struct QuickPasteKeyTests {
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
        panel.contentView = NSHostingView(rootView: PanelView(model: model, canAutoPaste: true, onSubmit: {
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
    @Test func commandPPinsTheSelectedClip() async throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)

        let store = try ClipStore()
        for (i, text) in ["oldest", "middle", "newest"].enumerated() {
            try store.insert(CapturedClip(text: text, sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: Double(i))))
        }
        let model = ClipListModel(store: store)
        model.moveSelection(by: 2) // on "oldest"

        let panel = ClipPanel(size: NSSize(width: 780, height: 460))
        panel.contentView = NSHostingView(rootView: PanelView(model: model, canAutoPaste: true, onSubmit: {}))
        panel.makeKeyAndOrderFront(nil)
        await pump()
        defer { panel.orderOut(nil) }

        NSApp.sendEvent(keyEvent("p", keyCode: 35, modifiers: .command, window: panel))
        await pump(0.2)
        #expect(model.clips.first?.text == "oldest")
        #expect(model.clips.first?.isPinned == true)
    }

    @Test func tabCyclesTheTypeFilter() async throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)

        let store = try ClipStore()
        for (i, text) in ["a note", "https://swift.org", "another note"].enumerated() {
            try store.insert(CapturedClip(text: text, sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: Double(i))))
        }
        let model = ClipListModel(store: store)

        let panel = ClipPanel(size: NSSize(width: 780, height: 460))
        panel.contentView = NSHostingView(rootView: PanelView(model: model, canAutoPaste: true, onSubmit: {}))
        panel.makeKeyAndOrderFront(nil)
        await pump()
        defer { panel.orderOut(nil) }

        NSApp.sendEvent(keyEvent("\t", keyCode: 48, modifiers: [], window: panel))
        await pump(0.2)
        #expect(model.filter == .text)
        NSApp.sendEvent(keyEvent("\t", keyCode: 48, modifiers: [], window: panel))
        await pump(0.2)
        #expect(model.filter == .links)
        #expect(model.clips.map(\.text) == ["https://swift.org"])
        NSApp.sendEvent(keyEvent("\t", keyCode: 48, modifiers: [], window: panel))
        await pump(0.2)
        #expect(model.filter == .all)
    }
}
}
