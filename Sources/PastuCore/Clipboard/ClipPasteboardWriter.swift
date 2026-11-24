import Foundation

/// Puts a stored clip back on the pasteboard (text, optionally with its formatting, or the picture's bytes), without Pastu recapturing it.
@MainActor
public enum ClipPasteboardWriter {
    /// Returns false when there was nothing to write (e.g. the picture's bytes are gone).
    @discardableResult
    /// With `keepFormatting`, a text clip's stored RTF/HTML go on the pasteboard next to the text; without it (the
    /// default) only plain text is written.
    public static func copy(
        _ clip: StoredClip, from store: ClipStore, using monitor: ClipboardMonitor, keepFormatting: Bool = false
    ) -> Bool {
        if clip.kind == .file {
            // Only files that are still there: a path that no longer exists would paste as nothing, or an error.
            let existing = clip.files.filter { FileManager.default.fileExists(atPath: $0) }.map { URL(fileURLWithPath: $0) }
            guard !existing.isEmpty else { return false }
            monitor.copyToPasteboard(files: existing)
        } else if clip.kind == .image {
            guard let png = try? store.imageData(id: clip.id) else { return false }
            monitor.copyToPasteboard(imagePNG: png)
        } else {
            let rich = keepFormatting && clip.hasFormatting ? (try? store.richContent(id: clip.id)) ?? nil : nil
            monitor.copyToPasteboard(clip.text, rtf: rich?.rtf, html: rich?.html)
        }
        return true
    }
}
