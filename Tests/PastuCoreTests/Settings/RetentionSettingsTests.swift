import Foundation
import Observation
import Testing
@testable import PastuCore

@MainActor
@Suite struct RetentionSettingsTests {
    private let day: TimeInterval = 24 * 3600

    @Test func defaultsMatchTheBuiltInPolicy() {
        #expect(RetentionSettings(store: InMemorySettings()).policy == RetentionPolicy())
    }

    @Test func eachChoiceMapsToItsPolicyValue() {
        let settings = RetentionSettings()
        settings.count = .limited(1_000)
        settings.age = .limited(30)
        settings.size = .limited(500)
        #expect(settings.policy == RetentionPolicy(maxCount: 1_000, maxAge: 30 * day, maxTotalBytes: 500 * 1024 * 1024))
    }

    @Test func unlimitedMeansNoLimit() {
        let settings = RetentionSettings()
        settings.count = .unlimited
        settings.age = .unlimited
        settings.size = .unlimited
        #expect(settings.policy == RetentionPolicy(maxCount: nil, maxAge: nil, maxTotalBytes: nil))
    }

    @Test func choicesSurviveARelaunch() {
        let store = InMemorySettings()
        let first = RetentionSettings(store: store)
        first.count = .limited(500)
        first.age = .unlimited
        first.size = .limited(1_024)
        let second = RetentionSettings(store: store)
        #expect(second.count == .limited(500))
        #expect(second.age == .unlimited)
        #expect(second.size == .limited(1_024))
    }

    @Test func choicesAreStoredUnderTheirKeys() {
        let store = InMemorySettings()
        let settings = RetentionSettings(store: store)
        settings.count = .limited(500)
        settings.age = .unlimited
        settings.size = .limited(50)
        #expect(store.string(forKey: "retentionCount") == "500")
        #expect(store.string(forKey: "retentionAgeDays") == "unlimited")
        #expect(store.string(forKey: "retentionSizeMB") == "50")
    }

    /// A value that is not one of the offered choices (a hand-edited plist, an older version) means the default,
    /// never "no limit" and never a tiny limit that would wipe the history.
    @Test(arguments: ["", "abc", "0", "-5", "7.5", "123456", "Unlimited "])
    func valuesThatAreNotChoicesFallBackToTheDefault(value: String) {
        let store = InMemorySettings()
        store.set(value, forKey: DefaultsKeys.retentionCount)
        store.set(value, forKey: DefaultsKeys.retentionAgeDays)
        store.set(value, forKey: DefaultsKeys.retentionSizeMB)
        #expect(RetentionSettings(store: store).policy == RetentionPolicy())
    }

    @Test func theDefaultsAreAmongTheChoices() {
        #expect(RetentionSettings.countChoices.contains(.limited(5_000)))
        #expect(RetentionSettings.ageChoices.contains(.limited(90)))
        #expect(RetentionSettings.sizeChoices.contains(.limited(200)))
    }

    @Test func everyListEndsWithUnlimited() {
        #expect(RetentionSettings.countChoices.last == .unlimited)
        #expect(RetentionSettings.ageChoices.last == .unlimited)
        #expect(RetentionSettings.sizeChoices.last == .unlimited)
    }

    @Test func titlesAreReadable() {
        #expect(RetentionSettings.countTitle(.limited(5_000)) == "5,000 clips")
        #expect(RetentionSettings.countTitle(.unlimited) == "No limit")
        #expect(RetentionSettings.ageTitle(.limited(7)) == "1 week")
        #expect(RetentionSettings.ageTitle(.limited(30)) == "30 days")
        #expect(RetentionSettings.ageTitle(.limited(365)) == "1 year")
        #expect(RetentionSettings.ageTitle(.unlimited) == "Forever")
        #expect(RetentionSettings.sizeTitle(.limited(200)) == "200 MB")
        #expect(RetentionSettings.sizeTitle(.limited(1_024)) == "1 GB")
        #expect(RetentionSettings.sizeTitle(.unlimited) == "No limit")
    }

    @Test func choicesAreObservable() {
        let settings = RetentionSettings()
        let changes = ChangeCounter()
        withObservationTracking { _ = settings.count } onChange: { changes.count += 1 }
        settings.count = .limited(500)
        #expect(changes.count == 1)
    }
}
