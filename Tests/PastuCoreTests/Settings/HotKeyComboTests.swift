import Foundation
import Testing
@testable import PastuCore

@Suite struct HotKeyComboTests {
    @Test func theDefaultIsCommandShiftV() {
        #expect(HotKeyCombo.default.keyCode == 9)
        #expect(HotKeyCombo.default.modifiers == [.command, .shift])
        // macOS writes modifiers as ⌃⌥⇧⌘, so the default reads ⇧⌘V, the same as the system menu shows it.
        #expect(HotKeyCombo.default.displayString == "⇧⌘V")
    }

    @Test func displayStringUsesTheMacModifierOrder() {
        let combo = HotKeyCombo(keyCode: 0, modifiers: [.shift, .command, .option, .control])
        #expect(combo.displayString == "⌃⌥⇧⌘A")
    }

    @Test func carbonModifiersMatchCarbonsConstants() {
        #expect(HotKeyCombo.Modifiers.command.carbonValue == 0x100)
        #expect(HotKeyCombo.Modifiers.shift.carbonValue == 0x200)
        #expect(HotKeyCombo.Modifiers.option.carbonValue == 0x800)
        #expect(HotKeyCombo.Modifiers.control.carbonValue == 0x1000)
        #expect(HotKeyCombo.default.carbonModifiers == 0x300)
    }

    @Test func storageRoundTrips() {
        let combo = HotKeyCombo(keyCode: 46, modifiers: [.control, .option])
        #expect(HotKeyCombo(storageValue: combo.storageValue) == combo)
        #expect(HotKeyCombo.default.storageValue == "9:3")
    }

    @Test(arguments: ["", "x", "9", "9:", ":3", "a:3", "9:99", "9:3:1", "-1:3", "9:0"])
    func brokenStorageValuesAreRejected(value: String) {
        #expect(HotKeyCombo(storageValue: value) == nil)
    }

    @Test func letterAndDigitAndFunctionKeysHaveNames() {
        #expect(HotKeyCombo(keyCode: 0, modifiers: .command).keyName == "A")
        #expect(HotKeyCombo(keyCode: 29, modifiers: .command).keyName == "0")
        #expect(HotKeyCombo(keyCode: 49, modifiers: .command).keyName == "Space")
        #expect(HotKeyCombo(keyCode: 122, modifiers: .command).keyName == "F1")
        #expect(HotKeyCombo(keyCode: 111, modifiers: .command).keyName == "F12")
        #expect(HotKeyCombo(keyCode: 53, modifiers: .command).keyName == nil)
    }

    @Test func everyLetterKeyHasADistinctName() {
        let letters = (0..<128).compactMap { HotKeyCombo(keyCode: $0, modifiers: .command).keyName }
            .filter { $0.count == 1 && $0.first!.isLetter }
        #expect(Set(letters).count == 26)
    }

    // MARK: Validation

    @Test func theDefaultIsValid() {
        #expect(HotKeyCombo.default.problem == nil)
    }

    @Test func aKeyNeedsAModifier() {
        #expect(HotKeyCombo(keyCode: 9, modifiers: []).problem == .needsModifier)
        #expect(HotKeyCombo(keyCode: 9, modifiers: .shift).problem == .needsModifier)
    }

    /// ⌘ plus a plain key would swallow that shortcut in every app: ⌘C, ⌘V, ⌘Q…
    @Test func commandAloneWithAPlainKeyIsRefused() {
        #expect(HotKeyCombo(keyCode: 8, modifiers: .command).problem == .collidesWithAppShortcuts)
        #expect(HotKeyCombo(keyCode: 18, modifiers: .command).problem == .collidesWithAppShortcuts)
        #expect(HotKeyCombo(keyCode: 9, modifiers: [.command, .shift]).problem == nil)
        #expect(HotKeyCombo(keyCode: 8, modifiers: [.command, .option]).problem == nil)
        #expect(HotKeyCombo(keyCode: 8, modifiers: .control).problem == nil)
        #expect(HotKeyCombo(keyCode: 8, modifiers: .option).problem == nil)
    }

    @Test func systemShortcutsAreRefused() {
        #expect(HotKeyCombo(keyCode: 49, modifiers: .command).problem == .reservedBySystem)
        #expect(HotKeyCombo(keyCode: 49, modifiers: .control).problem == .reservedBySystem)
        #expect(HotKeyCombo(keyCode: 49, modifiers: [.command, .option]).problem == .reservedBySystem)
        #expect(HotKeyCombo(keyCode: 49, modifiers: [.command, .shift]).problem == nil)
    }

    @Test func keysWithoutANameAreRefused() {
        #expect(HotKeyCombo(keyCode: 53, modifiers: [.command, .shift]).problem == .unsupportedKey)
        #expect(HotKeyCombo(keyCode: 126, modifiers: [.command, .shift]).problem == .unsupportedKey)
    }

    @Test func everyProblemHasAShortMessage() {
        for problem in [HotKeyCombo.Problem.needsModifier, .collidesWithAppShortcuts, .reservedBySystem, .unsupportedKey] {
            #expect(!problem.message.isEmpty)
        }
    }

    // MARK: Menu equivalent

    @Test func menuEquivalentIsTheLowercaseCharacterForLettersDigitsAndSpace() {
        #expect(HotKeyCombo.default.menuKeyEquivalent == "v")
        #expect(HotKeyCombo(keyCode: 29, modifiers: .command).menuKeyEquivalent == "0")
        #expect(HotKeyCombo(keyCode: 49, modifiers: [.command, .shift]).menuKeyEquivalent == " ")
        #expect(HotKeyCombo(keyCode: 122, modifiers: [.command, .shift]).menuKeyEquivalent == nil)
    }
}
