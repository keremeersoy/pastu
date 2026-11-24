import AppKit

/// `ClipboardSource` backed by the real `NSPasteboard.general`.
@MainActor
public final class SystemPasteboard: ClipboardSource {
    private let pasteboard: NSPasteboard

    /// - Parameter pasteboard: the real clipboard by default; tests pass a private one.
    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    public var changeCount: Int { pasteboard.changeCount }

    /// True when the user chose "Deny" for Pastu in System Settings (macOS 15.4+ pasteboard privacy).
    /// Pastu then cannot read anything, and the app should say so instead of failing silently.
    public var isAccessDenied: Bool {
        if #available(macOS 15.4, *) { return pasteboard.accessBehavior == .alwaysDeny }
        return false
    }

    /// Replaces the clipboard with text. Pasting from the panel is plain text unless the caller passes formatting.
    public func write(text: String, rtf: Data?, html: Data?) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        if let rtf { pasteboard.setData(rtf, forType: .rtf) }
        if let html { pasteboard.setData(html, forType: .html) }
    }

    /// Replaces the clipboard with files, as Finder does when they are copied.
    public func write(files: [URL]) {
        pasteboard.clearContents()
        pasteboard.writeObjects(files as [NSURL])
    }

    /// Writes the picture as PNG. Older apps that ask for TIFF still get one: the system converts on demand.
    public func write(imagePNG: Data) {
        pasteboard.clearContents()
        pasteboard.setData(imagePNG, forType: .png)
    }

    /// The picture is only read when the content is requested and there is no text (text wins), so a copy
    /// with text never pays for decoding an image it will not use.
    public func snapshot(includingContent: Bool) -> PasteboardSnapshot {
        var text: String?
        var imagePNG: Data?
        var rtf: Data?
        var html: Data?
        var fileURLs: [URL] = []
        if includingContent {
            fileURLs = readFileURLs()
            text = pasteboard.string(forType: .string)
            if !fileURLs.isEmpty {
                // The files are the copy; the text Finder adds is only their names.
            } else if text?.isEmpty ?? true {
                imagePNG = readPicture()
            } else {
                rtf = pasteboard.data(forType: .rtf)
                html = pasteboard.data(forType: .html)
            }
        }
        return PasteboardSnapshot(
            types: (pasteboard.types ?? []).map(\.rawValue),
            text: text,
            sourceBundleIdentifier: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            imagePNG: imagePNG,
            rtf: rtf,
            html: html,
            fileURLs: fileURLs
        )
    }

    /// Only real files: web addresses on the pasteboard are not file clips. A file reference
    /// (`file:///.file/id=…`) is turned into its path, so the clip survives a rename.
    private func readFileURLs() -> [URL] {
        let urls = pasteboard.readObjects(
            forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []
        var seen = Set<String>()
        return urls.map { ($0 as NSURL).filePathURL ?? $0 }.filter { seen.insert($0.path).inserted }
    }

    private func readPicture() -> Data? {
        for type in [NSPasteboard.PasteboardType.png, .tiff] {
            if let data = pasteboard.data(forType: type), let png = PNGConverter.png(from: data) { return png }
        }
        return nil
    }
}
