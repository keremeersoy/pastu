import PastuCore
import SwiftUI

/// The three steps of the welcome guide. Plain, calm and short; every step can be skipped with Continue.
struct OnboardingView: View {
    let onboarding: Onboarding
    let hotKeys: HotKeySettings
    let launchAtLogin: LaunchAtLogin
    let isTrusted: () -> Bool
    let requestAccessibility: () -> Void
    let openAccessibilitySettings: () -> Void
    let finish: () -> Void

    @State private var trusted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(onboarding.step.title).font(.title2.bold())
            content
            Spacer(minLength: 0)
            HStack {
                StepDots(current: onboarding.step.rawValue, count: Onboarding.Step.allCases.count)
                Spacer()
                if !onboarding.isFirstStep { Button("Back") { onboarding.back() } }
                if onboarding.isLastStep {
                    Button("Done", action: finish).keyboardShortcut(.defaultAction)
                } else {
                    Button("Continue") { onboarding.next() }.keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .frame(width: 460, height: 320)
        .onAppear { trusted = isTrusted() }
        // The user flips the switch in System Settings and comes back: show it without a click.
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in trusted = isTrusted() }
    }

    @ViewBuilder
    private var content: some View {
        switch onboarding.step {
        case .welcome:
            VStack(alignment: .leading, spacing: 12) {
                Text("Pastu remembers what you copy, text and pictures, and keeps it on your Mac only.")
                Text("Press \(hotKeys.combo.displayString) anywhere to open your history, type to search, press Return to paste.")
                Text("Nothing is sent over the network, and copies marked secret (password managers) are never saved.")
                    .foregroundStyle(.secondary)
            }
        case .pasting:
            VStack(alignment: .leading, spacing: 12) {
                Text("To paste into the app you are using, macOS needs your OK under Accessibility.")
                if trusted {
                    Label("Pastu can paste for you.", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                } else {
                    HStack {
                        Button("Allow Access…", action: requestAccessibility)
                        Button("Open System Settings", action: openAccessibilitySettings)
                    }
                    Text("You can skip this: Pastu then copies the clip and you press ⌘V yourself.")
                        .foregroundStyle(.secondary)
                }
            }
        case .ready:
            VStack(alignment: .leading, spacing: 12) {
                Text("Pastu lives in the menu bar. Press \(hotKeys.combo.displayString) to try it. Settings are in the menu.")
                Toggle("Open Pastu at login", isOn: Binding(
                    get: { launchAtLogin.isOn }, set: { launchAtLogin.setEnabled($0) }
                ))
                .disabled(!launchAtLogin.isAvailable)
            }
        }
    }
}

private struct StepDots: View {
    let current: Int
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Circle().fill(index == current ? Color.accentColor : Color.secondary.opacity(0.3)).frame(width: 7, height: 7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current + 1) of \(count)")
    }
}
