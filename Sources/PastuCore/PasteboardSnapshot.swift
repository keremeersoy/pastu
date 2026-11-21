/// A point-in-time, UI-independent view of the pasteboard.
public struct PasteboardSnapshot: Equatable, Sendable {
    public var types: [String]
    public var text: String?
    public var sourceBundleIdentifier: String?

    public init(types: [String], text: String?, sourceBundleIdentifier: String? = nil) {
        self.types = types
        self.text = text
        self.sourceBundleIdentifier = sourceBundleIdentifier
    }
}
