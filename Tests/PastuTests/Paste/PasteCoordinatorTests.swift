import AppKit
import Testing
@testable import Pastu
@testable import PastuCore

@MainActor
@Suite struct PasteCoordinatorTests {
    /// "Copy" in the row menu: the clip goes on the clipboard and moves up the history, but no ⌘V is sent
    /// (and so no Accessibility prompt is needed).
    @Test func copyPutsTheClipOnThePasteboardWithoutSendingCommandV() async throws {
        // A private pasteboard: this test never touches the user's clipboard.
        let raw = NSPasteboard(name: .init("pastu.test.\(UUID())"))
        defer { raw.releaseGlobally() }
        let store = try ClipStore()
        let old = Date(timeIntervalSince1970: 1)
        let id = try store.insert(CapturedClip(text: "copied by mouse", sourceBundleIdentifier: nil, date: old))
        let clip = try #require(try store.recent().first { $0.id == id })

        var pastes = 0
        let coordinator = PasteCoordinator(sendPaste: { pastes += 1 })
        coordinator.store = store
        coordinator.monitor = ClipboardMonitor(source: SystemPasteboard(pasteboard: raw), filter: PrivacyFilter()) { _ in }

        coordinator.copy(clip)

        #expect(raw.string(forType: .string) == "copied by mouse")
        let updated = try #require(try store.recent().first { $0.id == id })
        #expect(updated.lastCopiedAt > old)
        // `paste` sends ⌘V 80 ms later; wait past that so a delayed send from `copy` would be caught too.
        try? await Task.sleep(for: .milliseconds(150))
        #expect(pastes == 0)
    }

    /// If Pastu is the active app (its alert or About window had focus), ⌘V would go to Pastu: step aside first.
    @Test(arguments: [true, false])
    func pasteHidesPastuFirstOnlyWhenItIsActive(isActive: Bool) async throws {
        let raw = NSPasteboard(name: .init("pastu.test.\(UUID())"))
        defer { raw.releaseGlobally() }
        let store = try ClipStore()
        try store.insert(CapturedClip(text: "clip", sourceBundleIdentifier: nil, date: Date()))
        let clip = try #require(try store.recent().first)

        var events: [String] = []
        let coordinator = PasteCoordinator(
            sendPaste: { events.append("paste") },
            isTrusted: { true },
            isPastuActive: { isActive },
            hidePastu: { events.append("hide") }
        )
        coordinator.store = store
        coordinator.monitor = ClipboardMonitor(source: SystemPasteboard(pasteboard: raw), filter: PrivacyFilter()) { _ in }

        coordinator.paste(clip)
        #expect(events == (isActive ? ["hide"] : []))
        for _ in 0..<50 where !events.contains("paste") { try? await Task.sleep(for: .milliseconds(20)) }
        #expect(events == (isActive ? ["hide", "paste"] : ["paste"]))
    }

    // MARK: Paste queue

    private struct Rig {
        let coordinator: PasteCoordinator
        let raw: NSPasteboard
        let store: ClipStore
        let events: () -> [String]
    }

    /// Records, at every ⌘V, what the private pasteboard holds, which is what the target app would paste.
    private func makeRig(trusted: Bool = true, active: Bool = false) throws -> Rig {
        let raw = NSPasteboard(name: .init("pastu.test.\(UUID())"))
        let store = try ClipStore()
        var events: [String] = []
        let coordinator = PasteCoordinator(
            sendPaste: {
                if let png = raw.data(forType: .png) { events.append("image:\(png.count)") }
                else { events.append(raw.string(forType: .string) ?? "<empty>") }
            },
            isTrusted: { trusted },
            isPastuActive: { active },
            hidePastu: { events.append("hide") }
        )
        coordinator.store = store
        coordinator.monitor = ClipboardMonitor(source: SystemPasteboard(pasteboard: raw), filter: PrivacyFilter()) { _ in }
        return Rig(coordinator: coordinator, raw: raw, store: store, events: { events })
    }

