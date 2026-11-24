import Testing
@testable import PastuCore

@Suite struct PanelBannerTests {
    @Test func bannerPriority() {
        #expect(PanelBanner.current(canAutoPaste: true, isPaused: false) == nil)
        #expect(PanelBanner.current(canAutoPaste: true, isPaused: true) == .recordingPaused)
        #expect(PanelBanner.current(canAutoPaste: false, isPaused: false) == .accessibilityMissing)
        #expect(PanelBanner.current(canAutoPaste: false, isPaused: true) == .accessibilityMissing)
    }
}
