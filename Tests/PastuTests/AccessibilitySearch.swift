import AppKit

/// SwiftUI only builds a hosting view's accessibility tree once an assistive client has announced itself, and only
/// for views hosted after that. Setting this attribute on the app is how such clients announce themselves, so call
/// this before creating the panel in a test that uses `accessibilityElement(containing:in:)`.
@MainActor
func enableAccessibilityTree() {
    _ = NSApplication.shared
    for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
        NSApp.perform(
            NSSelectorFromString("accessibilitySetValue:forAttribute:"), with: NSNumber(value: true), with: attribute
        )
    }
}

/// Finds the first element in a view's accessibility tree whose label, title or value contains `text`. Lets shell tests
/// check what the panel shows, and press its buttons, without matching pixels or clicking at coordinates.
@MainActor
func accessibilityElement(containing text: String, in root: NSView) -> AnyObject? {
    func search(_ element: AnyObject, depth: Int) -> AnyObject? {
        guard depth < 40 else { return nil }
        // SwiftUI's nodes are plain NSObjects that implement the accessibility methods, so look them up dynamically.
        // `accessibilityValue` has several Objective-C signatures, so it goes through `perform` (static text keeps
        // its string there).
        let value = element.perform?(NSSelectorFromString("accessibilityValue"))?.takeUnretainedValue() as? String
        let strings = [element.accessibilityLabel?(), element.accessibilityTitle?(), value]
        if strings.contains(where: { $0?.contains(text) == true }) { return element }
        for child in element.accessibilityChildren?() ?? [] {
            if let found = search(child as AnyObject, depth: depth + 1) { return found }
        }
        return nil
    }
    return search(root, depth: 0)
}

/// Presses a button found with `accessibilityElement(containing:in:)`, the way VoiceOver does.
@MainActor
func accessibilityPress(_ element: AnyObject) -> Bool {
    element.accessibilityPerformPress?() ?? false
}
