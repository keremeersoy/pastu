import PastuCore
import SwiftUI

extension Color {
    init(_ value: ColorValue) {
        self.init(.sRGB, red: Double(value.red) / 255, green: Double(value.green) / 255, blue: Double(value.blue) / 255, opacity: value.alpha)
    }
}

/// A small rounded swatch of a colour clip, in the same 28×22 slot a picture's thumbnail uses.
struct ColorSwatchView: View {
    let color: ColorValue

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color(color))
            .frame(width: 28, height: 22)
            // A see-through colour needs something to be seen against; the outline also keeps white visible.
            .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(.quaternary))
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(.quaternary))
            .accessibilityHidden(true)
    }
}

/// The preview of a colour clip: a big swatch and the colour written two ways, ready to select and copy.
struct ColorPreview: View {
    let color: ColorValue

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(color))
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.quaternary))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.quaternary))
                .frame(maxWidth: .infinity, minHeight: 90, maxHeight: 140)
                .accessibilityLabel(color.spokenDescription)
            VStack(alignment: .leading, spacing: 3) {
                Text(color.hexString)
                Text(color.rgbString).foregroundStyle(.secondary)
            }
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
