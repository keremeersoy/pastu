import Foundation
import Testing
@testable import PastuCore

@MainActor
private final class FakeSource: ClipboardSource {
    var changeCount = 0
    var current = PasteboardSnapshot(types: [], text: nil)

    func copy(_ snapshot: PasteboardSnapshot) {
        current = snapshot
        changeCount += 1
    }

    private(set) var textReads = 0

    func snapshot(includingText: Bool) -> PasteboardSnapshot {
        var result = current
        if includingText { textReads += 1 } else { result.text = nil }
        return result
    }

    func write(text: String) {
        copy(PasteboardSnapshot(types: ["public.utf8-plain-text"], text: text))
    }
}

@MainActor
@Suite struct ClipboardMonitorTests {
    private func plain(_ text: String) -> PasteboardSnapshot {
        PasteboardSnapshot(types: ["public.utf8-plain-text"], text: text)
    }

    @Test func emitsNewCopy() {
        let source = FakeSource()
        var received: [String] = []
        let monitor = ClipboardMonitor(source: source, filter: PrivacyFilter()) { received.append($0.text) }

        source.copy(plain("one"))
        monitor.poll()
        #expect(received == ["one"])
    }

    @Test func ignoresUnchangedPasteboard() {
        let source = FakeSource()
        var received: [String] = []
        let monitor = ClipboardMonitor(source: source, filter: PrivacyFilter()) { received.append($0.text) }

        source.copy(plain("one"))
        monitor.poll()
        monitor.poll()
        #expect(received == ["one"])
    }

    @Test func doesNotEmitConcealedCopies() {
        let source = FakeSource()
        var received: [String] = []
        let monitor = ClipboardMonitor(source: source, filter: PrivacyFilter()) { received.append($0.text) }

        source.copy(PasteboardSnapshot(
            types: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"],
            text: "hunter2"
        ))
        monitor.poll()
        #expect(received.isEmpty)
    }

    @Test func startupContentIsNotCaptured() {
        // Whatever is on the clipboard when Pastu launches predates the user's intent to record it.
        let source = FakeSource()
        source.copy(plain("already there"))
        var received: [String] = []
        let monitor = ClipboardMonitor(source: source, filter: PrivacyFilter()) { received.append($0.text) }

        monitor.poll()
        #expect(received.isEmpty)
    }

    @Test func copyToPasteboardWritesTheText() {
        let source = FakeSource()
        let monitor = ClipboardMonitor(source: source, filter: PrivacyFilter()) { _ in }

        monitor.copyToPasteboard("picked from panel")
        #expect(source.snapshot(includingText: true).text == "picked from panel")
    }

    @Test func ownWriteIsNotCapturedAgain() {
        let source = FakeSource()
        var received: [String] = []
        let monitor = ClipboardMonitor(source: source, filter: PrivacyFilter()) { received.append($0.text) }

        monitor.copyToPasteboard("picked from panel")
        monitor.poll()
        #expect(received.isEmpty)
    }

    @Test func copyAfterOwnWriteIsStillCaptured() {
        let source = FakeSource()
        var received: [String] = []
        let monitor = ClipboardMonitor(source: source, filter: PrivacyFilter()) { received.append($0.text) }

        monitor.copyToPasteboard("picked from panel")
        monitor.poll()
        source.copy(plain("user copied this"))
        monitor.poll()
        #expect(received == ["user copied this"])
    }

    @Test func concealedContentIsNeverRead() {
        let source = FakeSource()
        let monitor = ClipboardMonitor(source: source, filter: PrivacyFilter()) { _ in }

        source.copy(PasteboardSnapshot(
            types: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"],
            text: "hunter2"
        ))
        monitor.poll()
        #expect(source.textReads == 0)
    }

    @Test func contentFromIgnoredAppIsNeverRead() {
        let source = FakeSource()
        let monitor = ClipboardMonitor(
            source: source,
            filter: PrivacyFilter(ignoredBundleIdentifiers: ["com.example.vault"])
        ) { _ in }

        source.copy(PasteboardSnapshot(
            types: ["public.utf8-plain-text"], text: "secret",
            sourceBundleIdentifier: "com.example.vault"
        ))
        monitor.poll()
        #expect(source.textReads == 0)
    }

    @Test func ordinaryContentIsReadExactlyOnce() {
        let source = FakeSource()
        let monitor = ClipboardMonitor(source: source, filter: PrivacyFilter()) { _ in }

        source.copy(plain("hello"))
        monitor.poll()
        #expect(source.textReads == 1)
    }

    /// While a menu is open the run loop is in event-tracking mode; a default-mode timer would stop firing
    /// and copies made at that moment would be missed.
    @Test func keepsPollingWhileTheRunLoopTracksEvents() {
        let source = FakeSource()
        var received: [String] = []
        let monitor = ClipboardMonitor(source: source, filter: PrivacyFilter()) { received.append($0.text) }
        monitor.start(interval: 0.01)
        defer { monitor.stop() }

        source.copy(plain("while menu open"))
        // AppKit marks event-tracking as a common mode; without NSApplication in tests, do the same for a stand-in mode.
        let trackingMode = CFRunLoopMode("pastu.test.tracking" as CFString)
        CFRunLoopAddCommonMode(CFRunLoopGetMain(), trackingMode)
        RunLoop.current.run(mode: RunLoop.Mode("pastu.test.tracking"), before: Date().addingTimeInterval(0.3))
        #expect(received == ["while menu open"])
    }
}
