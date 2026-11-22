import AppKit
import Testing
@testable import Pastu
@testable import PastuCore

@MainActor
@Suite struct StatusMenuTests {
    private func makeController(pasteboard: NSPasteboard) -> StatusMenuController {
        StatusMenuController(
            recording: RecordingState(), ignoredApps: IgnoredApps(),
            systemPasteboard: SystemPasteboard(pasteboard: pasteboard)
        )
    }

    /// Builds the menu without adding a real item to the menu bar, on a private pasteboard.
    private func withMenu(_ body: (StatusMenuController, NSMenu) -> Void) {
        let raw = NSPasteboard(name: .init("pastu.test.\(UUID())"))
        defer { raw.releaseGlobally() }
        let controller = makeController(pasteboard: raw)
        controller.install(inStatusBar: false)
        body(controller, controller.menuForTesting)
    }

    @Test func itemsFollowTheHIGOrder() {
        withMenu { _, menu in
            let titles = menu.items.filter { !$0.isHidden && !$0.isSeparatorItem }.map(\.title)
            #expect(titles == ["Show Pastu", "Pause Recording", "Clear History…", "Ignored Apps", "About Pastu", "Quit Pastu"])
        }
    }

    @Test func showItemDisplaysTheHotkey() {
        withMenu { _, menu in
            let show = menu.items.first { $0.title == "Show Pastu" }
            #expect(show?.keyEquivalent == "v")
            #expect(show?.keyEquivalentModifierMask == [.command, .shift])
        }
    }

    @Test func pausingChecksTheItemInsteadOfRenamingIt() {
        withMenu { controller, menu in
            let pause = menu.items.first { $0.title == "Pause Recording" }
            #expect(pause?.state == .off)
            controller.toggleRecording()
            #expect(pause?.state == .on)
            #expect(pause?.title == "Pause Recording")
        }
    }

    @Test func accessibilityDescriptionMentionsPause() {
        #expect(StatusMenuController.accessibilityDescription(isPaused: true) == "Pastu (paused)")
        #expect(StatusMenuController.accessibilityDescription(isPaused: false) == "Pastu")
    }

    @Test func warningsGetAnIconAndPlainText() {
        withMenu { controller, menu in
            controller.storageError = .save
            controller.menuNeedsUpdate(menu)
            let warning = menu.items.first { $0.title == "Pastu can't save new clips right now" }
            #expect(warning != nil)
            #expect(warning?.isHidden == false)
            #expect(warning?.image != nil)
        }
    }

    // MARK: Giving focus back

    /// Some other running app, used only for its identity: the injected hooks never really activate it.
    private func otherApp() throws -> NSRunningApplication {
        try #require(NSWorkspace.shared.runningApplications.first { $0.processIdentifier != getpid() })
    }

    /// A controller whose alert answers by itself and whose focus changes are only recorded.
    private func focusController(
        previous: NSRunningApplication?, isPastuActive: Bool = true
    ) -> (controller: StatusMenuController, reactivated: () -> [NSRunningApplication]) {
        let raw = NSPasteboard(name: .init("pastu.test.\(UUID())"))
        raw.releaseGlobally()
        let controller = makeController(pasteboard: raw)
        var activated = false
        var reactivated: [NSRunningApplication] = []
        controller.focus = StatusMenuController.Focus(
            // Once Pastu is active it is itself the frontmost app, so the previous one must be read before that.
            frontmostApp: { activated ? .current : previous },
            activatePastu: { activated = true },
            isPastuActive: { isPastuActive },
            reactivate: { reactivated.append($0) }
        )
        return (controller, { reactivated })
    }

    @Test(arguments: [NSApplication.ModalResponse.alertFirstButtonReturn, .alertSecondButtonReturn])
    func clearHistoryGivesFocusBackAfterTheAlert(answer: NSApplication.ModalResponse) throws {
        let previous = try otherApp()
        let (controller, reactivated) = focusController(previous: previous)
        let store = try ClipStore()
        try store.insert(CapturedClip(text: "a", sourceBundleIdentifier: nil, date: Date()))
        controller.store = store
        var reactivatedDuringAlert = false
        controller.runAlert = { _ in
            reactivatedDuringAlert = !reactivated().isEmpty
            return answer
        }
        controller.clearHistory()
        #expect(!reactivatedDuringAlert)
        #expect(reactivated() == [previous])
        #expect(try store.recent().isEmpty == (answer == .alertFirstButtonReturn))
    }

    /// The user switched to another app while the alert was open: that choice wins.
    @Test func clearHistoryDoesNotStealFocusWhenPastuIsNoLongerActive() throws {
        let (controller, reactivated) = focusController(previous: try otherApp(), isPastuActive: false)
        controller.store = try ClipStore()
        controller.runAlert = { _ in .alertSecondButtonReturn }
        controller.clearHistory()
        #expect(reactivated().isEmpty)
    }

    @Test func clearHistoryForgetsRowSnippets() throws {
        let (controller, _) = focusController(previous: nil)
        let store = try ClipStore()
        let text = String(repeating: "filler words ", count: 200) + "zebra"
        try store.insert(CapturedClip(text: text, sourceBundleIdentifier: nil, date: Date()))
        let model = ClipListModel(store: store)
        model.query = "zebra"
        _ = model.rowSnippet(for: try #require(model.selectedClip))
        #expect(!model.cachedSnippetIDs.isEmpty)
        controller.store = store
        controller.model = model
        controller.runAlert = { _ in .alertFirstButtonReturn }
        controller.clearHistory()
        #expect(model.cachedSnippetIDs.isEmpty)
    }

    private func aboutWindow() -> NSWindow {
        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        return window
    }

    @Test func closingTheAboutWindowGivesFocusBackOnce() throws {
        let previous = try otherApp()
        let (controller, reactivated) = focusController(previous: previous)
        let about = aboutWindow()
        controller.showAboutPanel = { about }
        controller.showAbout()
        // Choosing About again while it is open returns no new window and must not lose the app to go back to.
        controller.showAboutPanel = { nil }
        controller.showAbout()
        #expect(reactivated().isEmpty)
        NotificationCenter.default.post(name: NSWindow.willCloseNotification, object: aboutWindow())
        #expect(reactivated().isEmpty, "another window closing is not the About window closing")
        about.close()
        #expect(reactivated() == [previous])
        about.close()
        #expect(reactivated() == [previous])
    }

    @Test func closingTheAboutWindowDoesNotStealFocusWhenPastuIsNoLongerActive() throws {
        let (controller, reactivated) = focusController(previous: try otherApp(), isPastuActive: false)
        let about = aboutWindow()
        controller.showAboutPanel = { about }
        controller.showAbout()
        about.close()
        #expect(reactivated().isEmpty)
    }
}
