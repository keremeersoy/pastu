import AppKit
import Foundation

// Shared by the image-related tests.
let pngSignature = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

func bitmap(_ width: Int, _ height: Int) -> NSBitmapImageRep {
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

func pngData(_ width: Int = 6, _ height: Int = 4) -> Data { bitmap(width, height).representation(using: .png, properties: [:])! }
func tiffData(_ width: Int = 6, _ height: Int = 4) -> Data { bitmap(width, height).representation(using: .tiff, properties: [:])! }
func jpegData(_ width: Int = 6, _ height: Int = 4) -> Data { bitmap(width, height).representation(using: .jpeg, properties: [:])! }

func size(of png: Data) -> NSSize? {
    guard let rep = NSBitmapImageRep(data: png) else { return nil }
    return NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
}

