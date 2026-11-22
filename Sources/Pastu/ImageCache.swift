import AppKit
import ImageIO
import PastuCore

/// What the panel needs to draw a picture clip: a small thumbnail for the list row plus size information.
/// Each picture is loaded from the database and decoded once; the list then redraws from memory.
@MainActor
final class ImageCache {
    struct Info {
        let thumbnail: NSImage
        let width: Int
        let height: Int
        let byteCount: Int
    }

    /// The one cache the panel uses.
    static let shared = ImageCache()

    static let thumbnailPixels = 96
    /// Bounded so a long history of screenshots cannot grow the app's memory without limit.
    static let maxEntries = 200

    private var entries: [Int64: Info] = [:]
    var entryCount: Int { entries.count }

    /// Nil when the bytes are missing or not a decodable PNG; that is not cached, so a later call retries.
    func info(for clipID: Int64, load: (Int64) -> Data?) -> Info? {
        if let cached = entries[clipID] { return cached }
        guard let data = load(clipID), let size = PNGConverter.dimensions(of: data),
              let thumbnail = Self.makeThumbnail(from: data) else { return nil }

        if entries.count >= Self.maxEntries { entries.removeAll(keepingCapacity: true) }
        let info = Info(thumbnail: thumbnail, width: size.width, height: size.height, byteCount: data.count)
        entries[clipID] = info
        return info
    }

    private var lastFull: (clipID: Int64, image: NSImage)?
    var holdsFullImage: Bool { lastFull != nil }

    func contains(_ clipID: Int64) -> Bool { entries[clipID] != nil }

    /// Drops every thumbnail and the full picture; see `PanelCaches`.
    func removeAll() {
        entries.removeAll()
        lastFull = nil
    }

    /// Drops the full-size picture only; thumbnails stay so the next open draws rows without decoding.
    func removeFullImage() {
        lastFull = nil
    }

    /// Forgets one clip (it was deleted).
    func remove(_ clipID: Int64) {
        entries[clipID] = nil
        if lastFull?.clipID == clipID { lastFull = nil }
    }

    /// Forgets every clip not in `clipIDs` (removed by retention or anything else while the panel was hidden).
    func retain(_ clipIDs: Set<Int64>) {
        entries = entries.filter { clipIDs.contains($0.key) }
        if let last = lastFull, !clipIDs.contains(last.clipID) { lastFull = nil }
    }

    /// The full-size picture for the preview pane. Only the one on screen is kept (a big screenshot can be
    /// megabytes), so moving the selection decodes the next one and drops the previous.
    func fullImage(for clipID: Int64, load: (Int64) -> Data?) -> NSImage? {
        if let last = lastFull, last.clipID == clipID { return last.image }
        guard let data = load(clipID), PNGConverter.dimensions(of: data) != nil,
              let image = NSImage(data: data) else { return nil }
        lastFull = (clipID, image)
        return image
    }

    /// ImageIO makes the thumbnail while decoding, so a big screenshot is never held at full size.
    private static func makeThumbnail(from data: Data) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailPixels,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }
}

/// Everything the panel keeps in memory to draw clips: thumbnails, the full picture, preview text and row snippets.
/// A clip the user removed must not linger there, but thumbnails are kept across opens (re-decoding every visible
/// screenshot would make opening the panel slow), so each removal path forgets just what it has to.
@MainActor
enum PanelCaches {
    /// Clear History: forget everything, including the row snippets the list's model keeps.
    static func purgeAll(model: ClipListModel?) {
        model?.purgeSnippets()
        ImageCache.shared.removeAll()
        PreviewContent.purge()
    }

    /// The panel hid: forget the clip text and the full-size picture; keep the small thumbnails.
    static func panelDidHide() {
        ImageCache.shared.removeFullImage()
        PreviewContent.purge()
    }

    /// One clip was deleted from the panel.
    static func forget(_ clipID: Int64, model: ClipListModel) {
        model.forgetSnippet(of: clipID)
        ImageCache.shared.remove(clipID)
        PreviewContent.remove(clipID)
    }

    /// The panel opened with these clips loaded: anything else was deleted meanwhile (retention prune, another
    /// path) and is dropped. Clips on later pages are dropped too, which only costs a re-decode if scrolled to.
    static func retainOnly(_ clipIDs: Set<Int64>) {
        ImageCache.shared.retain(clipIDs)
        PreviewContent.retain(clipIDs)
    }
}
