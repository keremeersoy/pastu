import AppKit
import SwiftUI
import Testing
@testable import Pastu
@testable import PastuCore

/// Renders the panel offscreen. Set PASTU_SNAPSHOT_DIR to also write PNGs for visual review.
extension ShellTests {
@MainActor
@Suite struct PanelSnapshotTests {
    private func sampleModel() throws -> ClipListModel {
        let store = try ClipStore()
        let now = Date()
        let samples: [(String, String?, TimeInterval)] = [
            ("git commit -m \"Add retention policy\"\ngit push origin main", "com.apple.Terminal", 20),
            ("https://developer.apple.com/documentation/appkit/nspanel", "com.apple.Safari", 600),
            ("func submit() {\n    let clip = model.selectedClip\n    hide()\n    if let clip { onSelect(clip) }\n}", "com.apple.dt.Xcode", 7_200),
            ("Meeting notes: ship v0.1 beta to ten friends, collect feedback on first-run permissions.", "com.apple.Notes", 90_000),
            (String(repeating: "A very long clip that keeps going and going. ", count: 400), "com.apple.TextEdit", 400_000),
        ]
        for (text, app, secondsAgo) in samples {
            try store.insert(CapturedClip(text: text, sourceBundleIdentifier: app, date: now.addingTimeInterval(-secondsAgo)))
        }
        let model = ClipListModel(store: store)
        model.moveSelection(by: 3) // the Notes clip
        model.togglePinSelected()
        model.moveSelection(by: -3)
        return model
    }

    /// A recognisable picture (diagonal gradient with a bright block) so thumbnails and previews are easy to judge.
    private func samplePicture(_ width: Int, _ height: Int) -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGradient(starting: .systemIndigo, ending: .systemOrange)!.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: 35)
        NSColor.white.withAlphaComponent(0.85).setFill()
        NSRect(x: width / 8, y: height / 8, width: width / 4, height: height / 4).fill()
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])!
    }

    /// Text clips plus two screenshots; the loader hands the pictures to the panel like the app does.
    private func pictureSample() throws -> (ClipListModel, (Int64) -> Data?) {
        let store = try ClipStore()
        let now = Date()
        try store.insert(CapturedClip(text: "Notes about the launch plan", sourceBundleIdentifier: "com.apple.Notes", date: now.addingTimeInterval(-3_600)))
        try store.insert(.image(png: samplePicture(1440, 900), sourceBundleIdentifier: "com.apple.screencaptureui", date: now.addingTimeInterval(-120)))
        try store.insert(.image(png: samplePicture(600, 600), sourceBundleIdentifier: "com.apple.Preview", date: now.addingTimeInterval(-900)))
        let model = ClipListModel(store: store)
        return (model, { id in (try? store.imageData(id: id)) ?? nil })
    }

    /// Hosts the view in a real window and captures the window's own drawing, so AppKit-backed
    /// controls (text field, scroll views) render. ImageRenderer cannot draw those.
    private func render(_ view: some View) async throws -> NSImage {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        let panel = ClipPanel(size: PanelMetrics.size)
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.contentView = NSHostingView(rootView: view)
        panel.makeKeyAndOrderFront(nil)
        defer { panel.orderOut(nil) }
        try await Task.sleep(for: .milliseconds(600))

        let content = try #require(panel.contentView)
        let rep = try #require(content.bitmapImageRepForCachingDisplay(in: content.bounds))
        content.cacheDisplay(in: content.bounds, to: rep)
        let image = NSImage(size: content.bounds.size)
        image.addRepresentation(rep)
        return image
    }

    private func save(_ image: NSImage, name: String) {
        guard let dir = ProcessInfo.processInfo.environment["PASTU_SNAPSHOT_DIR"],
              let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
    }

    @Test func panelRendersWithClips() async throws {
        let model = try sampleModel()
        model.moveSelection(by: 1)
        let image = try await render(PanelView(model: model, canAutoPaste: true, onSubmit: {}))
        #expect(image.size.width >= PanelMetrics.size.width)
        save(image, name: "panel-with-clips")
    }

    @Test func panelRendersWithoutAccessibilityPermission() async throws {
        let image = try await render(PanelView(model: try sampleModel(), canAutoPaste: false, onSubmit: {}))
        save(image, name: "panel-no-accessibility")
    }

    @Test func panelRendersEmptyState() async throws {
        let model = ClipListModel(store: try ClipStore())
        let image = try await render(PanelView(model: model, canAutoPaste: true, onSubmit: {}))
        save(image, name: "panel-empty")
    }

    @Test func panelRendersLinksFilter() async throws {
        let model = try sampleModel()
        model.filter = .links
        let image = try await render(PanelView(model: model, canAutoPaste: true, onSubmit: {}))
        save(image, name: "panel-links-filter")
    }

    @Test func panelRendersEmptyFilteredState() async throws {
        let store = try ClipStore()
        try store.insert(CapturedClip(text: "just a note", sourceBundleIdentifier: nil, date: Date()))
        let model = ClipListModel(store: store)
        model.filter = .links
        let image = try await render(PanelView(model: model, canAutoPaste: true, onSubmit: {}))
        save(image, name: "panel-links-empty")
    }
    @Test func panelRendersWithAFooterNotice() async throws {
        let model = try sampleModel()
        model.notice = "Ignoring Terminal: its future copies are not recorded or read"
        let image = try await render(PanelView(model: model, canAutoPaste: true, onSubmit: {}))
        save(image, name: "panel-notice")
    }
    @Test func panelRendersPictureClips() async throws {
        let (model, loader) = try pictureSample()
        let image = try await render(PanelView(model: model, canAutoPaste: true, onSubmit: {}, imageData: loader))
        save(image, name: "panel-pictures")
    }

    @Test func panelRendersThePictureFilter() async throws {
        let (model, loader) = try pictureSample()
        model.filter = .images
        let image = try await render(PanelView(model: model, canAutoPaste: true, onSubmit: {}, imageData: loader))
        save(image, name: "panel-pictures-filter")
    }

    @Test func panelRendersAPictureWhoseBytesAreMissing() async throws {
        let (model, _) = try pictureSample()
        let image = try await render(PanelView(model: model, canAutoPaste: true, onSubmit: {}, imageData: { _ in nil }))
        save(image, name: "panel-picture-missing")
    }
}
}
