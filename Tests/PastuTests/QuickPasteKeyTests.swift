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
        #expect(model.filter == .images)
        NSApp.sendEvent(keyEvent("\t", keyCode: 48, modifiers: [], window: panel))
        await pump(0.2)
        #expect(model.filter == .all)
    }

    /// Goes through PanelController (the real wiring: controller -> panel callback -> model) and calls the
    /// panel's performKeyEquivalent directly. NSApp.sendEvent would route ⌘ shortcuts to the KEY window, and
    /// whether a window can become key depends on the desktop (a locked screen or an inactive session
    /// makes this fail), which would make the test depend on the machine instead of the code.
    @Test func commandBackspaceDeletesTheSelectedClip() async throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)

        let store = try ClipStore()
        for (i, text) in ["oldest", "middle", "newest"].enumerated() {
            try store.insert(CapturedClip(text: text, sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: Double(i))))
        }
        let model = ClipListModel(store: store)
        model.moveSelection(by: 1) // on "middle"

        let controller = PanelController(model: model, canAutoPaste: { true }, onSelect: { _ in })
        controller.show()
        await pump()
        defer { controller.hide() }

        let handled = controller.panel.performKeyEquivalent(
            with: keyEvent("\u{7F}", keyCode: 51, modifiers: .command, window: controller.panel)
        )
        #expect(handled)
        #expect(model.clips.map(\.text) == ["newest", "oldest"])
    }

    /// Plain Backspace must keep editing the search text, never delete a clip.
    @Test func plainBackspaceDoesNotDeleteAClip() async throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)

        let store = try ClipStore()
        for (i, text) in ["oldest", "newest"].enumerated() {
            try store.insert(CapturedClip(text: text, sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: Double(i))))
        }
        let model = ClipListModel(store: store)

        let controller = PanelController(model: model, canAutoPaste: { true }, onSelect: { _ in })
        controller.show()
        await pump()
        defer { controller.hide() }

        NSApp.sendEvent(keyEvent("\u{7F}", keyCode: 51, modifiers: [], window: controller.panel))
        await pump(0.2)
        #expect(model.clips.count == 2)
    }
    // The delete shortcut must be exactly ⌘⌫. These call the panel directly, so they hold no matter which
    // events AppKit chooses to route through performKeyEquivalent.
    @Test(arguments: [
        NSEvent.ModifierFlags([]),                 // plain Backspace edits the search text
        NSEvent.ModifierFlags([.shift]),
        NSEvent.ModifierFlags([.option]),
        NSEvent.ModifierFlags([.control]),
        NSEvent.ModifierFlags([.command, .shift]),
        NSEvent.ModifierFlags([.command, .option]),
    ])
    func onlyExactlyCommandBackspaceDeletes(modifiers: NSEvent.ModifierFlags) {
        let panel = ClipPanel(size: NSSize(width: 100, height: 100))
        var deletes = 0
        panel.onDeleteSelected = { deletes += 1 }
        let event = keyEvent("\u{7F}", keyCode: 51, modifiers: modifiers, window: panel)
        _ = panel.performKeyEquivalent(with: event)
        #expect(deletes == 0)
    }

    @Test func commandBackspaceIsHandledByThePanel() {
        let panel = ClipPanel(size: NSSize(width: 100, height: 100))
        var deletes = 0
        panel.onDeleteSelected = { deletes += 1 }
        let handled = panel.performKeyEquivalent(with: keyEvent("\u{7F}", keyCode: 51, modifiers: .command, window: panel))
        #expect(handled)
        #expect(deletes == 1)
    }
    // MARK: Ignore the source app (⌘I)

    private func controllerWithClips(app: String?) throws -> (PanelController, ClipListModel, IgnoredApps) {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        let store = try ClipStore()
        try store.insert(CapturedClip(text: "from a vault", sourceBundleIdentifier: app, date: Date(timeIntervalSince1970: 1)))
        let model = ClipListModel(store: store)
        let ignored = IgnoredApps(defaults: UserDefaults(suiteName: "pastu.test.\(UUID().uuidString)"))
        let controller = PanelController(model: model, canAutoPaste: { true }, ignoredApps: ignored, onSelect: { _ in })
        return (controller, model, ignored)
    }

    @Test func commandIIgnoresTheSelectedClipsSourceApp() async throws {
        let (controller, model, ignored) = try controllerWithClips(app: "com.example.vault")
        controller.show()
        await pump()
        defer { controller.hide() }

        NSApp.sendEvent(keyEvent("i", keyCode: 34, modifiers: .command, window: controller.panel))
        await pump(0.2)
        #expect(ignored.bundleIdentifiers == ["com.example.vault"])
        #expect(model.notice?.contains("Ignoring") == true)
    }

    @Test func commandIWithAnUnknownSourceAppAddsNothingButExplainsWhy() async throws {
        let (controller, model, ignored) = try controllerWithClips(app: nil)
        controller.show()
        await pump()
        defer { controller.hide() }

        NSApp.sendEvent(keyEvent("i", keyCode: 34, modifiers: .command, window: controller.panel))
        await pump(0.2)
        #expect(ignored.bundleIdentifiers.isEmpty)
        #expect(model.notice?.contains("unknown") == true)
    }

    @Test func plainIStaysInTheSearchField() async throws {
        let (controller, _, ignored) = try controllerWithClips(app: "com.example.vault")
        controller.show()
        await pump()
        defer { controller.hide() }

        NSApp.sendEvent(keyEvent("i", keyCode: 34, modifiers: [], window: controller.panel))
        await pump(0.2)
        #expect(ignored.bundleIdentifiers.isEmpty)
    }
}
}
