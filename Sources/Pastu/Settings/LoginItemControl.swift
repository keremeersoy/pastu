import PastuCore
import SwiftUI

/// "Open Pastu at login": the switch plus the sentence that explains why it cannot be used, when it cannot.
/// Shared by the Settings window and the last step of the welcome guide, so both say the same thing.
struct LoginItemControl: View {
    let launchAtLogin: LaunchAtLogin
    /// Opens System Settings at Login Items; replaceable for tests.
    var openLoginItemsSettings: @MainActor () -> Void = SystemLoginItem.openLoginItemsSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Open Pastu at login", isOn: Binding(
                get: { launchAtLogin.isOn }, set: { launchAtLogin.setEnabled($0) }
            ))
            .disabled(!launchAtLogin.isAvailable)
            note
        }
        // The user can change the login item in System Settings while this is on screen.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            launchAtLogin.refresh()
        }
    }

    @ViewBuilder
    private var note: some View {
        if let message = launchAtLogin.errorMessage {
            Text(message).font(.footnote).foregroundStyle(.red)
        } else if !launchAtLogin.isAvailable {
            Text("Starting at login isn't available for this copy of Pastu. Move Pastu.app to your Applications folder.")
                .font(.footnote).foregroundStyle(.secondary)
        } else if launchAtLogin.needsApproval {
            VStack(alignment: .leading, spacing: 4) {
                Text("Allow Pastu in System Settings → General → Login Items to finish.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Open Login Items Settings", action: openLoginItemsSettings)
            }
        }
    }
}
