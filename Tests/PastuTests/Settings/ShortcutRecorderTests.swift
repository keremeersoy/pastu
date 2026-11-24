import AppKit
import Testing
@testable import Pastu
@testable import PastuCore

extension ShellTests {
@MainActor
@Suite struct ShortcutRecorderTests {
    private func make(accepts: Bool = true) -> (ShortcutRecorder, HotKeySettings, () -> [Bool]) {
        let hotKeys = HotKeySettings(store: InMemorySettings()) { _ in accepts }
        var suspensions: [Bool] = []
        let recorder = ShortcutRecorder(hotKeys: hotKeys, installMonitor: false) { suspensions.append($0) }
        return (recorder, hotKeys, { suspensions })
    }

    @Test func cocoaModifierFlagsMapToOurModifiers() {
        #expect(HotKeyCombo.Modifiers(cocoa: [.command, .shift]) == [.command, .shift])
        #expect(HotKeyCombo.Modifiers(cocoa: [.option, .control]) == [.option, .control])
        // Caps Lock, Fn and the numeric-pad flag are not part of a shortcut.
        #expect(HotKeyCombo.Modifiers(cocoa: [.command, .capsLock, .function, .numericPad]) == .command)
        #expect(HotKeyCombo.Modifiers(cocoa: []) == [])
    }

    @Test func startingSuspendsTheShortcutAndStoppingResumesIt() {
        let (recorder, _, suspensions) = make()
        recorder.start()
        #expect(recorder.isRecording)
        recorder.stop()
        #expect(!recorder.isRecording)
        #expect(suspensions() == [true, false])
    }

    @Test func aValidKeyPressSetsTheShortcutAndEndsRecording() {
        let (recorder, hotKeys, suspensions) = make()
        recorder.start()
        // ⌥⌘C
        #expect(recorder.handle(keyCode: 8, flags: [.command, .option]))
        #expect(hotKeys.combo == HotKeyCombo(keyCode: 8, modifiers: [.command, .option]))
        #expect(!recorder.isRecording)
        #expect(suspensions() == [true, false])
    }

    @Test func escapeCancelsAndKeepsTheOldShortcut() {
        let (recorder, hotKeys, _) = make()
        recorder.start()
        #expect(recorder.handle(keyCode: 53, flags: []))
        #expect(hotKeys.combo == .default)
        #expect(hotKeys.errorMessage == nil)
        #expect(!recorder.isRecording)
    }

    @Test func anInvalidPressEndsRecordingWithAMessage() {
        let (recorder, hotKeys, _) = make()
        recorder.start()
        // ⌘C alone
        #expect(recorder.handle(keyCode: 8, flags: .command))
        #expect(hotKeys.combo == .default)
        #expect(hotKeys.errorMessage == HotKeyCombo.Problem.collidesWithAppShortcuts.message)
        #expect(!recorder.isRecording)
    }

    @Test func aComboAnotherAppHoldsEndsRecordingWithAMessage() {
        let (recorder, hotKeys, _) = make(accepts: false)
        recorder.start()
        #expect(recorder.handle(keyCode: 8, flags: [.command, .option]))
        #expect(hotKeys.combo == .default)
        #expect(hotKeys.errorMessage != nil)
    }

    @Test func keysAreIgnoredWhenNotRecording() {
        let (recorder, hotKeys, _) = make()
        #expect(!recorder.handle(keyCode: 8, flags: [.command, .option]))
        #expect(hotKeys.combo == .default)
    }

    @Test func startingTwiceSuspendsOnce() {
        let (recorder, _, suspensions) = make()
        recorder.start()
        recorder.start()
        #expect(suspensions() == [true])
    }
}
}
