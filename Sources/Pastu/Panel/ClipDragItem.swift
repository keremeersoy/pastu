import AppKit
import PastuCore
import UniformTypeIdentifiers

/// What a row hands over when it is dragged out of the panel: text as plain text, a picture as a PNG.
/// A picture is registered as data and the system makes a file only when the drop target wants one (Finder), so
/// Pastu never leaves a copy of the clip on disk.
enum ClipDragItem {
    static func provider(for clip: StoredClip, imageData: (Int64) -> Data?) -> NSItemProvider {
        if clip.kind == .file { return fileProvider(for: clip) }
        guard clip.kind == .image else { return NSItemProvider(object: clip.text as NSString) }
        // Without the bytes there is nothing to drag, and an empty provider keeps the drag from starting.
        guard let data = imageData(clip.id) else { return NSItemProvider() }
        let provider = NSItemProvider()
        provider.suggestedName = "Pastu picture"
        provider.registerDataRepresentation(forTypeIdentifier: UTType.png.identifier, visibility: .all) { completion in
            completion(data, nil)
            return nil
        }
        return provider
    }

    /// One file drags as that file. Several drag as their paths, one per line: a single drag item can carry only one
    /// file, and text is what most targets can take. Files that are gone are left out; with none left, nothing drags.
    private static func fileProvider(for clip: StoredClip) -> NSItemProvider {
        let existing = clip.files.filter { FileManager.default.fileExists(atPath: $0) }
        switch existing.count {
        case 0: return NSItemProvider()
        case 1: return NSItemProvider(object: URL(fileURLWithPath: existing[0]) as NSURL)
        default: return NSItemProvider(object: existing.joined(separator: "\n") as NSString)
        }
    }
}
