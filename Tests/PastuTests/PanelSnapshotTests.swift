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
    private func render(_ view: some View, appearance: NSAppearance.Name = .darkAqua) async throws -> NSImage {
        try await renderWindow(view, appearance: appearance).image
    }

    /// Like `render`, but also returns the hosting view so tests can inspect the view hierarchy.
    private func renderWindow(
        _ view: some View, appearance: NSAppearance.Name = .darkAqua
    ) async throws -> (image: NSImage, content: NSView) {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        // Cheap, and the banner tests read the accessibility tree, which must be switched on before hosting.
        enableAccessibilityTree()
        let panel = ClipPanel(size: PanelMetrics.size)
        panel.appearance = NSAppearance(named: appearance)
        panel.contentView = NSHostingView(rootView: view)
        panel.makeKeyAndOrderFront(nil)
        defer { panel.orderOut(nil) }
        try await Task.sleep(for: .milliseconds(600))

        let content = try #require(panel.contentView)
        let rep = try #require(content.bitmapImageRepForCachingDisplay(in: content.bounds))
        content.cacheDisplay(in: content.bounds, to: rep)
        let image = NSImage(size: content.bounds.size)
        image.addRepresentation(rep)
        return (image, content)
    }

    /// Alpha of the pixel at a point given in view points from the top-left corner.
    private func alpha(in image: NSImage, atPoint point: CGPoint) throws -> CGFloat {
        try color(in: image, atPoint: point).alphaComponent
    }

    private func color(in image: NSImage, atPoint point: CGPoint) throws -> NSColor {
        let rep = try #require(image.representations.first as? NSBitmapImageRep)
        let scale = CGFloat(rep.pixelsWide) / image.size.width
        return try #require(rep.colorAt(x: Int(point.x * scale), y: Int(point.y * scale)))
    }

    /// The middle of the header row, right of the search text: only the shell's background is there.
    private var headerCenter: CGPoint { CGPoint(x: PanelMetrics.size.width / 2, y: 24) }

    private func containsVisualEffectView(_ view: NSView) -> Bool {
        view is NSVisualEffectView || view.subviews.contains(where: containsVisualEffectView)
    }

    private func containsText(_ text: String, in view: NSView) -> Bool {
        accessibilityElement(containing: text, in: view) != nil
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

    @Test(arguments: [NSAppearance.Name.darkAqua, .aqua])
    func panelRendersAccessibilityBanner(appearance: NSAppearance.Name) async throws {
        let (image, content) = try await renderWindow(
            PanelView(model: try sampleModel(), canAutoPaste: false, onSubmit: {}), appearance: appearance
        )
        save(image, name: "panel-banner-accessibility-\(appearance == .aqua ? "light" : "dark")")
        #expect(image.size == PanelMetrics.size)
        #expect(containsText("Pastu can't paste for you", in: content))
    }

    @Test(arguments: [NSAppearance.Name.darkAqua, .aqua])
    func panelRendersPausedBanner(appearance: NSAppearance.Name) async throws {
        let (image, content) = try await renderWindow(
            PanelView(model: try sampleModel(), canAutoPaste: true, isPaused: true, onSubmit: {}), appearance: appearance
        )
        save(image, name: "panel-banner-paused-\(appearance == .aqua ? "light" : "dark")")
        #expect(image.size == PanelMetrics.size)
        #expect(containsText("Recording is paused", in: content))
        #expect(!(containsText("Pastu can't paste for you", in: content)))
    }

    /// One banner at a time: missing Accessibility wins over a paused recording.
    @Test func panelShowsOnlyTheAccessibilityBannerWhenBothApply() async throws {
        let (image, content) = try await renderWindow(
            PanelView(model: try sampleModel(), canAutoPaste: false, isPaused: true, onSubmit: {})
        )
        save(image, name: "panel-banner-both")
        #expect(containsText("Pastu can't paste for you", in: content))
        #expect(!(containsText("Recording is paused", in: content)))
    }

    @Test func panelShowsNoBannerWhenAllIsWell() async throws {
        let (_, content) = try await renderWindow(PanelView(model: try sampleModel(), canAutoPaste: true, onSubmit: {}))
        #expect(!(containsText("Pastu can't paste for you", in: content)))
        #expect(!(containsText("Recording is paused", in: content)))
    }

    @Test func panelRendersLegacyFilterControl() async throws {
        let view = PanelView(model: try sampleModel(), canAutoPaste: true, isPaused: true, onSubmit: {})
            .environment(\.panelStyle, .legacy)
        let (image, content) = try await renderWindow(view, appearance: .aqua)
        save(image, name: "panel-banner-paused-legacy-light")
        #expect(containsText("Recording is paused", in: content))
    }

    @Test(arguments: [NSAppearance.Name.darkAqua, .aqua])
    func panelRendersLegacyStyle(appearance: NSAppearance.Name) async throws {
        let view = PanelView(model: try sampleModel(), canAutoPaste: true, onSubmit: {})
            .environment(\.panelStyle, .legacy)
        let (image, content) = try await renderWindow(view, appearance: appearance)
        save(image, name: "panel-legacy-\(appearance == .aqua ? "light" : "dark")")
        // Rounded shell: the window corner stays see-through.
        #expect(try alpha(in: image, atPoint: CGPoint(x: 2, y: 2)) == 0)
        #expect(try alpha(in: image, atPoint: headerCenter) > 0)
        // The capture shows a flat stand-in for the blur, so also check the fallback is the real view.
        #expect(containsVisualEffectView(content))
    }

    @Test(arguments: [NSAppearance.Name.darkAqua, .aqua])
    func panelRendersWithReduceTransparency(appearance: NSAppearance.Name) async throws {
        let view = PanelView(model: try sampleModel(), canAutoPaste: true, onSubmit: {})
            // The public key is read-only; SwiftUI's underscored twin is the writable override.
            .environment(\._accessibilityReduceTransparency, true)
        let image = try await render(view, appearance: appearance)
        save(image, name: "panel-reduce-transparency-\(appearance == .aqua ? "light" : "dark")")
        #expect(try alpha(in: image, atPoint: CGPoint(x: 2, y: 2)) == 0)
        // An opaque fill is drawn by cacheDisplay, so the header pixel must be fully covered.
        #expect(try alpha(in: image, atPoint: headerCenter) == 1)
    }

    /// The query sits deep inside a long clip, so its row shows a snippet around the match instead of "App · time".
    @Test(arguments: [NSAppearance.Name.darkAqua, .aqua])
    func panelRendersSearchSnippet(appearance: NSAppearance.Name) async throws {
        let store = try ClipStore()
        let now = Date()
        let filler = String(repeating: "Some filler words that pad out a long clip. ", count: 30)
        try store.insert(CapturedClip(
            text: filler + "The deploy keychain rotates every Tuesday at noon. " + filler,
            sourceBundleIdentifier: "com.apple.TextEdit", date: now.addingTimeInterval(-60)
        ))
        try store.insert(CapturedClip(
            text: "Log file rotates nightly", sourceBundleIdentifier: "com.apple.Terminal", date: now.addingTimeInterval(-3_600)
        ))
        let model = ClipListModel(store: store)
        model.query = "rotates"
        let selected = try #require(model.selectedClip)
        // Guards the setup: the match must be outside the title, or the row would not need a snippet.
        #expect(!ClipFormatting.rowTitle(selected.text).contains("rotates"))
        #expect(SearchHighlighter.snippet(of: model.query, in: selected.text) != nil)
        #expect(model.rowSnippet(for: selected) != nil)

        let (image, content) = try await renderWindow(
            PanelView(model: model, canAutoPaste: true, onSubmit: {}), appearance: appearance
        )
        save(image, name: "panel-search-snippet-\(appearance == .aqua ? "light" : "dark")")
        // Each row is one VoiceOver element labelled by the PastuCore builder.
        #expect(containsText("Text from TextEdit, 1 minute ago", in: content))
    }

    @Test(arguments: [NSAppearance.Name.darkAqua, .aqua])
    func panelRendersWithCommandHeld(appearance: NSAppearance.Name) async throws {
        let view = PanelView(
            model: try sampleModel(), canAutoPaste: true, onSubmit: {},
            commandKeys: CommandKeyMonitor(isCommandHeld: true)
        )
        let image = try await render(view, appearance: appearance)
        save(image, name: "panel-command-held-\(appearance == .aqua ? "light" : "dark")")
        #expect(image.size == PanelMetrics.size)
    }

    /// Rows on their own: selected (pinned), hovered, plain and a picture, in the list's width. Drawn on the opaque
    /// Reduce Transparency shell because the offscreen capture does not blend glass vibrancy, which would show the
    /// hover fill as solid white.
    @Test(arguments: [NSAppearance.Name.darkAqua, .aqua])
    func panelRendersSelectedAndHoverRows(appearance: NSAppearance.Name) async throws {
        let model = try sampleModel()
        let (pictures, loader) = try pictureSample()
        let clips = Array(model.clips.prefix(4)) + Array(pictures.clips.prefix(1))
        let rows = VStack(spacing: 2) {
            // By position: the two stores both number their clips from 1.
            ForEach(Array(clips.enumerated()), id: \.offset) { index, clip in
                ClipRow(
                    clip: clip, isSelected: index == 0, shortcutDigit: index + 1, showsShortcut: index == 0,
                    query: "", snippet: nil, imageData: loader, isHovered: index == 1
                )
            }
            Spacer()
        }
        .padding(PanelMetrics.contentInset)
        .frame(width: PanelMetrics.listWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .frame(width: PanelMetrics.size.width, height: PanelMetrics.size.height)
        .panelShell()
        .environment(\._accessibilityReduceTransparency, true)
        let (image, content) = try await renderWindow(rows, appearance: appearance)
        save(image, name: "panel-rows-selected-hover-\(appearance == .aqua ? "light" : "dark")")
        // Pinned clips sort first, so row 0 (selected) is the pinned Notes clip.
        let selected = try #require(accessibilityElement(containing: "Text from Notes", in: content))
        #expect(selected.accessibilityLabel?()?.hasSuffix("pinned") == true)
        #expect(selected.isAccessibilitySelected?() == true)
        let other = try #require(accessibilityElement(containing: "Text from Terminal", in: content))
        #expect(other.isAccessibilitySelected?() != true)
        #expect(containsText("1440 by 900", in: content))
    }

    @Test func panelRendersWithIncreasedContrast() async throws {
        // Over the opaque Reduce Transparency fill the stroke is the only difference, so compare the two.
        func shell(_ contrast: ColorSchemeContrast) throws -> some View {
            PanelView(model: try sampleModel(), canAutoPaste: true, onSubmit: {})
                .environment(\._accessibilityReduceTransparency, true)
                .environment(\._colorSchemeContrast, contrast)
        }
        let plain = try await render(try shell(.standard), appearance: .aqua)
        let image = try await render(try shell(.increased), appearance: .aqua)
        save(image, name: "panel-increased-contrast-light")
        #expect(try alpha(in: image, atPoint: CGPoint(x: 2, y: 2)) == 0)
        // The 1pt separator stroke sits on the shell's top edge.
        let edge = CGPoint(x: PanelMetrics.size.width / 2, y: 0.5)
        #expect(try color(in: image, atPoint: edge) != color(in: plain, atPoint: edge))
    }

    // MARK: Preview

    /// The preview's text, ranges and font are derived once per clip and query, not on every body evaluation.
    @Test func previewContentIsBuiltOncePerClipAndQuery() throws {
        let clip = StoredClip(
            id: 4_242, text: String(repeating: "lorem ipsum ", count: 1_000) + "needle", sourceBundleIdentifier: nil,
            firstCopiedAt: Date(), lastCopiedAt: Date(), copyCount: 1, isPinned: false, kind: .text
        )
        let before = PreviewContent.computations
        let first = PreviewContent.cached(for: clip, query: "needle")
        _ = PreviewContent.cached(for: clip, query: "needle")
        #expect(PreviewContent.computations == before + 1)
        #expect(first.scrollsToMatch)
        _ = PreviewContent.cached(for: clip, query: "lorem")
        #expect(PreviewContent.computations == before + 2)
        #expect(!PreviewContent.cached(for: clip, query: "lorem").scrollsToMatch)
    }

    /// The scroll anchor starts at the match's line; a long line is cut at a space shortly before the match.
    @Test func previewAnchorSplitsAtTheMatchLine() throws {
        let text = "first line\nsecond line has the needle"
        let match = try #require(text.range(of: "needle"))
        let split = try #require(PreviewContent.anchorSplit(in: text, firstMatch: match.lowerBound))
        #expect(text[..<split.headEnd] == "first line")
        #expect(text[split.tailStart...] == "second line has the needle")
        // On the first line, near the top: nothing to scroll to.
        #expect(PreviewContent.anchorSplit(in: "the needle", firstMatch: "the needle".index("the needle".startIndex, offsetBy: 4)) == nil)

        let long = String(repeating: "word ", count: 200) + "needle"
        let deep = try #require(long.range(of: "needle"))
        let cut = try #require(PreviewContent.anchorSplit(in: long, firstMatch: deep.lowerBound))
        let gap = long.distance(from: cut.tailStart, to: deep.lowerBound)
        #expect((120...130).contains(gap))
        #expect(long[cut.headEnd] == " ")

        // Minified JSON, base64 or a token: no space anywhere before the match, but it must still be reachable.
        let dense = String(repeating: "x", count: 1_500) + "needle" + String(repeating: "y", count: 200)
        let denseMatch = try #require(dense.range(of: "needle"))
        let denseCut = try #require(PreviewContent.anchorSplit(in: dense, firstMatch: denseMatch.lowerBound))
        #expect(denseCut.tailStart <= denseMatch.lowerBound)
        #expect(dense.distance(from: denseCut.tailStart, to: denseMatch.lowerBound) <= 130)
        #expect(denseCut.headEnd == denseCut.tailStart)
    }

    /// Hiding the panel forgets every clip's text and pictures held for drawing, so nothing deleted or cleared
    /// (⌘⌫, Clear History…, retention) lingers in memory.
    @Test func hidingThePanelPurgesPreviewAndPictureCaches() async throws {
        let (model, loader) = try pictureSample()
        let controller = PanelController(model: model, canAutoPaste: { true }, imageData: loader, onSelect: { _ in })
        controller.show()
        try await Task.sleep(for: .milliseconds(300))
        let text = try #require(model.clips.first { $0.kind == .text })
        _ = PreviewContent.cached(for: text, query: "launch")
        #expect(PreviewContent.cachedCount > 0)
        #expect(ImageCache.shared.entryCount > 0) // the rows drew their thumbnails

        controller.hide()
        #expect(PreviewContent.cachedCount == 0)
        #expect(ImageCache.shared.entryCount == 0)
        #expect(!ImageCache.shared.holdsFullImage)
    }

    /// ⌘⌫ purges at once too, while the panel stays open.
    @Test func deletingAClipPurgesTheCaches() async throws {
        let (model, loader) = try pictureSample()
        let controller = PanelController(model: model, canAutoPaste: { true }, imageData: loader, onSelect: { _ in })
        controller.show()
        defer { controller.hide() }
        try await Task.sleep(for: .milliseconds(300))
        #expect(ImageCache.shared.entryCount > 0)
        _ = PreviewContent.cached(for: try #require(model.selectedClip), query: "")
        controller.panel.onDeleteSelected?()
        #expect(PreviewContent.cachedCount == 0)
        #expect(ImageCache.shared.entryCount == 0)
    }

    private func appearanceName(_ appearance: NSAppearance.Name) -> String { appearance == .aqua ? "light" : "dark" }

    /// Preview snapshots use the opaque Reduce Transparency shell: the offscreen capture does not blend glass
    /// vibrancy, which would draw dark-mode text black on a see-through background.
    private func renderPreview(
        _ panel: PanelView, appearance: NSAppearance.Name
    ) async throws -> (image: NSImage, content: NSView) {
        try await renderWindow(panel.environment(\._accessibilityReduceTransparency, true), appearance: appearance)
    }

    /// A link clip shows its host as a heading and the full URL below it, both as their own lines.
    @Test(arguments: [NSAppearance.Name.darkAqua, .aqua])
    func previewRendersLinkParts(appearance: NSAppearance.Name) async throws {
        let model = try sampleModel()
        model.filter = .links
        let link = try #require(model.selectedClip)
        #expect(link.kind == .link)
        let (image, content) = try await renderPreview(
            PanelView(model: model, canAutoPaste: true, onSubmit: {}), appearance: appearance
        )
        save(image, name: "preview-link-\(appearanceName(appearance))")
        #expect(accessibilityElement(exactly: "developer.apple.com", in: content) != nil)
        #expect(accessibilityElement(exactly: "https://developer.apple.com/documentation/appkit/nspanel", in: content) != nil)
        #expect(containsText("Safari", in: content))
    }

    /// Prose is set in the body font; only code-like text is monospaced. The metadata grid replaces the old header.
    @Test(arguments: [NSAppearance.Name.darkAqua, .aqua])
    func previewRendersProseInBodyFont(appearance: NSAppearance.Name) async throws {
        let model = try sampleModel()
        let notes = try #require(model.selectedClip) // pinned, so first
        #expect(notes.sourceBundleIdentifier == "com.apple.Notes")
        #expect(!PreviewPane.usesMonospace(for: notes))
        let shell = StoredClip(
            id: 99, text: "$ swift build\n$ swift test --filter PanelSnapshotTests", sourceBundleIdentifier: nil,
            firstCopiedAt: Date(), lastCopiedAt: Date(), copyCount: 1, isPinned: false, kind: .text
        )
        #expect(PreviewPane.usesMonospace(for: shell))

        let (image, content) = try await renderPreview(
            PanelView(model: model, canAutoPaste: true, onSubmit: {}), appearance: appearance
        )
        save(image, name: "preview-text-\(appearanceName(appearance))")
        for label in ["Source", "Copied", "Size", "Pinned"] {
            #expect(accessibilityElement(exactly: label, in: content) != nil, "missing metadata label \(label)")
        }
        #expect(accessibilityElement(exactly: ClipFormatting.stats(notes.text), in: content) != nil)
    }

    /// A match past the 4,000-character cut: the preview shows a window around it with "…" markers on both ends.
    @Test(arguments: [NSAppearance.Name.darkAqua, .aqua])
    func previewRendersMatchBeyondLimit(appearance: NSAppearance.Name) async throws {
        let store = try ClipStore()
        let filler = String(repeating: "Some filler words that pad out a long clip.\n", count: 20)
        let text = filler + "Opening paragraph that only the start of the clip shows.\n"
            + String(repeating: filler, count: 10)
            + "The deploy keychain rotates every Tuesday at noon.\n"
            + String(repeating: filler, count: 10)
        try store.insert(CapturedClip(text: text, sourceBundleIdentifier: "com.apple.TextEdit", date: Date()))
        let model = ClipListModel(store: store)
        model.query = "keychain"
        #expect(model.selectedClip != nil)

        let (image, content) = try await renderPreview(
            PanelView(model: model, canAutoPaste: true, onSubmit: {}), appearance: appearance
        )
        save(image, name: "preview-match-beyond-limit-\(appearanceName(appearance))")
        #expect(containsText("The deploy keychain rotates every Tuesday at noon.", in: content))
        #expect(!containsText("Opening paragraph that only the start", in: content))
        #expect(containsText("earlier characters", in: content))
        #expect(containsText("more characters", in: content))
    }

    @Test(arguments: [NSAppearance.Name.darkAqua, .aqua])
    func previewRendersPicture(appearance: NSAppearance.Name) async throws {
        let (model, loader) = try pictureSample()
        let (image, content) = try await renderPreview(
            PanelView(model: model, canAutoPaste: true, onSubmit: {}, imageData: loader), appearance: appearance
        )
        save(image, name: "preview-picture-\(appearanceName(appearance))")
        #expect(containsText("1440×900 ·", in: content))
    }
}
}
