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

    /// Pixel size read from the PNG header (the IHDR chunk), without decoding the picture.
    /// Nil for anything that is not a well-formed PNG header or that claims a zero size.
    public static func dimensions(of png: Data) -> (width: Int, height: Int)? {
        // Layout: signature (8) | IHDR length (4) | "IHDR" (4) | width (4) | height (4), big-endian.
        let header = Data(png.prefix(24))   // a copy, so slices with a non-zero start index work too
        guard header.count == 24, header.prefix(8) == signature, header[12..<16] == Data("IHDR".utf8) else { return nil }
        func bigEndian(_ range: Range<Int>) -> Int { header[range].reduce(0) { ($0 << 8) | Int($1) } }
        let width = bigEndian(16..<20), height = bigEndian(20..<24)
        return width > 0 && height > 0 ? (width, height) : nil
    }
}
