import Foundation
import Testing
@testable import PastuCore

/// The stored key names are part of the on-disk format: renaming one silently drops that setting
/// for everyone who already uses Pastu. These tests pin the exact strings.
@MainActor
@Suite struct DefaultsKeysTests {
    @Test func keyNamesAreStable() {
        #expect(DefaultsKeys.recordingPaused == "recordingPaused")
        #expect(DefaultsKeys.ignoredApps == "ignoredApps")
        #expect(DefaultsKeys.panelAppearance == "panelAppearance")
        #expect(DefaultsKeys.panelMaterial == "panelMaterial")
        #expect(DefaultsKeys.hotKey == "hotKey")
        #expect(DefaultsKeys.onboardingDone == "onboardingDone")
        #expect(DefaultsKeys.retentionCount == "retentionCount")
        #expect(DefaultsKeys.retentionAgeDays == "retentionAgeDays")
        #expect(DefaultsKeys.retentionSizeMB == "retentionSizeMB")
    }

    @Test func pauseIsStoredUnderItsKey() {
        let settings = InMemorySettings()
        RecordingState(store: settings).toggle()
        #expect(settings.bool(forKey: "recordingPaused") == true)
    }

    @Test func ignoredAppsAreStoredUnderTheirKey() {
        let settings = InMemorySettings()
        IgnoredApps(store: settings).add("com.example.vault")
        #expect(settings.stringArray(forKey: "ignoredApps") == ["com.example.vault"])
    }
}
