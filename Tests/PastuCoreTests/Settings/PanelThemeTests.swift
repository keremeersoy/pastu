import Foundation
import Observation
import Testing
@testable import PastuCore

@MainActor
@Suite struct PanelThemeTests {
    // MARK: Defaults and persistence

    @Test func startsWithTheSystemLook() {
        let theme = ThemeSettings(store: InMemorySettings())
        #expect(theme.appearance == .system)
        #expect(theme.material == .glass)
    }

    @Test func choicesSurviveARelaunch() {
        let settings = InMemorySettings()
        let first = ThemeSettings(store: settings)
        first.appearance = .dark
        first.material = .solid

        let second = ThemeSettings(store: settings)
        #expect(second.appearance == .dark)
        #expect(second.material == .solid)
    }

    @Test func choicesAreStoredUnderTheirKeys() {
        let settings = InMemorySettings()
        let theme = ThemeSettings(store: settings)
        theme.appearance = .light
        theme.material = .frosted
        #expect(settings.string(forKey: "panelAppearance") == "light")
        #expect(settings.string(forKey: "panelMaterial") == "frosted")
    }

    @Test func unknownStoredValuesFallBackToTheDefaults() {
        let settings = InMemorySettings()
        settings.set("sepia", forKey: DefaultsKeys.panelAppearance)
        settings.set(42, forKey: DefaultsKeys.panelMaterial)
        let theme = ThemeSettings(store: settings)
        #expect(theme.appearance == .system)
        #expect(theme.material == .glass)
    }

    @Test func withoutAStoreChoicesLiveInMemoryOnly() {
        let theme = ThemeSettings()
        theme.appearance = .dark
        #expect(theme.appearance == .dark)
        #expect(ThemeSettings().appearance == .system)
    }

    // MARK: Resolving the material

    @Test func glassNeedsMacOS26AndFallsBackToFrosted() {
        #expect(PanelMaterial.glass.resolved(glassAvailable: true) == .glass)
        #expect(PanelMaterial.glass.resolved(glassAvailable: false) == .frosted)
    }

    @Test func otherMaterialsAreNeverChanged() {
        for available in [true, false] {
            #expect(PanelMaterial.frosted.resolved(glassAvailable: available) == .frosted)
            #expect(PanelMaterial.solid.resolved(glassAvailable: available) == .solid)
        }
    }

    @Test func glassIsOfferedOnlyWhereItExists() {
        #expect(PanelMaterial.choices(glassAvailable: true) == [.glass, .frosted, .solid])
        #expect(PanelMaterial.choices(glassAvailable: false) == [.frosted, .solid])
    }

    @Test func menuTitlesAreStable() {
        #expect(PanelAppearance.allCases.map(\.title) == ["System", "Light", "Dark"])
        #expect(PanelMaterial.allCases.map(\.title) == ["Liquid Glass", "Frosted", "Solid"])
    }
}

/// `onChange` runs synchronously on the thread that made the change, so a plain counter is safe here.
final class ChangeCounter: @unchecked Sendable { var count = 0 }

@MainActor
@Suite struct ThemeSettingsObservationTests {
    /// The settings window binds to `ThemeSettings`, so a change made elsewhere (the menu) must reach the view.
    @Test func changingTheAppearanceIsObservable() {
        let theme = ThemeSettings()
        let changes = ChangeCounter()
        withObservationTracking { _ = theme.appearance } onChange: { changes.count += 1 }
        theme.appearance = .dark
        #expect(changes.count == 1)
    }

    @Test func changingTheMaterialIsObservable() {
        let theme = ThemeSettings()
        let changes = ChangeCounter()
        withObservationTracking { _ = theme.material } onChange: { changes.count += 1 }
        theme.material = .solid
        #expect(changes.count == 1)
    }
}
