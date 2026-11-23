import PastuCore
import SwiftUI

/// The Settings window's content: starting at login and the panel theme. Later settings get their own sections.
struct SettingsView: View {
    let theme: ThemeSettings
    let launchAtLogin: LaunchAtLogin
    let hotKeys: HotKeySettings
    let retention: RetentionSettings
    let ignoredApps: IgnoredApps
    let recorder: ShortcutRecorder
    let glassAvailable: Bool
    /// Opens System Settings at Login Items; replaceable for tests.
    var openLoginItemsSettings: @MainActor () -> Void = SystemLoginItem.openLoginItemsSettings

    var body: some View {
        @Bindable var theme = theme
        @Bindable var retention = retention
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
            Section("History") {
                Picker("Keep up to", selection: $retention.count) {
                    ForEach(RetentionSettings.countChoices, id: \.self) { Text(RetentionSettings.countTitle($0)).tag($0) }
                }
                Picker("Keep for", selection: $retention.age) {
                    ForEach(RetentionSettings.ageChoices, id: \.self) { Text(RetentionSettings.ageTitle($0)).tag($0) }
                }
                Picker("Size limit", selection: $retention.size) {
                    ForEach(RetentionSettings.sizeChoices, id: \.self) { Text(RetentionSettings.sizeTitle($0)).tag($0) }
                }
                Text("Clips over a limit are deleted the next time Pastu saves a copy or starts. Pinned clips are never deleted.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Ignored Apps") {
                if ignoredApps.sortedIdentifiers.isEmpty {
                    Text("None. Press ⌘I on a clip in the panel, or add an app here.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(ignoredApps.sortedIdentifiers, id: \.self) { id in
                    let name = AppLookup.name(for: id) ?? id
                    LabeledContent {
                        Button("Remove") { ignoredApps.remove(id) }
                            .accessibilityLabel("Stop ignoring \(id)")
                    } label: {
                        Text(name)
                        if name != id { Text(id).font(.footnote).foregroundStyle(.secondary) }
                    }
                }
                Button("Add App…") {
                    if let id = IgnoredAppChoice.chooseApp() { ignoredApps.add(id) }
                }
                Text("Copies from these apps are never read or saved.")
                    .font(.footnote).foregroundStyle(.secondary)
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
