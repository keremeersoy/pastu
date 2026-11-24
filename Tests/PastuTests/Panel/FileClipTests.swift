import AppKit
import SwiftUI
import Testing
import UniformTypeIdentifiers
@testable import Pastu
@testable import PastuCore

extension ShellTests {
@MainActor
@Suite struct FileClipTests {
    /// Real files in a temporary folder, so "still there" and "gone" both mean what they say.
    private func makeFiles(_ names: [String], missing: [String] = []) throws -> (paths: [String], cleanup: () -> Void) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pastu-fileclips-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var paths: [String] = []
        for name in names {
            let url = dir.appendingPathComponent(name)
            try Data("x".utf8).write(to: url)
            paths.append(url.path)
        }
        paths += missing.map { dir.appendingPathComponent($0).path }
        return (paths, { try? FileManager.default.removeItem(at: dir) })
    }

    private func fileClip(_ paths: [String]) throws -> StoredClip {
        let store = try ClipStore()
        let id = try store.insert(.files(paths: paths, sourceBundleIdentifier: "com.apple.finder", date: Date()))
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

    // MARK: Row

    @Test func aFileRowShowsTheNamesAndIsSpokenAsFiles() async throws {
        let (paths, cleanup) = try makeFiles(["Q3 report.pdf", "notes.txt"])
        defer { cleanup() }
        let row = ClipRow(
            clip: try fileClip(paths), isSelected: false, shortcutDigit: nil, showsShortcut: false, query: "",
            snippet: nil, imageData: { _ in nil }
        )
        let hosting = try await host(row, size: CGSize(width: 320, height: 60))
        defer { hosting.window?.orderOut(nil) }
        #expect(accessibilityElement(containing: "Files from Finder", in: hosting) != nil)
        #expect(accessibilityElement(containing: "2 files: Q3 report.pdf, notes.txt", in: hosting) != nil)
        #expect(accessibilityElement(containing: "[files]", in: hosting) == nil, "the storage key never shows")
    }

    @Test func aSingleFileIsSpokenInTheSingular() async throws {
        let (paths, cleanup) = try makeFiles(["one.txt"])
        defer { cleanup() }
        let row = ClipRow(
            clip: try fileClip(paths), isSelected: false, shortcutDigit: nil, showsShortcut: false, query: "",
            snippet: nil, imageData: { _ in nil }
        )
        let hosting = try await host(row, size: CGSize(width: 320, height: 60))
        defer { hosting.window?.orderOut(nil) }
        #expect(accessibilityElement(containing: "1 file: one.txt", in: hosting) != nil)
        #expect(accessibilityElement(containing: "1 files", in: hosting) == nil)
    }

    // MARK: Preview

    @Test func thePreviewListsEachFileWithItsFolder() async throws {
        let (paths, cleanup) = try makeFiles(["Q3 report.pdf", "notes.txt"])
        defer { cleanup() }
        let folder = (paths[0] as NSString).deletingLastPathComponent
        let preview = PreviewPane(clip: try fileClip(paths), query: "", imageData: { _ in nil })
        let hosting = try await host(preview, size: CGSize(width: 440, height: 380))
        defer { hosting.window?.orderOut(nil) }
        #expect(accessibilityElement(containing: "Q3 report.pdf", in: hosting) != nil)
        #expect(accessibilityElement(containing: "notes.txt", in: hosting) != nil)
        #expect(accessibilityElement(containing: (folder as NSString).abbreviatingWithTildeInPath, in: hosting) != nil)
        #expect(accessibilityElement(containing: "2 files", in: hosting) != nil, "the size line counts the files")
    }

    @Test func aFileThatIsGoneIsMarkedMissing() async throws {
        let (paths, cleanup) = try makeFiles(["here.txt"], missing: ["gone.txt"])
        defer { cleanup() }
        let preview = PreviewPane(clip: try fileClip(paths), query: "", imageData: { _ in nil })
        let hosting = try await host(preview, size: CGSize(width: 440, height: 380))
        defer { hosting.window?.orderOut(nil) }
        #expect(accessibilityElement(containing: "gone.txt, missing", in: hosting) != nil)
        #expect(accessibilityElement(containing: "here.txt, missing", in: hosting) == nil)
        #expect(accessibilityElement(containing: "here.txt, ", in: hosting) != nil)
    }

    @Test func aLongListIsCutWithACount() async throws {
        let (paths, cleanup) = try makeFiles((0..<60).map { "file \($0).txt" })
        defer { cleanup() }
        let preview = PreviewPane(clip: try fileClip(paths), query: "", imageData: { _ in nil })
        let hosting = try await host(preview, size: CGSize(width: 440, height: 380))
        defer { hosting.window?.orderOut(nil) }
        #expect(accessibilityElement(containing: "and \(60 - FilesPreview.visibleLimit) more", in: hosting) != nil)
    }

    // MARK: Filter and empty state

    @Test func theFilesFilterHasItsOwnEmptyMessage() async throws {
        let hosting = try await host(EmptyState(query: "", filter: .files), size: CGSize(width: 400, height: 300))
        defer { hosting.window?.orderOut(nil) }
        #expect(accessibilityElement(containing: "No files yet", in: hosting) != nil)
    }

    // MARK: Dragging

    @Test func oneFileIsDraggedAsAFile() throws {
        let (paths, cleanup) = try makeFiles(["one.txt"])
        defer { cleanup() }
        let provider = ClipDragItem.provider(for: try fileClip(paths), imageData: { _ in nil })
        #expect(provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier))
    }

    @Test func severalFilesAreDraggedAsTheirPaths() throws {
        let (paths, cleanup) = try makeFiles(["one.txt", "two.txt"])
        defer { cleanup() }
        let provider = ClipDragItem.provider(for: try fileClip(paths), imageData: { _ in nil })
        #expect(provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier))
        #expect(!provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier))
    }

    @Test func filesThatAreGoneDragNothing() throws {
        let provider = ClipDragItem.provider(for: try fileClip(["/no/such/dir/gone.txt"]), imageData: { _ in nil })
        #expect(provider.registeredTypeIdentifiers.isEmpty)
    }

    // MARK: Show in Finder

    @Test func showInFinderRevealsTheFilesThatStillExist() throws {
        let (paths, cleanup) = try makeFiles(["here.txt"], missing: ["gone.txt"])
        defer { cleanup() }
        var revealed: [URL] = []
        let finder = FinderReveal { revealed = $0 }
        #expect(finder.show(try fileClip(paths)) == true)
        #expect(revealed.map(\.path) == [paths[0]])
    }

    @Test func showInFinderDoesNothingWhenEverythingIsGone() throws {
        var called = false
        let finder = FinderReveal { _ in called = true }
        #expect(finder.show(try fileClip(["/no/such/dir/gone.txt"])) == false)
        #expect(!called)
    }

    @Test func showInFinderIgnoresOtherKinds() throws {
        let store = try ClipStore()
        let id = try store.insert(CapturedClip(text: "hello", sourceBundleIdentifier: nil, date: Date()))
        let clip = try #require(try store.recent().first { $0.id == id })
        var called = false
        #expect(FinderReveal { _ in called = true }.show(clip) == false)
        #expect(!called)
    }
}
}
