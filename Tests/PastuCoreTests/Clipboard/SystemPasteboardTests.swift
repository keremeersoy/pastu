import AppKit
import Foundation
import Testing
@testable import PastuCore

@Suite struct PNGConverterTests {
    @Test func pngInputIsReturnedUnchanged() {
        let original = pngData()
        #expect(PNGConverter.png(from: original) == original)
    }

    @Test func tiffIsConvertedToAPNGOfTheSameSize() throws {
        let png = try #require(PNGConverter.png(from: tiffData(8, 5)))
        #expect(png.prefix(8) == pngSignature)
        #expect(size(of: png) == NSSize(width: 8, height: 5))
    }

    @Test func jpegIsConvertedToo() throws {
        let png = try #require(PNGConverter.png(from: jpegData(7, 3)))
        #expect(png.prefix(8) == pngSignature)
        #expect(size(of: png) == NSSize(width: 7, height: 3))
    }

    @Test func garbageAndEmptyDataAreRejected() {
        #expect(PNGConverter.png(from: Data([1, 2, 3, 4])) == nil)
        #expect(PNGConverter.png(from: Data()) == nil)
    }
}

@Suite struct PNGDimensionsTests {
    @Test func readsTheSizeOfARealPNG() {
        let size = PNGConverter.dimensions(of: pngData(8, 5))
        #expect(size?.width == 8)
        #expect(size?.height == 5)
    }

    @Test func readsLargeDimensionsFromTheHeaderAlone() {
        // A header claiming 4096 x 3000 followed by nothing else: the size must come from IHDR, not from decoding.
        var header = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52])
        header.append(contentsOf: [0, 0, 0x10, 0x00, 0, 0, 0x0B, 0xB8])
        let size = PNGConverter.dimensions(of: header)
        #expect(size?.width == 4096)
        #expect(size?.height == 3000)
    }

    @Test func rejectsEverythingThatIsNotAWellFormedPNGHeader() {
        #expect(PNGConverter.dimensions(of: Data()) == nil)
        #expect(PNGConverter.dimensions(of: Data([1, 2, 3, 4])) == nil)
        #expect(PNGConverter.dimensions(of: jpegData()) == nil)
        #expect(PNGConverter.dimensions(of: tiffData()) == nil)
        #expect(PNGConverter.dimensions(of: pngData().prefix(20)) == nil)          // truncated header
        var wrongChunk = Data(pngData().prefix(24))
        wrongChunk.replaceSubrange(12..<16, with: Data([0x58, 0x58, 0x58, 0x58]))   // "XXXX" instead of "IHDR"
        #expect(PNGConverter.dimensions(of: wrongChunk) == nil)
        var wrongSignature = Data(pngData().prefix(24))
        wrongSignature[1] = 0x51                                                    // "Q" instead of "P", the rest is valid
        #expect(PNGConverter.dimensions(of: wrongSignature) == nil)
        var zeroWidth = Data(pngData().prefix(24))
        zeroWidth.replaceSubrange(16..<20, with: Data([0, 0, 0, 0]))
        #expect(PNGConverter.dimensions(of: zeroWidth) == nil)
    }
}

@MainActor
@Suite struct SystemPasteboardTests {
    /// A private pasteboard: these tests never touch the user's clipboard.
    private func makePasteboard() -> (SystemPasteboard, NSPasteboard) {
        let raw = NSPasteboard.withUniqueName()
        return (SystemPasteboard(pasteboard: raw), raw)
    }

    @Test func formattedTextRoundTrips() {
        let (system, raw) = makePasteboard()
        defer { raw.releaseGlobally() }
        let rtf = Data("{\\rtf1 hi}".utf8), html = Data("<b>hi</b>".utf8)

        system.write(text: "hi", rtf: rtf, html: html)
        let snapshot = system.snapshot(includingContent: true)
        #expect(snapshot.text == "hi")
        #expect(snapshot.rtf == rtf)
        #expect(snapshot.html == html)
    }

    @Test func plainWritesCarryNoFormatting() {
        let (system, raw) = makePasteboard()
        defer { raw.releaseGlobally() }
        system.write(text: "hi", rtf: Data("x".utf8), html: nil)
        system.write(text: "plain")
        let snapshot = system.snapshot(includingContent: true)
        #expect(snapshot.rtf == nil)
        #expect(snapshot.html == nil)
    }

    @Test func aMetadataOnlySnapshotDoesNotReadFormatting() {
        let (system, raw) = makePasteboard()
        defer { raw.releaseGlobally() }
        system.write(text: "hi", rtf: Data("x".utf8), html: Data("y".utf8))
        let snapshot = system.snapshot(includingContent: false)
        #expect(snapshot.rtf == nil)
        #expect(snapshot.html == nil)
    }

    @Test func aPictureRoundTrips() {
        let (system, raw) = makePasteboard()
        defer { raw.releaseGlobally() }
        let png = pngData()

        system.write(imagePNG: png)
        let snapshot = system.snapshot(includingContent: true)
        #expect(snapshot.imagePNG == png)
        #expect(snapshot.text == nil)
    }

    /// Not our code, but the app relies on it: apps that only understand TIFF can still paste what we write.
    @Test func aPictureWrittenAsPNGCanBeReadAsTIFFByOtherApps() throws {
        let (system, raw) = makePasteboard()
        defer { raw.releaseGlobally() }

        system.write(imagePNG: pngData(6, 4))
        let tiff = try #require(raw.data(forType: .tiff))
        #expect(size(of: tiff) == NSSize(width: 6, height: 4))
    }

    @Test func aTIFFOnlyPasteboardIsReadAsPNG() throws {
        let (system, raw) = makePasteboard()
        defer { raw.releaseGlobally() }
        raw.clearContents()
        raw.setData(tiffData(9, 2), forType: .tiff)

        let png = try #require(system.snapshot(includingContent: true).imagePNG)
        #expect(png.prefix(8) == pngSignature)
        #expect(size(of: png) == NSSize(width: 9, height: 2))
    }

    @Test func aMetadataOnlySnapshotDoesNotReadThePicture() {
        let (system, raw) = makePasteboard()
        defer { raw.releaseGlobally() }
        system.write(imagePNG: pngData())

        let snapshot = system.snapshot(includingContent: false)
        #expect(snapshot.imagePNG == nil)
        #expect(snapshot.types.contains("public.png"))
    }

    @Test func textWinsAndThePictureIsNotEvenRead() {
        let (system, raw) = makePasteboard()
        defer { raw.releaseGlobally() }
        raw.clearContents()
        raw.setString("Figure 3", forType: .string)
        raw.setData(pngData(), forType: .png)

        let snapshot = system.snapshot(includingContent: true)
        #expect(snapshot.text == "Figure 3")
        #expect(snapshot.imagePNG == nil)
    }

    @Test func undecodablePictureDataIsIgnored() {
        let (system, raw) = makePasteboard()
        defer { raw.releaseGlobally() }
        raw.clearContents()
        raw.setData(Data([1, 2, 3]), forType: .png)

        #expect(system.snapshot(includingContent: true).imagePNG == nil)
    }

    @Test func writingAPictureReplacesEarlierText() {
        let (system, raw) = makePasteboard()
        defer { raw.releaseGlobally() }
        system.write(text: "old text")
        system.write(imagePNG: pngData())

        #expect(system.snapshot(includingContent: true).text == nil)
    }
}
