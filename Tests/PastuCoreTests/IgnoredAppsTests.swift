import Foundation
import Testing
@testable import PastuCore

@MainActor
@Suite struct IgnoredAppsTests {
    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "pastu.test.\(UUID().uuidString)")!
    }

    @Test func startsEmpty() {
        #expect(IgnoredApps().bundleIdentifiers.isEmpty)
    }

    @Test func addInsertsAndReportsWhetherItWasNew() {
        let apps = IgnoredApps()
        #expect(apps.add("com.example.vault") == true)
        #expect(apps.add("com.example.vault") == false)
        #expect(apps.bundleIdentifiers == ["com.example.vault"])
    }

    @Test func listSurvivesARelaunch() {
        let defaults = freshDefaults()
        IgnoredApps(defaults: defaults).add("com.example.vault")
        #expect(IgnoredApps(defaults: defaults).bundleIdentifiers == ["com.example.vault"])
    }

    @Test func removeTakesAnAppOffAndPersists() {
        let defaults = freshDefaults()
        let apps = IgnoredApps(defaults: defaults)
        apps.add("com.a")
        apps.add("com.b")
        apps.remove("com.a")
        #expect(apps.bundleIdentifiers == ["com.b"])
        #expect(IgnoredApps(defaults: defaults).bundleIdentifiers == ["com.b"])
    }

    @Test func removingAnUnknownAppIsHarmless() {
        let apps = IgnoredApps()
        apps.add("com.a")
        apps.remove("com.unknown")
        #expect(apps.bundleIdentifiers == ["com.a"])
    }

    @Test func blankIdentifiersAreRejected() {
        let apps = IgnoredApps()
        #expect(apps.add("") == false)
        #expect(apps.add("   ") == false)
        #expect(apps.bundleIdentifiers.isEmpty)
    }

    @Test func surroundingWhitespaceIsTrimmed() {
        let apps = IgnoredApps()
        #expect(apps.add("  com.a \n") == true)
        #expect(apps.bundleIdentifiers == ["com.a"])
    }

    @Test func notifiesOnRealChangesOnly() {
        let apps = IgnoredApps()
        var notifications: [Set<String>] = []
        apps.onChange = { notifications.append($0) }

        apps.add("com.a")
        apps.add("com.a")          // no change
        apps.remove("com.zzz")     // no change
        apps.remove("com.a")
        #expect(notifications == [["com.a"], []])
    }

    @Test func sortedIdentifiersAreAlphabetical() {
        let apps = IgnoredApps()
        apps.add("com.zeta")
        apps.add("com.alpha")
        #expect(apps.sortedIdentifiers == ["com.alpha", "com.zeta"])
    }
}