    private func steps(_ rig: Rig, _ texts: [String], separator: QueueSeparator) throws -> [(clip: StoredClip, suffix: String)] {
        let queue = PasteQueue()
        for (i, text) in texts.enumerated() {
            try rig.store.insert(CapturedClip(text: text, sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: Double(i + 1))))
        }
        try rig.store.recent().sorted { $0.lastCopiedAt < $1.lastCopiedAt }.forEach { _ = queue.add($0) }
        return queue.plan(separator: separator)
    }

    @Test func theQueueIsPastedOneClipAtATimeInOrder() async throws {
        let rig = try makeRig()
        defer { rig.raw.releaseGlobally() }
        await rig.coordinator.pasteQueue(try steps(rig, ["a", "b", "c"], separator: .newline), startDelay: .zero, stepDelay: .zero)
        #expect(rig.events() == ["a\n", "b\n", "c"])
    }

    @Test func aPictureInTheQueueIsPastedAsAPicture() async throws {
        let rig = try makeRig()
        defer { rig.raw.releaseGlobally() }
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")!
        try rig.store.insert(.image(png: png, sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 1)))
        try rig.store.insert(CapturedClip(text: "after", sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 2)))
        let queue = PasteQueue()
        try rig.store.recent().sorted { $0.lastCopiedAt < $1.lastCopiedAt }.forEach { _ = queue.add($0) }
        await rig.coordinator.pasteQueue(queue.plan(separator: .space), startDelay: .zero, stepDelay: .zero)
        #expect(rig.events() == ["image:\(png.count)", "after"])
    }

    @Test func withoutPermissionTheQueueIsCopiedAsOneTextAndNothingIsPasted() async throws {
        let rig = try makeRig(trusted: false)
        defer { rig.raw.releaseGlobally() }
        await rig.coordinator.pasteQueue(try steps(rig, ["a", "b"], separator: .newline), startDelay: .zero, stepDelay: .zero)
        #expect(rig.events().isEmpty)
        #expect(rig.raw.string(forType: .string) == "a\nb")
    }

    @Test func pastuStepsAsideFirstWhenItIsActive() async throws {
        let rig = try makeRig(active: true)
        defer { rig.raw.releaseGlobally() }
        await rig.coordinator.pasteQueue(try steps(rig, ["a"], separator: .none), startDelay: .zero, stepDelay: .zero)
        #expect(rig.events() == ["hide", "a"])
    }

    @Test func anEmptyQueuePastesNothing() async throws {
        let rig = try makeRig()
        defer { rig.raw.releaseGlobally() }
        await rig.coordinator.pasteQueue([], startDelay: .zero, stepDelay: .zero)
        #expect(rig.events().isEmpty)
    }

    /// The pasted clips move to the top of the history in the order they were pasted, like single pastes do.
    @Test func pastingTheQueueMarksEachClipUsed() async throws {
        let rig = try makeRig()
        defer { rig.raw.releaseGlobally() }
        let plan = try steps(rig, ["a", "b"], separator: .none)
        await rig.coordinator.pasteQueue(plan, startDelay: .zero, stepDelay: .zero)
        #expect(try rig.store.recent().map(\.text) == ["b", "a"])
    }

    // MARK: Formatting

    @Test func pastingWithFormattingPutsTheStoredFormattingOnThePasteboard() async throws {
        let raw = NSPasteboard(name: .init("pastu.test.\(UUID())"))
        defer { raw.releaseGlobally() }
        let store = try ClipStore()
        let rtf = Data("{\\rtf1 hi}".utf8), html = Data("<b>hi</b>".utf8)
        let id = try store.insert(CapturedClip(text: "styled", sourceBundleIdentifier: nil, date: Date(), rtf: rtf, html: html))
        let clip = try #require(try store.recent().first { $0.id == id })
        let coordinator = PasteCoordinator(sendPaste: {}, isTrusted: { true }, isPastuActive: { false }, hidePastu: {})
        coordinator.store = store
        coordinator.monitor = ClipboardMonitor(source: SystemPasteboard(pasteboard: raw), filter: PrivacyFilter()) { _ in }

        coordinator.copy(clip, keepFormatting: true)
        #expect(raw.string(forType: .string) == "styled")
        #expect(raw.data(forType: .rtf) == rtf)
        #expect(raw.data(forType: .html) == html)
    }

    @Test func aPlainPasteLeavesTheFormattingBehind() async throws {
        let raw = NSPasteboard(name: .init("pastu.test.\(UUID())"))
        defer { raw.releaseGlobally() }
        let store = try ClipStore()
        let id = try store.insert(CapturedClip(text: "styled", sourceBundleIdentifier: nil, date: Date(), rtf: Data("{\\rtf1 hi}".utf8)))
        let clip = try #require(try store.recent().first { $0.id == id })
        let coordinator = PasteCoordinator(sendPaste: {}, isTrusted: { true }, isPastuActive: { false }, hidePastu: {})
        coordinator.store = store
        coordinator.monitor = ClipboardMonitor(source: SystemPasteboard(pasteboard: raw), filter: PrivacyFilter()) { _ in }

        coordinator.copy(clip)
        #expect(raw.string(forType: .string) == "styled")
        #expect(raw.data(forType: .rtf) == nil)
    }

    @Test func theFormattedPasteSendsCommandVAfterWritingTheFormatting() async throws {
        let raw = NSPasteboard(name: .init("pastu.test.\(UUID())"))
        defer { raw.releaseGlobally() }
        let store = try ClipStore()
        let rtf = Data("{\\rtf1 hi}".utf8)
        let id = try store.insert(CapturedClip(text: "styled", sourceBundleIdentifier: nil, date: Date(), rtf: rtf))
        let clip = try #require(try store.recent().first { $0.id == id })
        var seenAtPaste: Data?
        let coordinator = PasteCoordinator(
            sendPaste: { seenAtPaste = raw.data(forType: .rtf) }, isTrusted: { true }, isPastuActive: { false }, hidePastu: {}
        )
        coordinator.store = store
        coordinator.monitor = ClipboardMonitor(source: SystemPasteboard(pasteboard: raw), filter: PrivacyFilter()) { _ in }

        coordinator.paste(clip, keepFormatting: true)
        for _ in 0..<50 where seenAtPaste == nil { try? await Task.sleep(for: .milliseconds(20)) }
        #expect(seenAtPaste == rtf)
    }
}
