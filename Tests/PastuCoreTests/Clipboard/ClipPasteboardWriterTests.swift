import Foundation
import Testing
@testable import PastuCore

@MainActor
private final class RecordingSource: ClipboardSource {
    var changeCount = 0
    var text: String?
    var image: Data?
    var rtf: Data?
    var html: Data?
    var files: [URL]?

    func snapshot(includingContent: Bool) -> PasteboardSnapshot {
        PasteboardSnapshot(types: [], text: includingContent ? text : nil, imagePNG: includingContent ? image : nil)
    }
    func write(text: String, rtf: Data?, html: Data?) {
        self.text = text; self.rtf = rtf; self.html = html; image = nil; changeCount += 1
    }
    func write(imagePNG: Data) { image = imagePNG; text = nil; rtf = nil; html = nil; files = nil; changeCount += 1 }
    func write(files: [URL]) { self.files = files; text = nil; image = nil; rtf = nil; html = nil; changeCount += 1 }
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

    // MARK: Formatting

    private func formattedClip(_ store: ClipStore) throws -> StoredClip {
        let id = try store.insert(CapturedClip(
            text: "hello", sourceBundleIdentifier: nil, date: Date(), rtf: Data("rtf".utf8), html: Data("html".utf8)
        ))
        return try #require(try store.recent().first { $0.id == id })
    }

    @Test func formattingIsLeftOutByDefault() throws {
        let (store, source, monitor, _) = try setUp()
        #expect(ClipPasteboardWriter.copy(try formattedClip(store), from: store, using: monitor) == true)
        #expect(source.text == "hello")
        #expect(source.rtf == nil)
        #expect(source.html == nil)
    }

    @Test func formattingIsWrittenAlongsideTheTextWhenAsked() throws {
        let (store, source, monitor, _) = try setUp()
        let clip = try formattedClip(store)
        #expect(ClipPasteboardWriter.copy(clip, from: store, using: monitor, keepFormatting: true) == true)
        #expect(source.text == "hello")
        #expect(source.rtf == Data("rtf".utf8))
        #expect(source.html == Data("html".utf8))
    }

    @Test func keepingFormattingOfAPlainClipJustWritesText() throws {
        let (store, source, monitor, _) = try setUp()
        let id = try store.insert(CapturedClip(text: "plain", sourceBundleIdentifier: nil, date: Date()))
        let clip = try #require(try store.recent().first { $0.id == id })
        #expect(ClipPasteboardWriter.copy(clip, from: store, using: monitor, keepFormatting: true) == true)
        #expect(source.text == "plain")
        #expect(source.rtf == nil)
    }

    @Test func aFormattedWriteIsNeverRecaptured() throws {
        let (store, _, monitor, captured) = try setUp()
        ClipPasteboardWriter.copy(try formattedClip(store), from: store, using: monitor, keepFormatting: true)
        monitor.poll()
        #expect(captured() == 0)
    }

    // MARK: Files

    /// Real files in a temporary folder, so "does it still exist" means what it says.
    private func tempFiles(_ names: [String]) throws -> (paths: [String], cleanup: () -> Void) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pastu-files-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let paths = try names.map { name -> String in
            let url = dir.appendingPathComponent(name)
            try Data("x".utf8).write(to: url)
            return url.path
        }
        return (paths, { try? FileManager.default.removeItem(at: dir) })
    }

    private func fileClip(_ store: ClipStore, _ paths: [String]) throws -> StoredClip {
        let id = try store.insert(.files(paths: paths, sourceBundleIdentifier: nil, date: Date()))
        return try #require(try store.recent().first { $0.id == id })
    }

    @Test func fileClipsGoBackOnThePasteboardAsFiles() throws {
        let (store, source, monitor, _) = try setUp()
        let (paths, cleanup) = try tempFiles(["one.txt", "two.txt"])
        defer { cleanup() }
        let clip = try fileClip(store, paths)
        #expect(ClipPasteboardWriter.copy(clip, from: store, using: monitor) == true)
        #expect(source.files?.map(\.path) == paths)
        #expect(source.text == nil)
    }

    @Test func filesThatAreGoneAreLeftOut() throws {
        let (store, source, monitor, _) = try setUp()
        let (paths, cleanup) = try tempFiles(["here.txt"])
        defer { cleanup() }
        let clip = try fileClip(store, paths + ["/no/such/dir/gone.txt"])
        #expect(ClipPasteboardWriter.copy(clip, from: store, using: monitor) == true)
        #expect(source.files?.map(\.path) == paths)
    }

    @Test func ifEveryFileIsGoneNothingIsWritten() throws {
        let (store, source, monitor, _) = try setUp()
        let clip = try fileClip(store, ["/no/such/dir/gone.txt"])
        #expect(ClipPasteboardWriter.copy(clip, from: store, using: monitor) == false)
        #expect(source.files == nil)
        #expect(source.changeCount == 0, "the user's clipboard stays as it was")
    }

    @Test func aFileWriteIsNeverRecaptured() throws {
        let (store, _, monitor, captured) = try setUp()
        let (paths, cleanup) = try tempFiles(["one.txt"])
        defer { cleanup() }
        ClipPasteboardWriter.copy(try fileClip(store, paths), from: store, using: monitor)
        monitor.poll()
        #expect(captured() == 0)
    }
}
