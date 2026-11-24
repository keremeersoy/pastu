import Foundation

/// A clip that is nothing but a CSS colour: `#1e90ff`, `rgb(30, 144, 255)`, `hsl(210 100% 56% / 50%)`.
/// The panel shows a swatch for it. Text around a colour does not count: only whole clips are colours.
public struct ColorValue: Equatable, Sendable {
    public let red: Int
    public let green: Int
    public let blue: Int
    public let alpha: Double

    /// Anything longer is prose, not a colour. Checked on the raw bytes first (constant time), so a row asking about a
    /// huge clip on every redraw costs nothing.
    static let maxBytes = 256
    static let maxLength = 64

    public init?(_ text: String) {
        guard text.utf8.count <= Self.maxBytes else { return nil }
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= Self.maxLength else { return nil }
        if text.hasPrefix("#") {
            guard let parsed = Self.parseHex(text.dropFirst()) else { return nil }
            self = parsed
        } else if let parsed = Self.parseFunction(text.lowercased()) {
            self = parsed
        } else {
            return nil
        }
    }

    private init(red: Int, green: Int, blue: Int, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    // MARK: Display

    /// `#RRGGBB`, with two more digits when the colour is see-through.
    public var hexString: String {
        let base = String(format: "#%02X%02X%02X", red, green, blue)
        return alpha < 1 ? base + String(format: "%02X", Int((alpha * 255).rounded())) : base
    }

    /// `rgb(30, 144, 255)`, or `rgba(…, 0.5)` when see-through.
    public var rgbString: String {
        guard alpha < 1 else { return "rgb(\(red), \(green), \(blue))" }
        return "rgba(\(red), \(green), \(blue), \(String(format: "%g", (alpha * 100).rounded() / 100)))"
    }

    public var spokenDescription: String {
        let base = "Color, red \(red), green \(green), blue \(blue)"
        return alpha < 1 ? base + ", \(Int((alpha * 100).rounded())) percent opaque" : base
    }

    // MARK: Parsing

    private static func parseHex(_ digits: Substring) -> ColorValue? {
        guard [3, 4, 6, 8].contains(digits.count), digits.allSatisfy({ $0.isASCII && $0.isHexDigit }) else { return nil }
        // #f80 means #ff8800: each digit is doubled.
        let full = digits.count <= 4 ? digits.flatMap { [$0, $0] } : Array(digits)
        var bytes: [Int] = []
        var index = 0
        while index < full.count {
            guard let byte = Int(String(full[index..<index + 2]), radix: 16) else { return nil }
            bytes.append(byte)
            index += 2
        }
        let alpha = bytes.count == 4 ? Double(bytes[3]) / 255 : 1
        return ColorValue(red: bytes[0], green: bytes[1], blue: bytes[2], alpha: alpha)
    }

    /// `rgb(…)`, `rgba(…)`, `hsl(…)` and `hsla(…)`, with commas or with spaces and a slash before the alpha.
    private static func parseFunction(_ text: String) -> ColorValue? {
        guard let open = text.firstIndex(of: "("), text.hasSuffix(")") else { return nil }
        let name = text[..<open]
        guard ["rgb", "rgba", "hsl", "hsla"].contains(name) else { return nil }
        let inner = text[text.index(after: open)..<text.index(before: text.endIndex)]
        let parts: [String]
        if inner.contains(",") {
            parts = inner.split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        } else {
            parts = inner.split(whereSeparator: { $0 == " " || $0 == "/" }).map(String.init)
        }
        guard parts.count == 3 || parts.count == 4, !parts.contains("") else { return nil }

        var alpha = 1.0
        if parts.count == 4 {
            guard let value = unitInterval(parts[3]) else { return nil }
            alpha = value
        }
        if name.hasPrefix("rgb") {
            guard let r = channel(parts[0]), let g = channel(parts[1]), let b = channel(parts[2]) else { return nil }
            return ColorValue(red: r, green: g, blue: b, alpha: alpha)
        }
        guard let hue = Double(parts[0]), let s = percentage(parts[1]), let l = percentage(parts[2]) else { return nil }
        let (r, g, b) = hslToRGB(hue: hue, saturation: s / 100, lightness: l / 100)
        return ColorValue(red: r, green: g, blue: b, alpha: alpha)
    }

    /// 0–255 as a whole number, or 0%–100%.
    private static func channel(_ text: String) -> Int? {
        if let percent = percentage(text) { return Int((percent / 100 * 255).rounded()) }
        guard let value = Int(text), (0...255).contains(value) else { return nil }
        return value
    }

    /// "50%" is 50; nil for anything else, or outside 0–100.
    private static func percentage(_ text: String) -> Double? {
        guard text.hasSuffix("%"), let value = Double(text.dropLast()), (0...100).contains(value) else { return nil }
        return value
    }

    /// An alpha: 0–1, or 0%–100%.
    private static func unitInterval(_ text: String) -> Double? {
        if let percent = percentage(text) { return percent / 100 }
        guard let value = Double(text), (0...1).contains(value) else { return nil }
        return value
    }

    private static func hslToRGB(hue: Double, saturation: Double, lightness: Double) -> (Int, Int, Int) {
        let h = hue.truncatingRemainder(dividingBy: 360) / 360
        let q = lightness < 0.5 ? lightness * (1 + saturation) : lightness + saturation - lightness * saturation
        let p = 2 * lightness - q
        func channel(_ offset: Double) -> Int {
            var t = h + offset
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            let value: Double
            switch t {
            case ..<(1.0 / 6): value = p + (q - p) * 6 * t
            case ..<0.5: value = q
            case ..<(2.0 / 3): value = p + (q - p) * (2.0 / 3 - t) * 6
            default: value = p
            }
            return Int((value * 255).rounded())
        }
        return (channel(1.0 / 3), channel(0), channel(-1.0 / 3))
    }
}
