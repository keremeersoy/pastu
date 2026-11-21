import AppKit
import Foundation
import Testing
@testable import Pastu
@testable import PastuCore

// Deliberately duplicates the PNG helper in PastuCoreTests/TestImages.swift: SwiftPM test targets cannot share
// source files, and a shared helper target is not worth it for a few lines.
private func makePNG(_ width: Int, _ height: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.systemBlue.setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

@MainActor
@Suite struct ImageCacheTests {
    @Test func aBigPictureGetsASmallThumbnailAndKeepsItsRealSize() throws {
        let data = makePNG(800, 400)
        let info = try #require(ImageCache().info(for: 1, load: { _ in data }))
        #expect(info.width == 800)
        #expect(info.height == 400)
        #expect(info.byteCount == data.count)
        #expect(max(info.thumbnail.size.width, info.thumbnail.size.height) <= CGFloat(ImageCache.thumbnailPixels))
        #expect(info.thumbnail.size.width > info.thumbnail.size.height)   // aspect ratio is kept
    }

    @Test func eachPictureIsLoadedOnlyOnce() {
        let cache = ImageCache()
        let data = makePNG(50, 50)
        var loads = 0
        let loader: (Int64) -> Data? = { _ in loads += 1; return data }
        _ = cache.info(for: 7, load: loader)
        _ = cache.info(for: 7, load: loader)
        _ = cache.info(for: 7, load: loader)
        #expect(loads == 1)
    }

    @Test func differentClipsAreCachedSeparately() throws {
        let cache = ImageCache()
        let small = try #require(cache.info(for: 1, load: { _ in makePNG(10, 10) }))
        let large = try #require(cache.info(for: 2, load: { _ in makePNG(30, 20) }))
        #expect(small.width == 10)
        #expect(large.width == 30)
    }

    @Test func missingOrBrokenBytesGiveNoInfo() {
        let cache = ImageCache()
        #expect(cache.info(for: 1, load: { _ in nil }) == nil)
        #expect(cache.info(for: 2, load: { _ in Data([1, 2, 3, 4]) }) == nil)
        #expect(cache.info(for: 3, load: { _ in Data() }) == nil)
    }

    @Test func aFailedLoadIsRetriedNextTime() throws {
        let cache = ImageCache()
        var available = false
        let loader: (Int64) -> Data? = { _ in available ? makePNG(5, 5) : nil }
        #expect(cache.info(for: 9, load: loader) == nil)
        available = true
        #expect(try #require(cache.info(for: 9, load: loader)).width == 5)
    }

    @Test func theCacheStaysBounded() {
        let cache = ImageCache()
        let data = makePNG(4, 4)
        for id in 0..<(ImageCache.maxEntries + 50) { _ = cache.info(for: Int64(id), load: { _ in data }) }
        #expect(cache.entryCount <= ImageCache.maxEntries)
    }

    // MARK: Full-size picture for the preview

    @Test func theFullPictureKeepsItsPixelSize() throws {
        let image = try #require(ImageCache().fullImage(for: 1, load: { _ in makePNG(300, 200) }))
        let rep = try #require(image.representations.first)
        #expect(rep.pixelsWide == 300)
        #expect(rep.pixelsHigh == 200)
    }

    @Test func theFullPictureIsDecodedOnceWhileItStaysSelected() {
        let cache = ImageCache()
        let data = makePNG(20, 20)
        var loads = 0
        let loader: (Int64) -> Data? = { _ in loads += 1; return data }
        _ = cache.fullImage(for: 5, load: loader)
        _ = cache.fullImage(for: 5, load: loader)
        #expect(loads == 1)
    }

    @Test func selectingAnotherPictureLoadsThatOne() throws {
        let cache = ImageCache()
        let first = try #require(cache.fullImage(for: 1, load: { _ in makePNG(10, 10) }))
        let second = try #require(cache.fullImage(for: 2, load: { _ in makePNG(40, 30) }))
        #expect(first.representations.first?.pixelsWide == 10)
        #expect(second.representations.first?.pixelsWide == 40)
    }

    @Test func missingOrBrokenFullPicturesGiveNil() {
        let cache = ImageCache()
        #expect(cache.fullImage(for: 1, load: { _ in nil }) == nil)
        #expect(cache.fullImage(for: 2, load: { _ in Data([9, 9, 9]) }) == nil)
    }
}
