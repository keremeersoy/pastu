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
}
