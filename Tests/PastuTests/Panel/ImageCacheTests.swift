import AppKit
import SwiftUI
import Foundation
import Testing
@testable import Pastu
@testable import PastuCore

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

    // MARK: Loading without blocking the panel

    @Test func cachedInfoIsNilUntilThePictureWasLoaded() async throws {
        let cache = ImageCache()
        #expect(cache.cachedInfo(for: 1) == nil)
        let info = try #require(await cache.loadInfo(for: 1, load: { _ in makePNG(800, 400) }))
        #expect(cache.cachedInfo(for: 1) != nil)
        #expect(info.width == 800 && info.height == 400)
        #expect(max(info.thumbnail.size.width, info.thumbnail.size.height) <= CGFloat(ImageCache.thumbnailPixels))
    }

    @Test func loadingTwiceReadsTheBytesOnce() async {
        let cache = ImageCache()
        let data = makePNG(20, 20)
        var loads = 0
        let loader: (Int64) -> Data? = { _ in loads += 1; return data }
        _ = await cache.loadInfo(for: 3, load: loader)
        _ = await cache.loadInfo(for: 3, load: loader)
        #expect(loads == 1)
    }

    /// Several rows ask for the same picture at once (list and preview): one read, one decode.
    @Test func loadsInFlightForTheSameClipAreShared() async {
        let cache = ImageCache()
        let data = makePNG(300, 200)
        var loads = 0
        let loader: (Int64) -> Data? = { _ in loads += 1; return data }
        let first = Task { await cache.loadInfo(for: 4, load: loader) }
        let second = Task { await cache.loadInfo(for: 4, load: loader) }
        let results = await [first.value, second.value]
        #expect(results.allSatisfy { $0 != nil })
        #expect(loads == 1)
    }

    @Test func aMissingOrBrokenPictureGivesNilAndIsRetriedLater() async throws {
        let cache = ImageCache()
        #expect(await cache.loadInfo(for: 1, load: { _ in nil }) == nil)
        #expect(await cache.loadInfo(for: 2, load: { _ in Data([1, 2, 3]) }) == nil)
        #expect(try #require(await cache.loadInfo(for: 1, load: { _ in makePNG(5, 5) })).width == 5)
    }

    /// The clip was deleted while its thumbnail was still being made: the picture must not end up in the cache.
    @Test func aDeleteDuringALoadKeepsTheResultOutOfTheCache() async {
        let cache = ImageCache()
        let data = makePNG(2_000, 1_500)
        let result = Task { await cache.loadInfo(for: 8, load: { _ in data }) }
        await Task.yield()
        cache.remove(8)
        _ = await result.value
        #expect(cache.cachedInfo(for: 8) == nil)
    }

    @Test func clearingEverythingDuringALoadKeepsTheResultOutOfTheCache() async {
        let cache = ImageCache()
        let data = makePNG(2_000, 1_500)
        let result = Task { await cache.loadInfo(for: 8, load: { _ in data }) }
        await Task.yield()
        cache.removeAll()
        _ = await result.value
        #expect(cache.cachedInfo(for: 8) == nil)
    }
}

extension ShellTests {
@MainActor
@Suite struct PictureRowLoadingTests {
    /// A row for a picture the cache has never seen draws at once (placeholder) and fills in by itself.
    @Test func aPictureRowFillsInAfterTheThumbnailIsDecoded() async throws {
        enableAccessibilityTree()
        ImageCache.shared.removeAll()
        let store = try ClipStore()
        let id = try store.insert(.image(png: makePNG(800, 400), sourceBundleIdentifier: nil, date: Date()))
        let clip = try #require(try store.recent().first { $0.id == id })
        let loader: (Int64) -> Data? = { (try? store.imageData(id: $0)) ?? nil }
        let host = NSHostingView(rootView: ClipRow(
            clip: clip, isSelected: false, shortcutDigit: nil, showsShortcut: false, query: "", snippet: nil, imageData: loader
        ).frame(width: 320))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 60), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        window.orderFrontRegardless()
        defer { window.orderOut(nil); ImageCache.shared.removeAll() }

        // Before the decode finishes the row has no size to speak yet.
        #expect(ImageCache.shared.cachedInfo(for: id) == nil)
        for _ in 0..<40 where ImageCache.shared.cachedInfo(for: id) == nil { try await Task.sleep(for: .milliseconds(50)) }
        try #require(ImageCache.shared.cachedInfo(for: id) != nil, "the row never asked for its thumbnail")
        try await Task.sleep(for: .milliseconds(200))
        #expect(accessibilityElement(containing: "800 by 400", in: host) != nil)
    }
}
}
