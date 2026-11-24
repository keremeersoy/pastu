import PastuCore
import SwiftUI

// One small view per section of the Settings window, so `SettingsView` reads as the list of sections.

/// A short explanation under a setting.
private struct Hint: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(.footnote).foregroundStyle(.secondary)
    }
}

struct GeneralSection: View {
    let launchAtLogin: LaunchAtLogin
    let showWelcome: () -> Void

    var body: some View {
        Section("General") {
            LoginItemControl(launchAtLogin: launchAtLogin)
            Button("Show Welcome Guide…", action: showWelcome)
        }
    }
}

struct ShortcutSection: View {
    let hotKeys: HotKeySettings
    let recorder: ShortcutRecorder

    var body: some View {
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
                Hint(recorder.isRecording ? "Press the new shortcut, or Esc to cancel." : "Click the shortcut to change it.")
            }
        }
    }
}

struct HistorySection: View {
    let retention: RetentionSettings

    var body: some View {
        @Bindable var retention = retention
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
            Hint("Clips over a limit are deleted the next time Pastu saves a copy or starts. Pinned clips are never deleted.")
        }
    }
}

struct SearchSection: View {
    let pictureText: PictureTextSettings
    let onEnabled: () -> Void

    var body: some View {
        @Bindable var pictureText = pictureText
        Section("Search") {
            Toggle("Find text in pictures", isOn: $pictureText.isEnabled)
                .onChange(of: pictureText.isEnabled) { if pictureText.isEnabled { onEnabled() } }
            Hint("Screenshots and pictures are read on this Mac (nothing is sent anywhere), so you can search for the words in them.")
        }
    }
}

struct PasteQueueSection: View {
    let queue: QueueSettings

    var body: some View {
        @Bindable var queue = queue
        Section("Paste Queue") {
            Picker("Between clips", selection: $queue.separator) {
                ForEach(QueueSeparator.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Hint("⌥↩ adds the selected clip to the queue, ⌘↩ pastes the queue one clip after another.")
        }
    }
}

struct IgnoredAppsSection: View {
    let ignoredApps: IgnoredApps

    var body: some View {
        Section("Ignored Apps") {
            if ignoredApps.sortedIdentifiers.isEmpty {
                Hint("None. Press ⌘I on a clip in the panel, or add an app here.")
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
            Hint("Copies from these apps are never read or saved.")
        }
    }
}

struct AppearanceSection: View {
    let theme: ThemeSettings
    let glassAvailable: Bool

    var body: some View {
        @Bindable var theme = theme
        Section("Appearance") {
            Picker("Appearance", selection: $theme.appearance) {
                ForEach(PanelAppearance.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            // A stored Liquid Glass choice is drawn as Frosted where glass does not exist: show what is drawn.
            Picker("Material", selection: Binding(
                get: { theme.material.resolved(glassAvailable: glassAvailable) },
                set: { theme.material = $0 }
            )) {
                ForEach(PanelMaterial.choices(glassAvailable: glassAvailable), id: \.self) { Text($0.title).tag($0) }
            }
            Hint("Reduce Transparency in System Settings always gives a solid background.")
        }
    }
}
