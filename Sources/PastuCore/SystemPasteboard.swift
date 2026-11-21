import AppKit

/// `ClipboardSource` backed by the real `NSPasteboard.general`.
@MainActor
public final class SystemPasteboard: ClipboardSource {
    private let pasteboard = NSPasteboard.general

    public init() {}

    public var changeCount: Int { pasteboard.changeCount }

    public func write(text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    public func snapshot() -> PasteboardSnapshot {
        PasteboardSnapshot(
            types: (pasteboard.types ?? []).map(\.rawValue),
            text: pasteboard.string(forType: .string),
            sourceBundleIdentifier: NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        )
    }
}
