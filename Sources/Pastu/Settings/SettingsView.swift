import PastuCore
import SwiftUI

/// The Settings window's content. For now only the panel theme; later settings get their own sections.
struct SettingsView: View {
    let theme: ThemeSettings
    let glassAvailable: Bool

    var body: some View {
        @Bindable var theme = theme
        Form {
            Section("Appearance") {
                Picker("Appearance", selection: $theme.appearance) {
                    ForEach(PanelAppearance.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                // A stored Liquid Glass choice is drawn as Frosted where glass does not exist: show what is drawn.
                Picker("Material", selection: materialBinding($theme.material)) {
                    ForEach(PanelMaterial.choices(glassAvailable: glassAvailable), id: \.self) { Text($0.title).tag($0) }
                }
                Text("Reduce Transparency in System Settings always gives a solid background.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func materialBinding(_ stored: Binding<PanelMaterial>) -> Binding<PanelMaterial> {
        Binding(
            get: { stored.wrappedValue.resolved(glassAvailable: glassAvailable) },
            set: { stored.wrappedValue = $0 }
        )
    }
}
