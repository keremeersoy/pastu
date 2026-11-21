import AppKit

/// `ClipboardSource` backed by the real `NSPasteboard.general`.
@MainActor
public final class SystemPasteboard: ClipboardSource {
    private let pasteboard = NSPasteboard.general

    public init() {}

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

    /// STUB: pictures are written in the next sub-step.
    public func write(imagePNG: Data) {}

    public func snapshot(includingContent: Bool) -> PasteboardSnapshot {
        PasteboardSnapshot(
            types: (pasteboard.types ?? []).map(\.rawValue),
            text: includingContent ? pasteboard.string(forType: .string) : nil,
            sourceBundleIdentifier: NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        )
    }
}
