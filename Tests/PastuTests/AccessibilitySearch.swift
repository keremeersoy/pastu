import AppKit

/// SwiftUI only builds a hosting view's accessibility tree once an assistive client has announced itself, and only
/// for views hosted after that. Setting this attribute on the app is how such clients announce themselves, so call
/// this before creating the panel in a test that uses `accessibilityElement(containing:in:)`.
/// The switch is process-wide and cannot be turned off again, so every later test in the run sees the tree too.
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

/// Presses a plain button found with `accessibilityElement(containing:in:)`, the way VoiceOver does.
/// Anything else (for example an AppKit segment, role AXRadioButton) is refused and returns false: pressing a
/// segment runs a short HIToolbox event loop whose wake-up `CFRunLoopStop` can land on the test runner's own
/// `CFRunLoopRun`, which ends the whole test process with exit 0 and silently skips the remaining tests.
@MainActor
func accessibilityPress(_ element: AnyObject) -> Bool {
    guard element.accessibilityRole?() == .button else { return false }
    return element.accessibilityPerformPress?() ?? false
}
