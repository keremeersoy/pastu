import Foundation
import Testing
@testable import PastuCore

@MainActor
@Suite struct HotKeySettingsTests {
    private func make(
        settings: SettingsStore = InMemorySettings(), accepts: Bool = true
    ) -> (HotKeySettings, () -> [HotKeyCombo]) {
        var registered: [HotKeyCombo] = []
        let hotKeys = HotKeySettings(store: settings) { combo in
            registered.append(combo)
            return accepts
        }
        return (hotKeys, { registered })
    }

    @Test func startsWithTheDefault() {
        #expect(make().0.combo == .default)
    }

    @Test func applyRegistersTheCurrentCombo() {
        let (hotKeys, registered) = make()
        hotKeys.apply()
        #expect(registered() == [.default])
        #expect(hotKeys.errorMessage == nil)
    }

    @Test func aNewComboIsRegisteredAndRemembered() {
        let settings = InMemorySettings()
        let (hotKeys, registered) = make(settings: settings)
        let combo = HotKeyCombo(keyCode: 8, modifiers: [.command, .option])
        #expect(hotKeys.set(combo))
        #expect(hotKeys.combo == combo)
        #expect(registered() == [combo])
        #expect(settings.string(forKey: "hotKey") == combo.storageValue)
        #expect(make(settings: settings).0.combo == combo)
    }

    @Test func anInvalidComboIsRefusedWithoutTouchingTheSystem() {
        let (hotKeys, registered) = make()
        #expect(!hotKeys.set(HotKeyCombo(keyCode: 8, modifiers: .command)))
        #expect(hotKeys.combo == .default)
        #expect(registered().isEmpty)
        #expect(hotKeys.errorMessage == HotKeyCombo.Problem.collidesWithAppShortcuts.message)
    }

    @Test func aComboAnotherAppHoldsIsRefusedAndTheOldOneStays() {
        let settings = InMemorySettings()
        var accept = true
        var registered: [HotKeyCombo] = []
        let hotKeys = HotKeySettings(store: settings) { combo in registered.append(combo); return accept }
        accept = false
        let combo = HotKeyCombo(keyCode: 8, modifiers: [.command, .option])
        #expect(!hotKeys.set(combo))
        #expect(hotKeys.combo == .default)
        #expect(settings.string(forKey: "hotKey") == nil)
        #expect(hotKeys.errorMessage == "That shortcut is already used by another app or by macOS.")
        // The previous shortcut is put back, so Pastu never ends up with none.
        #expect(registered == [combo, .default])
    }

    @Test func theMessageGoesAwayAfterTheNextSuccess() {
        let (hotKeys, _) = make()
        _ = hotKeys.set(HotKeyCombo(keyCode: 8, modifiers: .command))
        #expect(hotKeys.errorMessage != nil)
        #expect(hotKeys.set(HotKeyCombo(keyCode: 8, modifiers: [.command, .option])))
        #expect(hotKeys.errorMessage == nil)
    }

    @Test func resetGoesBackToTheDefault() {
        let settings = InMemorySettings()
        let (hotKeys, _) = make(settings: settings)
        _ = hotKeys.set(HotKeyCombo(keyCode: 8, modifiers: [.command, .option]))
        hotKeys.reset()
        #expect(hotKeys.combo == .default)
        #expect(settings.string(forKey: "hotKey") == HotKeyCombo.default.storageValue)
    }

    @Test func aBrokenStoredValueFallsBackToTheDefault() {
        let settings = InMemorySettings()
        settings.set("garbage", forKey: DefaultsKeys.hotKey)
        #expect(make(settings: settings).0.combo == .default)
        // A stored combo that is no longer allowed (⌘C alone) is dropped too.
        settings.set(HotKeyCombo(keyCode: 8, modifiers: .command).storageValue, forKey: DefaultsKeys.hotKey)
        #expect(make(settings: settings).0.combo == .default)
    }

    @Test func aStoredComboTakenAtLaunchIsReportedButKept() {
        let settings = InMemorySettings()
        let combo = HotKeyCombo(keyCode: 8, modifiers: [.command, .option])
        settings.set(combo.storageValue, forKey: DefaultsKeys.hotKey)
        let (hotKeys, _) = make(settings: settings, accepts: false)
        hotKeys.apply()
        #expect(hotKeys.combo == combo)
        #expect(hotKeys.errorMessage != nil)
    }

    @Test func settingTheSameComboAgainDoesNothing() {
        let (hotKeys, registered) = make()
        #expect(hotKeys.set(.default))
        #expect(registered().isEmpty)
    }
}
