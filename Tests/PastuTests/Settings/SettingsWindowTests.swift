import AppKit
import Testing
@testable import Pastu
@testable import PastuCore

extension ShellTests {
@MainActor
@Suite struct SettingsWindowTests {
    private func makeController(
        glassAvailable: Bool = true, loginStatus: LoginItemStatus = .disabled, maxContentHeight: CGFloat? = nil
    ) -> SettingsWindowController {
        SettingsWindowController(
            settings: .inMemory(loginStatus: loginStatus), glassAvailable: glassAvailable,
            maxContentHeight: { maxContentHeight ?? SettingsWindowController.heightThatFitsTheScreen() }
        )
    }

    @Test func showOpensAWindowTitledSettings() throws {
        let controller = makeController()
        let window = try #require(controller.show())
        defer { window.close() }
        #expect(window.title == "Settings")
        #expect(window.isVisible)
    }

    /// Choosing Settings again while it is open only brings it forward; there is no second window.
    @Test func showingTwiceKeepsOneWindow() throws {
        let controller = makeController()
        let window = try #require(controller.show())
        defer { window.close() }
        #expect(controller.show() == nil)
        #expect(window.isVisible)
    }

    @Test func itOpensAgainAfterBeingClosed() throws {
        let controller = makeController()
        try #require(controller.show()).close()
        let again = try #require(controller.show())
        defer { again.close() }
        #expect(again.isVisible)
    }

    @Test func closingTheWindowDoesNotQuitTheApp() throws {
        // A window that releases itself on close would be freed while the controller still points at it.
        let controller = makeController()
        let window = try #require(controller.show())
        window.close()
        #expect(!window.isReleasedWhenClosed)
    }

    @Test func theWindowShowsTheThemeChoices() async throws {
        enableAccessibilityTree()
        let controller = makeController()
        let window = try #require(controller.show())
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(300))
        let content = try #require(window.contentView)
        for text in ["Appearance", "Material"] {
            #expect(accessibilityElement(containing: text, in: content) != nil, "missing \(text)")
        }
    }

    @Test func withoutGlassTheMaterialListHasNoLiquidGlass() async throws {
        enableAccessibilityTree()
        let controller = makeController(glassAvailable: false)
        let window = try #require(controller.show())
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(300))
        let content = try #require(window.contentView)
        #expect(accessibilityElement(containing: "Liquid Glass", in: content) == nil)
    }

    @Test func theWindowOffersOpenAtLogin() async throws {
        enableAccessibilityTree()
        let window = try #require(makeController().show())
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(300))
        let content = try #require(window.contentView)
        #expect(accessibilityElement(containing: "Open Pastu at login", in: content) != nil)
        #expect(accessibilityElement(containing: "System Settings → General → Login Items", in: content) == nil)
    }

    @Test func aPendingApprovalPointsToSystemSettings() async throws {
        enableAccessibilityTree()
        let window = try #require(makeController(loginStatus: .requiresApproval).show())
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(300))
        let content = try #require(window.contentView)
        #expect(accessibilityElement(containing: "System Settings → General → Login Items", in: content) != nil)
    }

    @Test func anUnavailableLoginItemSaysSo() async throws {
        enableAccessibilityTree()
        let window = try #require(makeController(loginStatus: .unavailable).show())
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(300))
        let content = try #require(window.contentView)
        #expect(accessibilityElement(containing: "isn't available for this copy of Pastu", in: content) != nil)
    }

    @Test func theWindowShowsTheCurrentShortcut() async throws {
        enableAccessibilityTree()
        let window = try #require(makeController().show())
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(300))
        let content = try #require(window.contentView)
        #expect(accessibilityElement(containing: "⇧⌘V", in: content) != nil)
        #expect(accessibilityElement(containing: "Reset", in: content) == nil, "no Reset while it is the default")
    }

    @Test func theWindowShowsTheHistoryLimits() async throws {
        enableAccessibilityTree()
        let window = try #require(makeController().show())
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(300))
        let content = try #require(window.contentView)
        for text in ["Keep up to", "Keep for", "Size limit", "5,000 clips", "90 days", "200 MB", "never deleted"] {
            #expect(accessibilityElement(containing: text, in: content) != nil, "missing \(text)")
        }
    }

    @Test func theWelcomeGuideCanBeOpenedAgainFromSettings() async throws {
        enableAccessibilityTree()
        let controller = makeController()
        var opened = 0
        controller.showWelcome = { opened += 1 }
        let window = try #require(controller.show())
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(300))
        let content = try #require(window.contentView)
        let button = try #require(accessibilityElement(containing: "Show Welcome Guide", in: content))
        #expect(accessibilityPress(button))
        #expect(opened == 1)
    }

    @Test func theWindowOffersTheQueueSeparator() async throws {
        enableAccessibilityTree()
        let window = try #require(makeController().show())
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(300))
        let content = try #require(window.contentView)
        for text in ["Between clips", "New line"] {
            #expect(accessibilityElement(containing: text, in: content) != nil, "missing \(text)")
        }
    }

    @Test func theWindowOffersTextSearchInPictures() async throws {
        enableAccessibilityTree()
        let window = try #require(makeController().show())
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(300))
        let content = try #require(window.contentView)
        #expect(accessibilityElement(containing: "Find text in pictures", in: content) != nil)
        #expect(accessibilityElement(containing: "nothing is sent anywhere", in: content) != nil)
    }

    // MARK: Size

    /// The window must fit the screen: the long list of settings scrolls instead of growing past the display.
    @Test func theWindowIsNeverTallerThanItsLimit() throws {
        let controller = makeController(maxContentHeight: 300)
        let window = try #require(controller.show())
        defer { window.close() }
        let content = try #require(window.contentView)
        #expect(content.frame.height <= 300)
        #expect(content.frame.height > 100)
    }

    @Test func aRoomyScreenGetsTheWholeListWithoutScrolling() throws {
        let tall = makeController(maxContentHeight: 10_000)
        let window = try #require(tall.show())
        defer { window.close() }
        let capped = makeController(maxContentHeight: 300)
        let small = try #require(capped.show())
        defer { small.close() }
        #expect(try #require(window.contentView).frame.height > 600)
        #expect(try #require(small.contentView).frame.height < (try #require(window.contentView).frame.height))
    }

    @Test func theDefaultLimitFitsTheMainScreen() throws {
        let screen = try #require(NSScreen.main)
        #expect(SettingsWindowController.heightThatFitsTheScreen() < screen.visibleFrame.height)
        #expect(SettingsWindowController.heightThatFitsTheScreen() > 300)
        let window = try #require(makeController().show())
        defer { window.close() }
        #expect(window.frame.height <= screen.visibleFrame.height)
    }

    @Test func theLastSectionIsReachableOnASmallWindow() async throws {
        enableAccessibilityTree()
        let window = try #require(makeController(maxContentHeight: 300).show())
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(300))
        let content = try #require(window.contentView)
        // Off-screen rows are still in the accessibility tree of a scroll view: scrolling is possible.
        #expect(accessibilityElement(containing: "Material", in: content) != nil)
    }
}
}
