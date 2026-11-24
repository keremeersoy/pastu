import Foundation
import Testing
@testable import PastuCore

@MainActor
@Suite struct PictureTextSettingsTests {
    @Test func itIsOnByDefault() {
        #expect(PictureTextSettings(store: InMemorySettings()).isEnabled)
    }

    @Test func theChoiceSurvivesARelaunchUnderItsKey() {
        let store = InMemorySettings()
        PictureTextSettings(store: store).isEnabled = false
        #expect(store.bool(forKey: "recognizeTextInPictures") == false)
        #expect(!PictureTextSettings(store: store).isEnabled)
        PictureTextSettings(store: store).isEnabled = true
        #expect(PictureTextSettings(store: store).isEnabled)
    }
}
