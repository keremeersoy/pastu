import Foundation

/// What a clip is, computed from its text (nothing is stored).
public enum ClipKind: Sendable, Equatable {
    case text
    case link

    /// Longer than this is never treated as a link: it is more likely a data blob than something to open.
    static let maxLinkLength = 2048

    /// Conservative: a clip is a link only when the whole text (ignoring surrounding whitespace) is a single
    /// http(s) URL with a host, or a mailto: address. A sentence that merely contains a URL stays text.
    public static func detect(_ text: String) -> ClipKind {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxLinkLength,
              !trimmed.contains(where: \.isWhitespace) else { return .text }

        let lower = trimmed.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            guard let host = URLComponents(string: trimmed)?.host, !host.isEmpty else { return .text }
            return .link
        }
        if lower.hasPrefix("mailto:") {
            let address = trimmed.dropFirst("mailto:".count).prefix { $0 != "?" }
            let parts = address.split(separator: "@", omittingEmptySubsequences: false)
            return parts.count == 2 && parts.allSatisfy { !$0.isEmpty } ? .link : .text
        }
        return .text
    }
}

/// The panel's type filter. Cycled with Tab: all, text, links.
public enum ClipFilter: Sendable, Equatable, CaseIterable {
    case all
    case text
    case links

    /// `nil` means "no restriction".
    public var kind: ClipKind? {
        switch self {
        case .all: nil
        case .text: .text
        case .links: .link
        }
    }

    public var next: ClipFilter {
        switch self {
        case .all: .text
        case .text: .links
        case .links: .all
        }
    }

    public var title: String {
        switch self {
        case .all: "All"
        case .text: "Text"
        case .links: "Links"
        }
    }
}
