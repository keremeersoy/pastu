import Foundation

/// Puts a stored clip back on the pasteboard (text, or the picture's bytes), without Pastu recapturing it.
@MainActor
public enum ClipPasteboardWriter {
    /// Returns false when there was nothing to write (e.g. the picture's bytes are gone).
    @discardableResult
    public static func copy(_ clip: StoredClip, from store: ClipStore, using monitor: ClipboardMonitor) -> Bool {
        if clip.kind == .image {
            guard let png = try? store.imageData(id: clip.id) else { return false }
            monitor.copyToPasteboard(imagePNG: png)
        } else {
            monitor.copyToPasteboard(clip.text)
        }
        return true
    }
}
