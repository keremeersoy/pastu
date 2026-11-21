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

    func snapshot() -> PasteboardSnapshot { current }
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
}
