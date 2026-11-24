import Foundation
import Testing
@testable import Pastu

extension ShellTests {
/// Inside `ShellTests` (serialized) because it swaps a static hook.
@MainActor
@Suite struct AppLookupTests {
    /// Rows ask for the name and icon every time they are rebuilt; an app that is gone must not cost a
    /// LaunchServices query each time.
    @Test func aMissingAppIsLookedUpOnce() {
        let original = AppLookup.findApp
        defer { AppLookup.findApp = original }
        var calls = 0
        AppLookup.findApp = { _ in calls += 1; return nil }

        let name = "test.missing.\(UUID())"
        for _ in 0..<3 { #expect(AppLookup.name(for: name) == nil) }
        #expect(calls == 1)
        let icon = "test.missing.\(UUID())"
        for _ in 0..<3 { #expect(AppLookup.icon(for: icon) == nil) }
        #expect(calls == 2)
    }
}
}
