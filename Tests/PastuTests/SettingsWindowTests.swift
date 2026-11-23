import AppKit
import Testing
@testable import Pastu
@testable import PastuCore

extension ShellTests {
@MainActor
@Suite struct SettingsWindowTests {
    private func makeController(glassAvailable: Bool = true) -> SettingsWindowController {
        SettingsWindowController(theme: ThemeSettings(), glassAvailable: glassAvailable)
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
}
}
