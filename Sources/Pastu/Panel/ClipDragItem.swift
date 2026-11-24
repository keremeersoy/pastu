import AppKit
import PastuCore
import UniformTypeIdentifiers

/// What a row hands over when it is dragged out of the panel: text as plain text, a picture as a PNG.
/// A picture is registered as data and the system makes a file only when the drop target wants one (Finder), so
/// Pastu never leaves a copy of the clip on disk.
enum ClipDragItem {
    static func provider(for clip: StoredClip, imageData: (Int64) -> Data?) -> NSItemProvider {
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
}
