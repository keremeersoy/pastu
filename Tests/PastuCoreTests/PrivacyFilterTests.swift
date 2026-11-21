import Testing
@testable import PastuCore

@Suite struct PrivacyFilterTests {
    @Test func recordsPlainText() {
        let filter = PrivacyFilter()
        let snapshot = PasteboardSnapshot(types: ["public.utf8-plain-text"], text: "hello")
        #expect(filter.decision(for: snapshot) == .record)
    }

    @Test func skipsConcealedType() {
        let filter = PrivacyFilter()
        let snapshot = PasteboardSnapshot(
            types: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"],
            text: "hunter2"
        )
        #expect(filter.decision(for: snapshot) == .skip(.concealed))
    }

    @Test func skipsTransientType() {
        let filter = PrivacyFilter()
        let snapshot = PasteboardSnapshot(
            types: ["public.utf8-plain-text", "org.nspasteboard.TransientType"],
            text: "123456"
        )
        #expect(filter.decision(for: snapshot) == .skip(.transient))
    }

    @Test func skipsIgnoredApps() {
        let filter = PrivacyFilter(ignoredBundleIdentifiers: ["com.example.vault"])
        let snapshot = PasteboardSnapshot(
            types: ["public.utf8-plain-text"],
            text: "secret",
            sourceBundleIdentifier: "com.example.vault"
        )
        #expect(filter.decision(for: snapshot) == .skip(.ignoredApp))
    }

    @Test func skipsEmptyOrWhitespaceText() {
        let filter = PrivacyFilter()
        let empty = PasteboardSnapshot(types: ["public.utf8-plain-text"], text: "  \n ")
        let none = PasteboardSnapshot(types: ["public.png"], text: nil)
        #expect(filter.decision(for: empty) == .skip(.empty))
        #expect(filter.decision(for: none) == .skip(.empty))
    }
}
