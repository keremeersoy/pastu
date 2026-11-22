import SwiftUI

/// Turns search match ranges into styled text, shared by list rows and the preview so both emphasize matches alike.
enum MatchHighlight {
    /// Matches in semibold `font`. On the accent fill (a selected row) they are also underlined and full white,
    /// because a colored background behind the match would fight the selection color; elsewhere an optional
    /// `background` tint makes them easy to spot in a long text.
    static func attributed(
        _ text: String, ranges: [Range<String.Index>], font: Font, onAccent: Bool = false, background: Color? = nil
    ) -> AttributedString {
        var attributed = AttributedString(text)
        for range in ranges {
            // Short-term ranges may end inside a grapheme; skip anything that does not map rather than trap.
            guard let target = Range(range, in: attributed) else { continue }
            attributed[target].font = font.weight(.semibold)
            if onAccent {
                attributed[target].foregroundColor = .white
                attributed[target].underlineStyle = .single
            } else {
                attributed[target].foregroundColor = .primary
                if let background { attributed[target].backgroundColor = background }
            }
        }
        return attributed
    }
}
