import AppKit
import Foundation
import Testing
@testable import Pastu
@testable import PastuCore

/// Measures how long the panel needs to open, for a history of a given size. Off by default, because it takes a while
/// and its numbers depend on the machine: run it with `PASTU_BENCH=1 swift test --filter PanelOpenBenchmark` and
/// read the `BENCH` lines. See docs/performance.md.
extension ShellTests {
@MainActor
@Suite(.enabled(if: ProcessInfo.processInfo.environment["PASTU_BENCH"] != nil, "set PASTU_BENCH=1 to measure"))
struct PanelOpenBenchmark {
    private static let runs = 25

    /// A noisy picture about the size of a retina screenshot, so decoding it costs what a real one costs.
    private func screenshot(_ salt: Int) -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 2880, pixelsHigh: 1800, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        var generator = SystemRandomNumberGenerator()
        let bytes = rep.bitmapData!
        for index in stride(from: 0, to: 2880 * 1800 * 4, by: 7) { bytes[index] = UInt8.random(in: 0...255, using: &generator) }
        // The salt makes each picture unique, so none of them merges into another.
        bytes[0] = UInt8(salt % 256); bytes[1] = UInt8(salt / 256)
        return rep.representation(using: .png, properties: [:])!
    }

    private func makeStore(texts: Int, pictures: Int) throws -> ClipStore {
        let store = try ClipStore()
        let now = Date()
        for index in 0..<texts {
            let text = "Clip number \(index): " + String(repeating: "lorem ipsum dolor sit amet ", count: 1 + index % 8)
            try store.insert(CapturedClip(text: text, sourceBundleIdentifier: "com.apple.Safari", date: now.addingTimeInterval(-Double(index))))
        }
        let template = screenshot(1)
        for index in 0..<pictures {
            // Distinct bytes per picture; decoding cost is the same as for the template.
            let png = template + Data([UInt8(index % 256), UInt8(index / 256)])
            try store.insert(.image(png: png, sourceBundleIdentifier: "com.apple.screencaptureui", date: now.addingTimeInterval(-Double(index) * 7)))
        }
        return store
    }

    private func milliseconds(_ body: () -> Void) -> Double {
        let start = DispatchTime.now().uptimeNanoseconds
        body()
        return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
    }

    private func report(_ name: String, _ samples: [Double]) {
        let sorted = samples.sorted()
        let median = sorted[sorted.count / 2]
        let p95 = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))]
        print(String(format: "BENCH %@ first=%.1f ms median=%.1f ms p95=%.1f ms (n=%d)", name, samples[0], median, p95, samples.count))
    }

    private func measureOpening(texts: Int, pictures: Int, label: String) async throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        ImageCache.shared.removeAll()
        let store = try makeStore(texts: texts, pictures: pictures)
        let model = ClipListModel(store: store)
        let controller = PanelController(
            model: model, canAutoPaste: { true },
            imageData: { id in (try? store.imageData(id: id)) ?? nil }, onSelect: { _ in }
        )
        var samples: [Double] = []
        for _ in 0..<Self.runs {
            samples.append(milliseconds { controller.show() })
            // Let the pictures decode in the background and the view settle before closing, like a user reading the list.
            try await Task.sleep(for: .milliseconds(400))
            controller.hide()
            try await Task.sleep(for: .milliseconds(50))
        }
        report(label, samples)
    }

    @Test func emptyHistory() async throws { try await measureOpening(texts: 0, pictures: 0, label: "open/empty-history") }
    @Test func fiveThousandTextClips() async throws { try await measureOpening(texts: 5_000, pictures: 0, label: "open/5000-text") }
    @Test func textAndTwentyScreenshots() async throws { try await measureOpening(texts: 500, pictures: 20, label: "open/500-text+20-screenshots") }
    @Test func screenshotsOnly() async throws { try await measureOpening(texts: 0, pictures: 60, label: "open/60-screenshots") }

    /// Searching the biggest history the retention default allows.
    @Test func searchOnFiveThousandClips() throws {
        let store = try makeStore(texts: 5_000, pictures: 0)
        var samples: [Double] = []
        for query in ["lorem", "number 42", "zzzz", "ipsum dolor", "Clip number 4999", "sit"] {
            samples.append(milliseconds { _ = try? store.search(query, limit: 100, offset: 0, kind: nil) })
        }
        report("search/5000-text (6 queries)", samples)
    }
}
}
