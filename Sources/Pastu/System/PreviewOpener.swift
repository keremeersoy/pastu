import AppKit
import PastuCore

/// "Open in Preview" for picture clips: writes a copy of the PNG to a private temporary folder and opens it.
/// The files are copies of clips, so the folder is emptied at launch and on quit.
@MainActor
final class PreviewOpener {
    static let shared = PreviewOpener()

    private let directory: URL
    private let openFile: @MainActor (URL) -> Void

    init(
        directory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("Pastu-Open-In-Preview"),
        openFile: @escaping @MainActor (URL) -> Void = PreviewOpener.openInPreview
    ) {
        self.directory = directory
        self.openFile = openFile
    }

    /// Returns false for anything but a picture whose bytes can be read.
    @discardableResult
    func open(_ clip: StoredClip, imageData: (Int64) -> Data?) -> Bool {
        guard clip.kind == .image, let data = imageData(clip.id) else { return false }
        do {
            // Owner-only, like the history itself.
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]
            )
            let url = directory.appendingPathComponent("Pastu \(UUID().uuidString.prefix(8)).png")
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            openFile(url)
            return true
        } catch {
            NSLog("Pastu could not open a picture in Preview: \(error)")
            return false
        }
    }

    /// Removes every file this opener wrote.
    func cleanUp() {
        try? FileManager.default.removeItem(at: directory)
    }

    private static func openInPreview(_ url: URL) {
        let preview = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Preview")
        if let preview {
            NSWorkspace.shared.open([url], withApplicationAt: preview, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(url)
        }
    }
}
