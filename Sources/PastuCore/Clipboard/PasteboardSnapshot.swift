import Foundation

/// A point-in-time, UI-independent view of the pasteboard.
public struct PasteboardSnapshot: Equatable, Sendable {
    public var types: [String]
    public var text: String?
    public var sourceBundleIdentifier: String?
    /// The picture on the pasteboard as PNG, if any. Like `text`, only filled when the content is read.
    public var imagePNG: Data?
    /// The text's rich formatting, if the source offered it. Like `text`, only filled when the content is read.
    public var rtf: Data?
    public var html: Data?
    /// The files on the pasteboard (copied in Finder), empty when there are none. Only filled when the content is read.
    public var fileURLs: [URL]

    public init(
        types: [String], text: String?, sourceBundleIdentifier: String? = nil, imagePNG: Data? = nil,
        rtf: Data? = nil, html: Data? = nil, fileURLs: [URL] = []
    ) {
        self.types = types
        self.text = text
        self.sourceBundleIdentifier = sourceBundleIdentifier
        self.imagePNG = imagePNG
        self.rtf = rtf
        self.html = html
        self.fileURLs = fileURLs
    }
}
