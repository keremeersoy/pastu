import AppKit
import Testing
@testable import Pastu
@testable import PastuCore

/// Stands in for `SMAppService`: tests must never register the real app as a login item.
@MainActor
final class StubLoginItem: LoginItemService {
    var status: LoginItemStatus
    init(status: LoginItemStatus = .disabled) { self.status = status }
    func register() throws { status = .enabled }
    func unregister() throws { status = .disabled }
}

extension ShellTests {
@MainActor
@Suite struct SettingsWindowTests {
    private func makeController(
        glassAvailable: Bool = true, loginStatus: LoginItemStatus = .disabled
    ) -> SettingsWindowController {
        SettingsWindowController(
            theme: ThemeSettings(), launchAtLogin: LaunchAtLogin(service: StubLoginItem(status: loginStatus)),
            hotKeys: HotKeySettings { _ in true }, retention: RetentionSettings(), ignoredApps: IgnoredApps(),
            glassAvailable: glassAvailable
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
}
}
