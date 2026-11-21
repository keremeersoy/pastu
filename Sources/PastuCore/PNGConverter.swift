import AppKit

/// Normalises pictures from the pasteboard to PNG, so storage and pasting deal with a single format.
public enum PNGConverter {
    private static let signature = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

    /// PNG for any image format AppKit can decode (TIFF, JPEG, …). PNG input is returned unchanged
    /// (no needless re-encoding). Returns nil for data that is not a decodable image.
    public static func png(from data: Data) -> Data? {
        if data.prefix(signature.count) == signature, NSBitmapImageRep(data: data) != nil { return data }
        return NSBitmapImageRep(data: data)?.representation(using: .png, properties: [:])
    }
}
