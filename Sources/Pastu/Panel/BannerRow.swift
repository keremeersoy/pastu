import PastuCore
import SwiftUI

/// A one-line notice under the header with a single action, e.g. "Recording is paused  [Resume]".
/// It sits on a quiet fill so the text is not drawn straight on glass.
struct BannerRow: View {
    let banner: PanelBanner
    let action: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(message)
            Spacer(minLength: 8)
            Button(actionTitle, action: action)
                .controlSize(.small)
                .focusable(false)
        }
        .font(.callout)
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: PanelMetrics.innerRadius, style: .continuous))
        .padding(.horizontal, PanelMetrics.contentInset)
        .padding(.bottom, PanelMetrics.contentInset)
        .accessibilityElement(children: .contain)
    }

    private var symbol: String {
        switch banner {
        case .accessibilityMissing: "exclamationmark.triangle.fill"
        case .recordingPaused: "pause.circle"
        }
    }

    private var tint: Color {
        switch banner {
        case .accessibilityMissing: .orange
        case .recordingPaused: .secondary
        }
    }

    private var message: String {
        switch banner {
        case .accessibilityMissing: "Pastu can't paste for you"
        case .recordingPaused: "Recording is paused"
        }
    }

    private var actionTitle: String {
        switch banner {
        case .accessibilityMissing: "Enable…"
        case .recordingPaused: "Resume"
        }
    }
}
