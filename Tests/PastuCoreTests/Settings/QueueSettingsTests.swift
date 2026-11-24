import Foundation
import Testing
@testable import PastuCore

@MainActor
@Suite struct QueueSettingsTests {
    @Test func theDefaultIsANewLine() {
        #expect(QueueSettings(store: InMemorySettings()).separator == .newline)
    }

    @Test func theChoiceSurvivesARelaunchUnderItsKey() {
        let store = InMemorySettings()
        QueueSettings(store: store).separator = .tab
        #expect(store.string(forKey: "queueSeparator") == "tab")
        #expect(QueueSettings(store: store).separator == .tab)
    }

    @Test func anUnknownValueMeansTheDefault() {
        let store = InMemorySettings()
        store.set("comma", forKey: DefaultsKeys.queueSeparator)
        #expect(QueueSettings(store: store).separator == .newline)
    }
}
