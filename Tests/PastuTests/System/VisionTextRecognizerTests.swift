import AppKit
import Testing
@testable import Pastu
@testable import PastuCore

/// Runs the real Vision framework on a picture made here: no network, no files.
@Suite struct VisionTextRecognizerTests {
    private func picture(_ lines: [String], size: CGFloat = 40) -> Data {
        let font = NSFont.systemFont(ofSize: size, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        let width = 900, height = 90 * lines.count + 40
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        for (index, line) in lines.enumerated() {
            (line as NSString).draw(at: NSPoint(x: 30, y: CGFloat(height - 90 * (index + 1))), withAttributes: attributes)
        }
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])!
    }

    @Test func readsTextFromAPicture() async throws {
        let text = try #require(await VisionTextRecognizer().recognizeText(in: picture(["Hello Pastu", "Invoice 2026"])))
        let lower = text.lowercased()
        #expect(lower.contains("pastu"), "recognised: \(text)")
        #expect(lower.contains("invoice"), "recognised: \(text)")
    }

    @Test func aPictureWithoutTextGivesAnEmptyString() async throws {
        let blank = picture([])
        #expect(try #require(await VisionTextRecognizer().recognizeText(in: blank)) == "")
    }

    @Test func somethingThatIsNotAPictureFails() async {
        #expect(await VisionTextRecognizer().recognizeText(in: Data([1, 2, 3])) == nil)
    }
}
