import SwiftUI

/// How the panel shell is drawn. One value so tests on a macOS 26 machine can also render the macOS 15 look.
enum PanelStyle: Sendable {
    /// Liquid Glass (macOS 26+).
    case glass
    /// A behind-window `NSVisualEffectView` (macOS 15).
    case legacy

    static var system: PanelStyle {
        if #available(macOS 26, *) { .glass } else { .legacy }
    }
}

extension EnvironmentValues {
    @Entry var panelStyle: PanelStyle = .system
}

extension View {
    /// The rounded panel background: glass or a visual-effect view, an opaque fill with Reduce Transparency,
    /// and a separator stroke with Increase Contrast.
    func panelShell() -> some View {
        modifier(PanelShellModifier())
    }

    /// On glass, soften scrolled content where it passes under the header and footer.
    func panelScrollEdges() -> some View {
        modifier(PanelScrollEdgesModifier())
    }
}

private struct PanelShellModifier: ViewModifier {
    @Environment(\.panelStyle) private var style
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PanelMetrics.cornerRadius, style: .continuous)
    }

    func body(content: Content) -> some View {
        background(content.clipShape(shape))
            .overlay {
                if contrast == .increased {
                    shape.strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                }
            }
    }

    @ViewBuilder
    private func background(_ content: some View) -> some View {
        if reduceTransparency {
            content.background(Color(nsColor: .windowBackgroundColor), in: shape)
        } else if style == .glass, #available(macOS 26, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content.background {
                VisualEffectBackground(cornerRadius: PanelMetrics.cornerRadius)
            }
        }
    }
}

private struct PanelScrollEdgesModifier: ViewModifier {
    @Environment(\.panelStyle) private var style

    func body(content: Content) -> some View {
        if style == .glass, #available(macOS 26, *) {
            content.scrollEdgeEffectStyle(.soft, for: .vertical)
        } else {
            content
        }
    }
}
