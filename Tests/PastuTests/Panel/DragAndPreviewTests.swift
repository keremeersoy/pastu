import AppKit
import Testing
import UniformTypeIdentifiers
@testable import Pastu
@testable import PastuCore

extension ShellTests {
@MainActor
@Suite struct DragAndPreviewTests {
    private func clips() throws -> (text: StoredClip, link: StoredClip, picture: StoredClip, png: Data, loader: (Int64) -> Data?) {
        let store = try ClipStore()
        let png = makePNG(30, 20)
        try store.insert(CapturedClip(text: "hello world", sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 1)))
        try store.insert(CapturedClip(text: "https://example.com/a", sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 2)))
        try store.insert(.image(png: png, sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 3)))
        let all = try store.recent()
        return (
            all.first { $0.text == "hello world" }!, all.first { $0.kind == .link }!, all.first { $0.kind == .image }!,
            png, { (try? store.imageData(id: $0)) ?? nil }
        )
    }

    // MARK: Drag

    @Test func aTextClipIsDraggedAsText() async throws {
        let c = try clips()
        let provider = ClipDragItem.provider(for: c.text, imageData: c.loader)
        #expect(provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier))
        let loaded: String? = await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: NSString.self) { object, _ in continuation.resume(returning: object as? String) }
        }
        #expect(loaded == "hello world")
    }

    @Test func aLinkIsDraggedAsTextToo() {
        let c = try! clips()
        #expect(ClipDragItem.provider(for: c.link, imageData: c.loader).hasItemConformingToTypeIdentifier(UTType.plainText.identifier))
    }

    @Test func aPictureIsDraggedAsAPNGFileWithItsBytes() async throws {
        let c = try clips()
        let provider = ClipDragItem.provider(for: c.picture, imageData: c.loader)
        #expect(provider.hasItemConformingToTypeIdentifier(UTType.png.identifier))
        #expect(!provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier))
        let bytes: Data? = await withCheckedContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: UTType.png.identifier) { url, _ in
                // The file only exists inside this handler.
                continuation.resume(returning: url.flatMap { try? Data(contentsOf: $0) })
            }
        }
        #expect(bytes == c.png)
    }

    @Test func aPictureWithMissingBytesDragsNothingUseful() {
        let c = try! clips()
        let provider = ClipDragItem.provider(for: c.picture, imageData: { _ in nil })
        #expect(provider.registeredTypeIdentifiers.isEmpty)
    }

    // MARK: Open in Preview

    private func makeOpener() -> (PreviewOpener, () -> [URL]) {
        var opened: [URL] = []
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pastu-test-\(UUID())")
        let opener = PreviewOpener(directory: dir) { opened.append($0) }
        return (opener, { opened })
    }

    @Test func openingWritesThePictureToAPrivateFileAndHandsItOver() throws {
        let c = try clips()
        let (opener, opened) = makeOpener()
        defer { opener.cleanUp() }
        #expect(opener.open(c.picture, imageData: c.loader))
        let url = try #require(opened().first)
        #expect(url.pathExtension == "png")
        #expect(try Data(contentsOf: url) == c.png)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        #expect((attributes[.posixPermissions] as? Int) == 0o600)
        let folder = try FileManager.default.attributesOfItem(atPath: url.deletingLastPathComponent().path)
        #expect((folder[.posixPermissions] as? Int) == 0o700)
    }

    @Test func eachOpenGetsItsOwnFile() throws {
        let c = try clips()
        let (opener, opened) = makeOpener()
        defer { opener.cleanUp() }
        _ = opener.open(c.picture, imageData: c.loader)
        _ = opener.open(c.picture, imageData: c.loader)
        #expect(Set(opened()).count == 2)
    }

    @Test func onlyPicturesCanBeOpened() throws {
        let c = try clips()
        let (opener, opened) = makeOpener()
        defer { opener.cleanUp() }
        #expect(!opener.open(c.text, imageData: c.loader))
        #expect(!opener.open(c.link, imageData: c.loader))
        #expect(!opener.open(c.picture, imageData: { _ in nil }))
        #expect(opened().isEmpty)
    }

    /// The files are copies of clips, so they must not pile up: they are removed at launch and on quit.
    @Test func cleaningUpRemovesEveryFile() throws {
        let c = try clips()
        let (opener, opened) = makeOpener()
        _ = opener.open(c.picture, imageData: c.loader)
        let url = try #require(opened().first)
        #expect(FileManager.default.fileExists(atPath: url.path))
        opener.cleanUp()
        #expect(!FileManager.default.fileExists(atPath: url.path))
        opener.cleanUp()   // nothing to remove is fine
    }
}
}
