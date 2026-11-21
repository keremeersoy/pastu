import SwiftUI

extension View {
    /// Liquid Glass only on the panel shell (macOS 26+), a material on older systems.
    @ViewBuilder
    func panelShell() -> some View {
        let shape = RoundedRectangle(cornerRadius: 18)
        if #available(macOS 26, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.regularMaterial, in: shape)
        }
    }
}
