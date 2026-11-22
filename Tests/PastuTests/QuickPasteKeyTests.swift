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

    /// Polls for up to 2 s until the search field's field editor is the panel's first responder.
    private func searchFieldHasFocus(_ panel: NSWindow) async -> Bool {
        for _ in 0..<20 {
            if panel.isKeyWindow, panel.firstResponder is NSTextView { return true }
            await pump(0.1)
        }
        return false
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

    /// Shift-Tab arrives as keyCode 48 with the back-tab character (U+0019), the way AppKit reports it.
    @Test func shiftTabCyclesFiltersBackwards() async throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)

        let model = ClipListModel(store: try ClipStore())
        let panel = ClipPanel(size: NSSize(width: 780, height: 460))
        panel.contentView = NSHostingView(rootView: PanelView(model: model, canAutoPaste: true, onSubmit: {}))
        panel.makeKeyAndOrderFront(nil)
        await pump()
        defer { panel.orderOut(nil) }

        // Rarely (about 1 run in 7, only with the snapshot suite before it) the first Shift-Tab was not handled.
        // Wait until the search field really has focus, and say where focus was if it still fails.
        try #require(await searchFieldHasFocus(panel), "first responder: \(String(describing: panel.firstResponder))")
        NSApp.sendEvent(keyEvent("\u{19}", keyCode: 48, modifiers: .shift, window: panel))
        await pump(0.2)
        #expect(model.filter == .images, "first responder: \(String(describing: panel.firstResponder))")
        NSApp.sendEvent(keyEvent("\u{19}", keyCode: 48, modifiers: .shift, window: panel))
        await pump(0.2)
        #expect(model.filter == .links)
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
    // MARK: Banners

    /// Pressing the banner's Resume button goes through the controller to the recording state, and the banner goes away.
    @Test func resumeInThePausedBannerResumesRecording() async throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        enableAccessibilityTree()
        let recording = RecordingState()   // in memory
        recording.toggle()
        let controller = PanelController(
            model: ClipListModel(store: try ClipStore()), canAutoPaste: { true },
            isPaused: { recording.isPaused }, onResume: { recording.toggle() }, onSelect: { _ in }
        )
        controller.show()
        await pump()
        defer { controller.hide() }
        let content = try #require(controller.panel.contentView)

        #expect(accessibilityElement(containing: "Recording is paused", in: content) != nil)
        let resume = try #require(accessibilityElement(containing: "Resume", in: content))
        #expect(accessibilityPress(resume))
        await pump(0.2)
        #expect(recording.isPaused == false)
        #expect(accessibilityElement(containing: "Recording is paused", in: content) == nil)
    }

    /// "Enable…" hides the panel first (it would float above System Settings), then opens the settings pane.
    @Test func enableInTheAccessibilityBannerHidesThePanelAndOpensSettings() async throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        enableAccessibilityTree()
        var opened = 0
        let controller = PanelController(
            model: ClipListModel(store: try ClipStore()), canAutoPaste: { false },
            openAccessibilitySettings: { opened += 1 }, onSelect: { _ in }
        )
        controller.show()
        await pump()
        defer { controller.hide() }
        let content = try #require(controller.panel.contentView)

        let enable = try #require(accessibilityElement(containing: "Enable", in: content))
        #expect(accessibilityPress(enable))
        await pump(0.2)
        #expect(opened == 1)
        #expect(controller.isVisible == false)
    }

    // MARK: Mouse in the header

    /// Pins the shell style and turns Reduce Transparency off, so the filter control does not depend on the
    /// machine's accessibility settings.
    private func hostedPanel(_ model: ClipListModel, style: PanelStyle) async -> ClipPanel {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        enableAccessibilityTree()
        let panel = ClipPanel(size: NSSize(width: 780, height: 460))
        panel.contentView = NSHostingView(
            rootView: PanelView(model: model, canAutoPaste: true, onSubmit: {})
                .environment(\.panelStyle, style)
                .environment(\._accessibilityReduceTransparency, false)
        )
        panel.makeKeyAndOrderFront(nil)
        await pump()
        return panel
    }

    /// Our own glass buttons (macOS 26 only). The macOS 15 segmented control is a stock Picker and is only rendered:
    /// pressing its AppKit segment through accessibility ends this test process early (see `accessibilityPress`).
    @Test(.enabled(if: ProcessInfo.processInfo.isOperatingSystemAtLeast(
        OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0)
    ), "glass buttons exist only on macOS 26"))
    func clickingAFilterSelectsIt() async throws {
        let model = ClipListModel(store: try ClipStore())
        let panel = await hostedPanel(model, style: .glass)
        defer { panel.orderOut(nil) }
        let content = try #require(panel.contentView)

        let links = try #require(accessibilityElement(containing: "Links", in: content))
        // A segment here would mean the glass buttons fell back to the Picker: fail instead of pressing it.
        try #require(links.accessibilityRole?() == .button)
        #expect(accessibilityPress(links))
        await pump(0.2)
        #expect(model.filter == .links)
    }

    @Test func clearButtonEmptiesTheQuery() async throws {
        let model = ClipListModel(store: try ClipStore())
        model.query = "swift"
        let panel = await hostedPanel(model, style: .system)
        defer { panel.orderOut(nil) }
        let content = try #require(panel.contentView)

        let clear = try #require(accessibilityElement(containing: "Clear search", in: content))
        #expect(accessibilityPress(clear))
        await pump(0.2)
        #expect(model.query.isEmpty)
        #expect(accessibilityElement(containing: "Clear search", in: content) == nil)
    }

    // MARK: Ignore the source app (⌘I)

    private func controllerWithClips(app: String?) throws -> (PanelController, ClipListModel, IgnoredApps) {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        let store = try ClipStore()
        try store.insert(CapturedClip(text: "from a vault", sourceBundleIdentifier: app, date: Date(timeIntervalSince1970: 1)))
        let model = ClipListModel(store: store)
        let ignored = IgnoredApps()   // in memory: nothing is written to ~/Library/Preferences
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

    private func flagsEvent(_ modifiers: NSEvent.ModifierFlags, window: NSWindow) -> NSEvent {
        NSEvent.keyEvent(
            with: .flagsChanged, location: .zero, modifierFlags: modifiers,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil,
            characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 55 // left ⌘
        )!
    }

    /// Holding ⌘ shows all nine badges; the monitor only exists while the panel is open.
    @Test func holdingCommandIsTrackedOnlyWhileThePanelIsOpen() async throws {
        let (controller, _, _) = try controllerWithClips(app: nil)
        #expect(!controller.commandKeys.isMonitoring)
        controller.show()
        defer { controller.hide() }
        try #require(await searchFieldHasFocus(controller.panel))
        #expect(controller.commandKeys.isMonitoring)

        NSApp.sendEvent(flagsEvent(.command, window: controller.panel))
        await pump(0.2)
        #expect(controller.commandKeys.isCommandHeld)
        NSApp.sendEvent(flagsEvent([], window: controller.panel))
        await pump(0.2)
        #expect(!controller.commandKeys.isCommandHeld)

        NSApp.sendEvent(flagsEvent(.command, window: controller.panel))
        await pump(0.2)
        controller.hide()
        // Hiding while ⌘ is down must not leave the badges on for the next open, nor a monitor behind.
        #expect(!controller.commandKeys.isCommandHeld)
        #expect(!controller.commandKeys.isMonitoring)
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

    // MARK: Mouse on the rows

    /// A controller with three text clips (rows newest first: "newest", "middle", "oldest") that records what it pastes.
    private func controllerForMouse(app: String? = "com.example.editor") throws
        -> (PanelController, ClipListModel, IgnoredApps, picked: () -> [String], copied: () -> [String]) {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        enableAccessibilityTree()
        let store = try ClipStore()
        for (i, text) in ["oldest", "middle", "newest"].enumerated() {
            try store.insert(CapturedClip(text: text, sourceBundleIdentifier: app, date: Date(timeIntervalSince1970: Double(i))))
        }
        let model = ClipListModel(store: store)
        let ignored = IgnoredApps()   // in memory
        var picked: [String] = []
        var copied: [String] = []
        let controller = PanelController(
            model: model, canAutoPaste: { true }, ignoredApps: ignored, onCopy: { copied.append($0.text) }
        ) { picked.append($0.text) }
        return (controller, model, ignored, { picked }, { copied })
    }

    /// The centre of row `index` (0 = top), in window coordinates. Rows are found through the accessibility tree:
    /// the list is the first scroll area and each row one element in it, with its frame in screen coordinates.
    private func rowCenter(_ index: Int, in panel: NSWindow) throws -> NSPoint {
        let content = try #require(panel.contentView)
        let list = try #require((content.accessibilityChildren() ?? []).first {
            ($0 as AnyObject).accessibilityRole?() == .scrollArea
        } as AnyObject?)
        let rows = try #require((list.accessibilityChildren?() ?? []).first as AnyObject?).accessibilityChildren?() ?? []
        try #require(rows.indices.contains(index), "only \(rows.count) rows")
        let frame = try #require((rows[index] as AnyObject).accessibilityFrame?())
        return panel.convertPoint(fromScreen: NSPoint(x: frame.midX, y: frame.midY))
    }

    private func mouseEvent(_ type: NSEvent.EventType, at point: NSPoint, clickCount: Int, window: NSWindow) -> NSEvent {
        NSEvent.mouseEvent(
            with: type, location: point, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil,
            eventNumber: 0, clickCount: clickCount, pressure: type == .leftMouseUp ? 0 : 1
        )!
    }

    /// One press and release; a double click is the second pair with clickCount 2, as AppKit reports it.
    private func click(at point: NSPoint, clickCount: Int = 1, in window: NSWindow) {
        NSApp.sendEvent(mouseEvent(.leftMouseDown, at: point, clickCount: clickCount, window: window))
        NSApp.sendEvent(mouseEvent(.leftMouseUp, at: point, clickCount: clickCount, window: window))
    }

    @Test func clickingARowKeepsSearchFieldFocused() async throws {
        let (controller, model, _, picked, _) = try controllerForMouse()
        controller.show()
        defer { controller.hide() }
        try #require(await searchFieldHasFocus(controller.panel))

        click(at: try rowCenter(1, in: controller.panel), in: controller.panel)
        await pump(0.2)
        #expect(model.selectedIndex == 1)
        #expect(controller.isVisible)
        #expect(controller.panel.firstResponder is NSTextView, "first responder: \(String(describing: controller.panel.firstResponder))")
        #expect(picked().isEmpty)
    }

    /// Selection must follow the click at once, not after the double-click interval (about 0.5 s by default).
    @Test func singleClickSelectsWithoutWaitingForADoubleClick() async throws {
        let (controller, model, _, _, _) = try controllerForMouse()
        controller.show()
        defer { controller.hide() }
        try #require(await searchFieldHasFocus(controller.panel))
        try #require(NSEvent.doubleClickInterval > 0.15)

        click(at: try rowCenter(1, in: controller.panel), in: controller.panel)
        await pump(0.05)
        #expect(model.selectedIndex == 1)
    }

    @Test func doubleClickSubmits() async throws {
        let (controller, _, _, picked, _) = try controllerForMouse()
        controller.show()
        defer { controller.hide() }
        try #require(await searchFieldHasFocus(controller.panel))

        let point = try rowCenter(2, in: controller.panel)
        click(at: point, clickCount: 1, in: controller.panel)
        click(at: point, clickCount: 2, in: controller.panel)
        await pump(0.3)
        #expect(picked() == ["oldest"])
        #expect(!controller.isVisible)
    }

    /// The row's context menu as AppKit gets it for a right click there (`menu(for:)` on the hosting view), without
    /// popping it up: a real menu runs its own event loop, whose wake-up can stop the test runner's run loop and end
    /// the whole test process early with exit 0 (the same trap as pressing a segment, see `accessibilityPress`).
    private func contextMenu(onRow row: Int, in panel: NSWindow) throws -> NSMenu {
        let point = try rowCenter(row, in: panel)
        let event = try #require(NSEvent.mouseEvent(
            with: .rightMouseDown, location: point, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: panel.windowNumber, context: nil,
            eventNumber: 0, clickCount: 1, pressure: 1
        ))
        return try #require(panel.contentView?.menu(for: event), "no context menu on row \(row)")
    }

    /// Picks the item titled `title`, the way choosing it in the open menu would.
    private func choose(_ title: String, in menu: NSMenu) throws {
        let index = try #require(menu.items.firstIndex { $0.title == title }, "no \(title) in \(menu.items.map(\.title))")
        try #require(menu.items[index].isEnabled)
        menu.performActionForItem(at: index)
    }

    private func titles(_ menu: NSMenu) -> [String] {
        menu.items.filter { !$0.isSeparatorItem }.map(\.title)
    }

    @Test func rowContextMenuOffersTheRowActions() async throws {
        let (controller, _, _, _, _) = try controllerForMouse()
        controller.show()
        defer { controller.hide() }
        try #require(await searchFieldHasFocus(controller.panel))

        let menu = try contextMenu(onRow: 1, in: controller.panel)
        // The app is not installed, so the menu names it by its bundle identifier, as the ⌘I notice does.
        #expect(titles(menu) == ["Paste", "Copy", "Pin", "Delete", "Ignore “com.example.editor”"])
        #expect(menu.items.allSatisfy { $0.isSeparatorItem || $0.isEnabled })
        #expect(controller.isVisible)
        #expect(controller.panel.firstResponder is NSTextView)
    }

    @Test func pinFromTheContextMenuKeepsThePanelOpen() async throws {
        let (controller, model, _, _, _) = try controllerForMouse()
        controller.show()
        defer { controller.hide() }
        try #require(await searchFieldHasFocus(controller.panel))

        try choose("Pin", in: try contextMenu(onRow: 2, in: controller.panel))
        await pump(0.2)
        #expect(model.clips.first?.text == "oldest")
        #expect(model.clips.first?.isPinned == true)
        #expect(controller.isVisible)
        // A pinned row offers the opposite.
        #expect(titles(try contextMenu(onRow: 0, in: controller.panel)).contains("Unpin"))
    }

    @Test func deleteFromTheContextMenuKeepsThePanelOpen() async throws {
        let (controller, model, _, _, _) = try controllerForMouse()
        controller.show()
        defer { controller.hide() }
        try #require(await searchFieldHasFocus(controller.panel))

        try choose("Delete", in: try contextMenu(onRow: 1, in: controller.panel))
        await pump(0.2)
        #expect(model.clips.map(\.text) == ["newest", "oldest"])
        #expect(controller.isVisible)
    }

    @Test func ignoreFromTheContextMenuKeepsThePanelOpen() async throws {
        let (controller, model, ignored, _, _) = try controllerForMouse()
        controller.show()
        defer { controller.hide() }
        try #require(await searchFieldHasFocus(controller.panel))

        try choose("Ignore “com.example.editor”", in: try contextMenu(onRow: 1, in: controller.panel))
        await pump(0.2)
        #expect(ignored.bundleIdentifiers == ["com.example.editor"])
        #expect(model.notice?.contains("Ignoring") == true)
        #expect(controller.isVisible)
    }

    @Test func ignoreIsDisabledWhenTheSourceAppIsUnknown() async throws {
        let (controller, _, _, _, _) = try controllerForMouse(app: nil)
        controller.show()
        defer { controller.hide() }
        try #require(await searchFieldHasFocus(controller.panel))

        let menu = try contextMenu(onRow: 1, in: controller.panel)
        let ignore = try #require(menu.items.first { $0.title.hasPrefix("Ignore") })
        #expect(ignore.isEnabled == false)
    }

    @Test func pasteFromTheContextMenuPastesThatRow() async throws {
        let (controller, _, _, picked, copied) = try controllerForMouse()
        controller.show()
        defer { controller.hide() }
        try #require(await searchFieldHasFocus(controller.panel))

        try choose("Paste", in: try contextMenu(onRow: 1, in: controller.panel))
        await pump(0.2)
        #expect(picked() == ["middle"])
        #expect(copied().isEmpty)
        #expect(!controller.isVisible)
    }

    /// Copy is Paste without ⌘V: the panel closes and the clip goes to the copy path, never to the paste path.
    @Test func copyFromTheContextMenuCopiesWithoutPasting() async throws {
        let (controller, _, _, picked, copied) = try controllerForMouse()
        controller.show()
        defer { controller.hide() }
        try #require(await searchFieldHasFocus(controller.panel))

        try choose("Copy", in: try contextMenu(onRow: 1, in: controller.panel))
        await pump(0.2)
        #expect(copied() == ["middle"])
        #expect(picked().isEmpty)
        #expect(!controller.isVisible)
    }

    /// A titled window that can take key status from the panel, standing in for the menu or another app's window.
    private func keyThief() -> NSWindow {
        let other = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 60, height: 60), styleMask: [.titled], backing: .buffered, defer: false
        )
        other.isReleasedWhenClosed = false
        return other
    }

    /// A right click's menu runs its tracking loop inside the panel's `sendEvent`. If the panel loses key status in
    /// there and the menu is dismissed with the mouse over the panel, the panel stays open and takes key status back.
    @Test func menuDismissedInsideThePanelKeepsItOpenAndKey() async throws {
        let (controller, _, _, _, _) = try controllerForMouse()
        controller.show()
        defer { controller.hide() }
        try #require(await searchFieldHasFocus(controller.panel))
        let panel = controller.panel
        controller.mouseLocation = { NSPoint(x: panel.frame.midX, y: panel.frame.midY) }
        let other = keyThief()
        defer { other.orderOut(nil) }

        panel.handlingContextClick {
            other.makeKeyAndOrderFront(nil)
            #expect(!panel.isKeyWindow)
        }
        #expect(controller.isVisible)
        #expect(panel.isKeyWindow)
        #expect(await searchFieldHasFocus(panel))

        // Outside a context click, losing key still closes the panel.
        other.makeKeyAndOrderFront(nil)
        await pump(0.1)
        #expect(!controller.isVisible)
    }

    /// Dismissing the menu by clicking somewhere else (another app's window took key) must close the panel, as any
    /// click-away does, and must not take key status back: that app's typing would otherwise land in the panel.
    @Test func menuDismissedOutsideThePanelClosesItWithoutRekeying() async throws {
        let (controller, _, _, _, _) = try controllerForMouse()
        controller.show()
        defer { controller.hide() }
        try #require(await searchFieldHasFocus(controller.panel))
        let panel = controller.panel
        controller.mouseLocation = { NSPoint(x: panel.frame.maxX + 200, y: panel.frame.maxY + 200) }
        let other = keyThief()
        defer { other.orderOut(nil) }

        panel.handlingContextClick { other.makeKeyAndOrderFront(nil) }
        #expect(!controller.isVisible)
        #expect(!panel.isKeyWindow)
        #expect(NSApp.keyWindow !== panel)
    }

    /// Choosing an item keeps the panel working even when the menu hung over the panel's edge, so the mouse was
    /// outside the panel's frame when the item was picked.
    @Test func choosingAMenuItemOutsideThePanelFrameKeepsItOpenAndKey() async throws {
        let (controller, model, _, _, _) = try controllerForMouse()
        controller.show()
        defer { controller.hide() }
        try #require(await searchFieldHasFocus(controller.panel))
        let panel = controller.panel
        controller.mouseLocation = { NSPoint(x: panel.frame.maxX + 200, y: panel.frame.maxY + 200) }
        let menu = try contextMenu(onRow: 2, in: panel)
        let other = keyThief()
        defer { other.orderOut(nil) }

        panel.handlingContextClick {
            other.makeKeyAndOrderFront(nil)
            menu.performActionForItem(at: menu.items.firstIndex { $0.title == "Pin" }!)
        }
        await pump(0.2)
        #expect(model.clips.first?.isPinned == true)
        #expect(controller.isVisible)
        #expect(panel.isKeyWindow)
    }
}
}

