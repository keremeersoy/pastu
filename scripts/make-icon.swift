// Generates Resources/AppIcon.icns: a temporary, placeholder app icon drawn in code (a clipboard on a blue
// rounded square). Uses only AppKit and `iconutil`, both part of macOS; no design tools or dependencies.
//
// Usage: swift scripts/make-icon.swift
// A designed icon is welcome: replace Resources/AppIcon.icns and delete this script.
import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let output = root.appendingPathComponent("Resources/AppIcon.icns")
let iconset = FileManager.default.temporaryDirectory
    .appendingPathComponent("PastuIcon-\(UUID().uuidString).iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: iconset) }

/// Draws the icon at `pixels` × `pixels` and returns PNG bytes.
func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    let size = CGFloat(pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // macOS icon grid: the rounded square fills ~80% of the canvas, leaving room for the system shadow.
    let inset = size * 0.1
    let body = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let shape = NSBezierPath(roundedRect: body, xRadius: body.width * 0.225, yRadius: body.width * 0.225)
    NSGradient(
        starting: NSColor(calibratedRed: 0.29, green: 0.56, blue: 1.0, alpha: 1),
        ending: NSColor(calibratedRed: 0.13, green: 0.32, blue: 0.86, alpha: 1)
    )!.draw(in: shape, angle: -90)

    // A clipboard drawn with plain paths. (SF Symbols must not be used in app icons under Apple's license.)
    let u = body.width / 100
    let board = NSRect(x: body.midX - 26 * u, y: body.midY - 32 * u, width: 52 * u, height: 62 * u)
    NSColor.white.setFill()
    NSBezierPath(roundedRect: board, xRadius: 7 * u, yRadius: 7 * u).fill()
    let clip = NSRect(x: body.midX - 13 * u, y: board.maxY - 6 * u, width: 26 * u, height: 12 * u)
    NSColor(calibratedRed: 0.10, green: 0.22, blue: 0.62, alpha: 1).setFill()
    NSBezierPath(roundedRect: clip, xRadius: 4 * u, yRadius: 4 * u).fill()
    // Lines of "text" on the board.
    NSColor(calibratedRed: 0.29, green: 0.56, blue: 1.0, alpha: 1).setFill()
    for (row, width) in [36.0, 30.0, 36.0, 22.0].enumerated() {
        let y = board.maxY - (19 + Double(row) * 11) * u
        NSBezierPath(roundedRect: NSRect(x: board.minX + 8 * u, y: y, width: width * u, height: 5 * u),
                     xRadius: 2.5 * u, yRadius: 2.5 * u).fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        try render(pixels: points * scale).write(to: iconset.appendingPathComponent(name))
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
print("Wrote \(output.path)")
