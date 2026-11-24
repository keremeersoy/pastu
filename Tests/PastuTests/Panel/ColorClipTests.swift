import AppKit
import SwiftUI
import Testing
@testable import Pastu
@testable import PastuCore

extension ShellTests {
@MainActor
@Suite struct ColorClipTests {
    private func clip(_ text: String) throws -> StoredClip {
        let store = try ClipStore()
        let id = try store.insert(CapturedClip(text: text, sourceBundleIdentifier: nil, date: Date()))
        return try #require(try store.recent().first { $0.id == id })
    }

    private func host(_ view: some View, size: CGSize) async throws -> NSView {
        enableAccessibilityTree()
        let hosting = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hosting
        window.orderFrontRegardless()
        try await Task.sleep(for: .milliseconds(300))
        return hosting
    }

    @Test func aColorRowIsSpokenWithItsChannels() async throws {
        let row = ClipRow(
            clip: try clip("#1e90ff"), isSelected: false, shortcutDigit: nil, showsShortcut: false, query: "",
            snippet: nil, imageData: { _ in nil }
        )
        let hosting = try await host(row, size: CGSize(width: 320, height: 60))
        defer { hosting.window?.orderOut(nil) }
        #expect(accessibilityElement(containing: "Color, red 30, green 144, blue 255", in: hosting) != nil)
    }

    @Test func anOrdinaryTextRowIsNotAColor() async throws {
        let row = ClipRow(
            clip: try clip("the sky is #1e90ff today"), isSelected: false, shortcutDigit: nil, showsShortcut: false,
            query: "", snippet: nil, imageData: { _ in nil }
        )
        let hosting = try await host(row, size: CGSize(width: 320, height: 60))
        defer { hosting.window?.orderOut(nil) }
        #expect(accessibilityElement(containing: "Color, red", in: hosting) == nil)
    }

    @Test func thePreviewShowsTheColorTwoWays() async throws {
        let preview = PreviewPane(clip: try clip("rgb(30, 144, 255)"), query: "", imageData: { _ in nil })
        let hosting = try await host(preview, size: CGSize(width: 440, height: 380))
        defer { hosting.window?.orderOut(nil) }
        #expect(accessibilityElement(containing: "#1E90FF", in: hosting) != nil)
        #expect(accessibilityElement(containing: "rgb(30, 144, 255)", in: hosting) != nil)
        #expect(accessibilityElement(containing: "Color, red 30", in: hosting) != nil)
    }

    @Test func aTextClipThatMentionsAColorKeepsItsTextPreview() async throws {
        let preview = PreviewPane(clip: try clip("use #1e90ff for links"), query: "", imageData: { _ in nil })
        let hosting = try await host(preview, size: CGSize(width: 440, height: 380))
        defer { hosting.window?.orderOut(nil) }
        #expect(accessibilityElement(containing: "use #1e90ff for links", in: hosting) != nil)
        #expect(accessibilityElement(containing: "Color, red", in: hosting) == nil)
    }
}
}
