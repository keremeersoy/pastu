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
    private(set) var snapshotCalls = 0

    func snapshot(includingContent: Bool) -> PasteboardSnapshot {
        snapshotCalls += 1
        var result = current
        if includingContent { textReads += 1 } else { result.text = nil; result.imagePNG = nil }
        return result
    }

    func write(imagePNG: Data) {
        copy(PasteboardSnapshot(types: ["public.png"], text: nil, imagePNG: imagePNG))
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
        #expect(source.snapshot(includingContent: true).text == "picked from panel")
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

    // MARK: Pictures

    private func picture(_ seed: UInt8 = 1, bytes: Int = 100, text: String? = nil, app: String? = nil,
                         types: [String] = ["public.png"]) -> PasteboardSnapshot {
        PasteboardSnapshot(types: types, text: text, sourceBundleIdentifier: app, imagePNG: Data(repeating: seed, count: bytes))
    }

    @Test func capturesAPictureCopy() {
        let source = FakeSource()
        var received: [CapturedClip] = []
        let monitor = ClipboardMonitor(source: source, filter: PrivacyFilter()) { received.append($0) }

        source.copy(picture(5, app: "com.apple.screencaptureui"))
        monitor.poll()
        #expect(received.count == 1)
        #expect(received.first?.imagePNG == Data(repeating: 5, count: 100))
        #expect(received.first?.text.hasPrefix("[image] ") == true)
        #expect(received.first?.sourceBundleIdentifier == "com.apple.screencaptureui")
    }

    @Test func textWinsWhenTheCopyHasBothTextAndAPicture() {
        let source = FakeSource()
        var received: [CapturedClip] = []
        let monitor = ClipboardMonitor(source: source, filter: PrivacyFilter()) { received.append($0) }

        source.copy(picture(text: "Figure 3: results", types: ["public.png", "public.utf8-plain-text"]))
        monitor.poll()
        #expect(received.count == 1)
        #expect(received.first?.text == "Figure 3: results")
        #expect(received.first?.imagePNG == nil)
    }

    @Test func aConcealedPictureIsNeverRead() {
        let source = FakeSource()
        var received: [CapturedClip] = []
        let monitor = ClipboardMonitor(source: source, filter: PrivacyFilter()) { received.append($0) }

        source.copy(picture(types: ["public.png", "org.nspasteboard.ConcealedType"]))
        monitor.poll()
        #expect(received.isEmpty)
        #expect(source.textReads == 0)
    }

    @Test func aPictureFromAnIgnoredAppIsNeverRead() {
        let source = FakeSource()
        var received: [CapturedClip] = []
        let monitor = ClipboardMonitor(
            source: source, filter: PrivacyFilter(ignoredBundleIdentifiers: ["com.example.vault"])
        ) { received.append($0) }

        source.copy(picture(app: "com.example.vault"))
        monitor.poll()
        #expect(received.isEmpty)
        #expect(source.textReads == 0)
    }

    @Test func anOversizedPictureIsNotCaptured() {
        let source = FakeSource()
        var received: [CapturedClip] = []
        let monitor = ClipboardMonitor(source: source, filter: PrivacyFilter(maxImageBytes: 50)) { received.append($0) }

        source.copy(picture(bytes: 51))
        monitor.poll()
        #expect(received.isEmpty)
    }

    @Test func copyingAPictureToThePasteboardWritesItAndIsNotRecaptured() {
        let source = FakeSource()
        var received: [CapturedClip] = []
        let monitor = ClipboardMonitor(source: source, filter: PrivacyFilter()) { received.append($0) }
        let data = Data(repeating: 9, count: 100)

        monitor.copyToPasteboard(imagePNG: data)
        #expect(source.snapshot(includingContent: true).imagePNG == data)
        monitor.poll()
        #expect(received.isEmpty)

        source.copy(picture(3))
        monitor.poll()
        #expect(received.count == 1)   // a later, real copy is still captured
    }

    // MARK: Ignored apps at runtime

    @Test func ignoringAnAppLaterAppliesToTheNextCopies() {
        let source = FakeSource()
        var received: [String] = []
        let monitor = ClipboardMonitor(source: source, filter: PrivacyFilter()) { received.append($0.text) }
        let vault = "com.example.vault"

        source.copy(PasteboardSnapshot(types: ["public.utf8-plain-text"], text: "before", sourceBundleIdentifier: vault))
        monitor.poll()
        #expect(received == ["before"])

        monitor.filter.ignoredBundleIdentifiers.insert(vault)
        let readsBefore = source.textReads
        source.copy(PasteboardSnapshot(types: ["public.utf8-plain-text"], text: "after", sourceBundleIdentifier: vault))
        monitor.poll()
        #expect(received == ["before"])
        #expect(source.textReads == readsBefore)   // the content of the ignored app was never read
    }

    // MARK: Pause

    @Test func copiesMadeWhilePausedAreNeitherCapturedNorRead() {
        let source = FakeSource()
        let recording = RecordingState()
        var received: [String] = []
        let monitor = ClipboardMonitor(source: source, filter: PrivacyFilter(), recording: recording) { received.append($0.text) }

        recording.isPaused = true
        source.copy(plain("secret while paused"))
        monitor.poll()
        #expect(received.isEmpty)
        #expect(source.snapshotCalls == 0) // not even metadata was looked at
        #expect(source.textReads == 0)
    }

    @Test func copyMadeWhilePausedIsNotCapturedAfterResume() {
        let source = FakeSource()
        let recording = RecordingState()
        var received: [String] = []
        let monitor = ClipboardMonitor(source: source, filter: PrivacyFilter(), recording: recording) { received.append($0.text) }

        recording.isPaused = true
        source.copy(plain("during pause"))
        monitor.poll()
        recording.isPaused = false
        monitor.poll()
        #expect(received.isEmpty)

        source.copy(plain("after resume"))
        monitor.poll()
        #expect(received == ["after resume"])
    }

    @Test func pausingTakesEffectImmediatelyBetweenPolls() {
        let source = FakeSource()
        let recording = RecordingState()
        var received: [String] = []
        let monitor = ClipboardMonitor(source: source, filter: PrivacyFilter(), recording: recording) { received.append($0.text) }

        source.copy(plain("copied just before pausing"))
        recording.isPaused = true
        monitor.poll()
        #expect(received.isEmpty)
    }

    @Test func ownWritesWhilePausedStillAdvanceTheChangeCount() {
        let source = FakeSource()
        let recording = RecordingState()
        var received: [String] = []
        let monitor = ClipboardMonitor(source: source, filter: PrivacyFilter(), recording: recording) { received.append($0.text) }

        recording.isPaused = true
        monitor.copyToPasteboard("pasted from panel")
        recording.isPaused = false
        monitor.poll()
        #expect(received.isEmpty)
    }
}

@MainActor
@Suite struct RecordingStateTests {
    private func defaults() -> UserDefaults {
        let name = "pastu.tests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test func startsRecording() {
        #expect(RecordingState().isPaused == false)
        #expect(RecordingState(defaults: defaults()).isPaused == false)
    }

    @Test func pausedFlagSurvivesRelaunch() {
        let d = defaults()
        RecordingState(defaults: d).isPaused = true
        #expect(RecordingState(defaults: d).isPaused == true)
        RecordingState(defaults: d).isPaused = false
        #expect(RecordingState(defaults: d).isPaused == false)
    }

    @Test func togglesBetweenStates() {
        let state = RecordingState()
        state.toggle()
        #expect(state.isPaused)
        state.toggle()
        #expect(!state.isPaused)
    }
}
