import AppKit
import Testing
@testable import Pastu
@testable import PastuCore

extension ShellTests {
@MainActor
@Suite struct IgnoredAppsSettingsTests {
    @Test func anAppBundleGivesItsIdentifier() {
        let url = URL(fileURLWithPath: "/System/Applications/Calculator.app")
        #expect(IgnoredAppChoice.bundleIdentifier(at: url) == "com.apple.calculator")
    }

    @Test func somethingThatIsNotAnAppGivesNil() {
        #expect(IgnoredAppChoice.bundleIdentifier(at: URL(fileURLWithPath: "/System/Library")) == nil)
        #expect(IgnoredAppChoice.bundleIdentifier(at: URL(fileURLWithPath: "/no/such/thing.app")) == nil)
        #expect(IgnoredAppChoice.bundleIdentifier(at: URL(fileURLWithPath: "/etc/hosts")) == nil)
    }

    private func controller(_ settings: AppSettings) -> SettingsWindowController {
        SettingsWindowController(settings: settings, glassAvailable: true)
    }

    @Test func theWindowListsIgnoredAppsByNameAndFallsBackToTheIdentifier() async throws {
        enableAccessibilityTree()
        let settings = AppSettings.inMemory()
        settings.ignoredApps.add("com.apple.calculator")
        settings.ignoredApps.add("com.example.gone")
        let window = try #require(controller(settings).show())
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(300))
        let content = try #require(window.contentView)
        #expect(accessibilityElement(containing: "Calculator", in: content) != nil)
        #expect(accessibilityElement(containing: "com.example.gone", in: content) != nil)
    }

    @Test func removingAnAppFromTheListStopsIgnoringIt() async throws {
        enableAccessibilityTree()
        let settings = AppSettings.inMemory()
        settings.ignoredApps.add("com.example.gone")
        let window = try #require(controller(settings).show())
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(300))
        let content = try #require(window.contentView)
        let button = try #require(accessibilityElement(containing: "Stop ignoring com.example.gone", in: content))
        #expect(accessibilityPress(button))
        #expect(settings.ignoredApps.bundleIdentifiers.isEmpty)
    }

    @Test func anEmptyListSaysHowToAddOne() async throws {
        enableAccessibilityTree()
        let window = try #require(controller(.inMemory()).show())
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(300))
        let content = try #require(window.contentView)
        #expect(accessibilityElement(containing: "⌘I", in: content) != nil)
    }
}
}
