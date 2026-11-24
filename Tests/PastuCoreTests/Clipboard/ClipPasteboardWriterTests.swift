import Foundation
import Testing
@testable import PastuCore

@MainActor
private final class RecordingSource: ClipboardSource {
    var changeCount = 0
    var text: String?
    var image: Data?

    func snapshot(includingContent: Bool) -> PasteboardSnapshot {
        PasteboardSnapshot(types: [], text: includingContent ? text : nil, imagePNG: includingContent ? image : nil)
    }
    func write(text: String) { self.text = text; image = nil; changeCount += 1 }
    func write(imagePNG: Data) { image = imagePNG; text = nil; changeCount += 1 }
}

@MainActor
@Suite struct ClipPasteboardWriterTests {
    private func setUp() throws -> (ClipStore, RecordingSource, ClipboardMonitor, captured: () -> Int) {
        let store = try ClipStore()
        let source = RecordingSource()
        var count = 0
        let monitor = ClipboardMonitor(source: source, filter: PrivacyFilter()) { _ in count += 1 }
        return (store, source, monitor, { count })
    }

    @Test func aTextClipIsWrittenAsText() throws {
        let (store, source, monitor, _) = try setUp()
        let id = try store.insert(CapturedClip(text: "hello", sourceBundleIdentifier: nil, date: Date()))
        let clip = try #require(try store.recent().first { $0.id == id })

        #expect(ClipPasteboardWriter.copy(clip, from: store, using: monitor) == true)
        #expect(source.text == "hello")
        #expect(source.image == nil)
    }

    @Test func aPictureClipIsWrittenAsItsBytes() throws {
        let (store, source, monitor, _) = try setUp()
        let bytes = Data(repeating: 4, count: 64)
        let id = try store.insert(.image(png: bytes))
        let clip = try #require(try store.recent().first { $0.id == id })

        #expect(ClipPasteboardWriter.copy(clip, from: store, using: monitor) == true)
        #expect(source.image == bytes)
        #expect(source.text == nil)
    }

    @Test func aPictureWhoseBytesAreGoneWritesNothing() throws {
        let (store, source, monitor, _) = try setUp()
        let id = try store.insert(.image(png: Data(repeating: 1, count: 10)))
        let clip = try #require(try store.recent().first { $0.id == id })
        try store.delete(id: id)

        #expect(ClipPasteboardWriter.copy(clip, from: store, using: monitor) == false)
        #expect(source.image == nil)
        #expect(source.text == nil)
        #expect(source.changeCount == 0)
    }

    @Test func ourOwnWritesAreNeverRecaptured() throws {
        let (store, _, monitor, captured) = try setUp()
        let textID = try store.insert(CapturedClip(text: "hello", sourceBundleIdentifier: nil, date: Date()))
        let pictureID = try store.insert(.image(png: Data(repeating: 4, count: 64)))
        for clip in try store.recent() where clip.id == textID || clip.id == pictureID {
            ClipPasteboardWriter.copy(clip, from: store, using: monitor)
            monitor.poll()
        }
        #expect(captured() == 0)
    }
}
