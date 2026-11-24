import Foundation
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

    @Test func contentOfSensitiveItemsMustNotBeRead() {
        let filter = PrivacyFilter(ignoredBundleIdentifiers: ["com.example.vault"])
        let concealed = PasteboardSnapshot(types: ["org.nspasteboard.ConcealedType"], text: nil)
        let transient = PasteboardSnapshot(types: ["org.nspasteboard.TransientType"], text: nil)
        let vault = PasteboardSnapshot(types: ["public.utf8-plain-text"], text: nil, sourceBundleIdentifier: "com.example.vault")
        let ordinary = PasteboardSnapshot(types: ["public.utf8-plain-text"], text: nil)
        #expect(filter.shouldReadContent(of: concealed) == false)
        #expect(filter.shouldReadContent(of: transient) == false)
        #expect(filter.shouldReadContent(of: vault) == false)
        #expect(filter.shouldReadContent(of: ordinary) == true)
    }

    @Test func skipsTextLargerThanLimit() {
        let filter = PrivacyFilter(maxTextBytes: 10)
        let exact = PasteboardSnapshot(types: ["public.utf8-plain-text"], text: String(repeating: "a", count: 10))
        let over = PasteboardSnapshot(types: ["public.utf8-plain-text"], text: String(repeating: "a", count: 11))
        #expect(filter.decision(for: exact) == .record)
        #expect(filter.decision(for: over) == .skip(.tooLarge))
    }

    @Test func limitCountsBytesNotCharacters() {
        // "ç" is 2 bytes in UTF-8: 5 of them fit in 10 bytes, 6 do not.
        let filter = PrivacyFilter(maxTextBytes: 10)
        let fits = PasteboardSnapshot(types: ["public.utf8-plain-text"], text: String(repeating: "ç", count: 5))
        let over = PasteboardSnapshot(types: ["public.utf8-plain-text"], text: String(repeating: "ç", count: 6))
        #expect(filter.decision(for: fits) == .record)
        #expect(filter.decision(for: over) == .skip(.tooLarge))
    }

    @Test func defaultFilterHasASizeLimit() {
        let huge = PasteboardSnapshot(
            types: ["public.utf8-plain-text"],
            text: String(repeating: "a", count: PrivacyFilter.defaultMaxTextBytes + 1)
        )
        #expect(PrivacyFilter().decision(for: huge) == .skip(.tooLarge))
    }

    // MARK: Images

    private func imageSnapshot(
        _ bytes: Int = 10, text: String? = nil, types: [String] = ["public.png"], app: String? = nil
    ) -> PasteboardSnapshot {
        PasteboardSnapshot(types: types, text: text, sourceBundleIdentifier: app, imagePNG: Data(repeating: 7, count: bytes))
    }

    @Test func recordsAPictureWhenThereIsNoText() {
        #expect(PrivacyFilter().decision(for: imageSnapshot()) == .record)
    }

    @Test func whitespaceOnlyTextDoesNotHideThePicture() {
        #expect(PrivacyFilter().decision(for: imageSnapshot(text: "  \n ")) == .record)
    }

    @Test func emptyPictureDataIsEmpty() {
        let empty = PasteboardSnapshot(types: ["public.png"], text: nil, imagePNG: Data())
        #expect(PrivacyFilter().decision(for: empty) == .skip(.empty))
    }

    @Test func skipsPicturesLargerThanTheLimit() {
        let filter = PrivacyFilter(maxImageBytes: 100)
        #expect(filter.decision(for: imageSnapshot(100)) == .record)
        #expect(filter.decision(for: imageSnapshot(101)) == .skip(.tooLarge))
    }

    @Test func defaultFilterHasAPictureSizeLimit() {
        let huge = imageSnapshot(PrivacyFilter.defaultMaxImageBytes + 1)
        #expect(PrivacyFilter().decision(for: huge) == .skip(.tooLarge))
    }

    @Test func picturesFollowThePrivacyRulesToo() {
        let filter = PrivacyFilter(ignoredBundleIdentifiers: ["com.example.vault"])
        let concealed = imageSnapshot(types: ["public.png", "org.nspasteboard.ConcealedType"])
        let transient = imageSnapshot(types: ["public.png", "org.nspasteboard.TransientType"])
        let vault = imageSnapshot(app: "com.example.vault")
        #expect(filter.decision(for: concealed) == .skip(.concealed))
        #expect(filter.decision(for: transient) == .skip(.transient))
        #expect(filter.decision(for: vault) == .skip(.ignoredApp))
        #expect(filter.shouldReadContent(of: concealed) == false)
    }
}
