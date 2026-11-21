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

    public func write(text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
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
        if includingContent {
            text = pasteboard.string(forType: .string)
            if text?.isEmpty ?? true { imagePNG = readPicture() }
        }
        return PasteboardSnapshot(
            types: (pasteboard.types ?? []).map(\.rawValue),
            text: text,
            sourceBundleIdentifier: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            imagePNG: imagePNG
        )
    }

    private func readPicture() -> Data? {
        for type in [NSPasteboard.PasteboardType.png, .tiff] {
            if let data = pasteboard.data(forType: type), let png = PNGConverter.png(from: data) { return png }
        }
        return nil
    }
}
