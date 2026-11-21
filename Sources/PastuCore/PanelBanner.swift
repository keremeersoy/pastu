/// The single banner the panel shows above the list, if any.
public enum PanelBanner: Equatable, Sendable {
    case accessibilityMissing
    case recordingPaused

    /// Only one banner at a time: missing Accessibility permission wins because it blocks pasting,
    /// while a paused recording is something the user chose.
    public static func current(canAutoPaste: Bool, isPaused: Bool) -> PanelBanner? {
        if !canAutoPaste { return .accessibilityMissing }
        if isPaused { return .recordingPaused }
        return nil
    }
}
