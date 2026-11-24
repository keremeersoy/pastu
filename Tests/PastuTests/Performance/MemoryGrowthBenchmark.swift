import AppKit
import Darwin
import Foundation
import Testing
@testable import Pastu
@testable import PastuCore

/// Looks for memory that grows with use: opens and closes the panel hundreds of times, and reads text in pictures, and
/// prints the process's physical footprint along the way. A steady line is fine; a line that keeps climbing is a leak.
/// Off by default: `PASTU_BENCH=1 swift test --filter MemoryGrowthBenchmark` (see docs/performance.md).
extension ShellTests {
@MainActor
@Suite(.enabled(if: ProcessInfo.processInfo.environment["PASTU_BENCH"] != nil, "set PASTU_BENCH=1 to measure"))
struct MemoryGrowthBenchmark {
    /// The physical footprint of this process, in MB: the number Activity Monitor calls "Memory".
    private func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : -1
    }

    private func noisyPNG(_ salt: Int) -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 1600, pixelsHigh: 1000, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        var generator = SystemRandomNumberGenerator()
        let bytes = rep.bitmapData!
        for index in stride(from: 0, to: 1600 * 1000 * 4, by: 5) { bytes[index] = UInt8.random(in: 0...255, using: &generator) }
        bytes[0] = UInt8(salt % 256); bytes[1] = UInt8(salt / 256)
        return rep.representation(using: .png, properties: [:])!
    }

    private func settle(_ seconds: Double = 0.3) async { try? await Task.sleep(for: .seconds(seconds)) }

    private func line(_ label: String) { print(String(format: "MEM %@ %.1f MB", label, footprintMB())) }

    @Test func openingAndClosingThePanelManyTimes() async throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        let store = try ClipStore()
        for index in 0..<500 {
            try store.insert(CapturedClip(
                text: "Clip \(index): " + String(repeating: "lorem ipsum dolor ", count: 1 + index % 12),
                sourceBundleIdentifier: "com.apple.Safari", date: Date().addingTimeInterval(-Double(index))
            ))
        }
        for index in 0..<20 {
            try store.insert(.image(png: noisyPNG(index), sourceBundleIdentifier: "com.apple.screencaptureui", date: Date().addingTimeInterval(-Double(index) * 9)))
        }
        let model = ClipListModel(store: store)
        let controller = PanelController(
            model: model, canAutoPaste: { true },
            imageData: { id in (try? store.imageData(id: id)) ?? nil }, onSelect: { _ in }
        )
        await settle()
        line("start")
        for cycle in 1...400 {
            controller.show()
            await settle(0.02)
            // Move around and search a little, like a user would.
            model.moveSelection(by: 3)
            if cycle % 5 == 0 { model.query = "lorem"; await settle(0.02); model.query = "" }
            controller.hide()
            await settle(0.01)
            if [1, 25, 50, 100, 200, 300, 400].contains(cycle) { line("after \(cycle) opens") }
        }
        controller.hide()
        await settle(1)
        line("end, panel closed")
    }

    @Test func readingTheTextInPictures() async throws {
        let recognizer = VisionTextRecognizer()
        let pictures = (0..<12).map { noisyPNG($0) }
        line("before recognition")
        for round in 1...5 {
            for png in pictures { _ = await recognizer.recognizeText(in: png) }
            await settle(0.5)
            line("after \(round * pictures.count) pictures")
        }
        await settle(3)
        line("3 s later")
    }
}
}
