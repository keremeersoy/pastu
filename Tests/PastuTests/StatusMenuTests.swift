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

    @Test func showItemDisplaysTheHotkey() throws {
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
}
