import PastuCore
import SwiftUI

/// The Settings window's content: starting at login and the panel theme. Later settings get their own sections.
struct SettingsView: View {
    let theme: ThemeSettings
    let launchAtLogin: LaunchAtLogin
    let hotKeys: HotKeySettings
    let recorder: ShortcutRecorder
    let glassAvailable: Bool
    /// Opens System Settings at Login Items; replaceable for tests.
    var openLoginItemsSettings: @MainActor () -> Void = SystemLoginItem.openLoginItemsSettings

    var body: some View {
        @Bindable var theme = theme
        Form {
            Section("General") {
                Toggle("Open Pastu at login", isOn: Binding(
                    get: { launchAtLogin.isOn }, set: { launchAtLogin.setEnabled($0) }
                ))
                .disabled(!launchAtLogin.isAvailable)
                loginNote
            }
            Section("Shortcut") {
                LabeledContent("Show Pastu") {
                    HStack {
                        Button(recorder.isRecording ? "Type shortcut…" : hotKeys.combo.displayString) {
                            recorder.isRecording ? recorder.stop() : recorder.start()
                        }
                        .accessibilityLabel("Shortcut")
                        .accessibilityValue(recorder.isRecording ? "Recording" : hotKeys.combo.displayString)
                        if hotKeys.combo != .default {
                            Button("Reset") { hotKeys.reset() }
                        }
                    }
                }
                if let message = hotKeys.errorMessage {
                    Text(message).font(.footnote).foregroundStyle(.red)
                } else {
                    Text(recorder.isRecording ? "Press the new shortcut, or Esc to cancel." : "Click the shortcut to change it.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
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
        // The user can change the login item in System Settings while this window is open.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            launchAtLogin.refresh()
        }
        // Recording ends with the window: a shortcut left suspended would stop working.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in recorder.stop() }
        .onDisappear { recorder.stop() }
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var loginNote: some View {
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

    private func materialBinding(_ stored: Binding<PanelMaterial>) -> Binding<PanelMaterial> {
        Binding(
            get: { stored.wrappedValue.resolved(glassAvailable: glassAvailable) },
            set: { stored.wrappedValue = $0 }
        )
    }
}
