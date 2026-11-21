import AppKit
import Foundation
import Testing
@testable import PastuCore

private let pngSignature = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

private func bitmap(_ width: Int, _ height: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.red.setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

private func pngData(_ width: Int = 6, _ height: Int = 4) -> Data { bitmap(width, height).representation(using: .png, properties: [:])! }
private func tiffData(_ width: Int = 6, _ height: Int = 4) -> Data { bitmap(width, height).representation(using: .tiff, properties: [:])! }
private func jpegData(_ width: Int = 6, _ height: Int = 4) -> Data { bitmap(width, height).representation(using: .jpeg, properties: [:])! }

private func size(of png: Data) -> NSSize? {
    guard let rep = NSBitmapImageRep(data: png) else { return nil }
    return NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
}

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

@MainActor
@Suite struct SystemPasteboardTests {
    /// A private pasteboard: these tests never touch the user's clipboard.
    private func makePasteboard() -> (SystemPasteboard, NSPasteboard) {
        let raw = NSPasteboard.withUniqueName()
        return (SystemPasteboard(pasteboard: raw), raw)
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
