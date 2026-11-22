import AppKit
import Testing
@testable import Pastu
@testable import PastuCore

@MainActor
@Suite struct PasteCoordinatorTests {
    /// "Copy" in the row menu: the clip goes on the clipboard and moves up the history, but no ⌘V is sent
    /// (and so no Accessibility prompt is needed).
    @Test func copyPutsTheClipOnThePasteboardWithoutSendingCommandV() throws {
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
        #expect(pastes == 0)
    }
}
