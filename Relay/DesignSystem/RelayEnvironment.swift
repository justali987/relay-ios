import SwiftUI

/// Environment plumbing for the two Accessibility settings that affect the Remote screen's control
/// styling directly, so `RelayRemoteControlButtonStyle` (and any other component) can read them
/// without every call site threading `AppSettings` through by hand. `RemoteView` is what actually
/// sets these from `appState.settings`.
private struct LargeButtonModeKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Scales up remote control targets beyond their already-larger-than-minimum default size —
    /// see `AppSettings.largeButtonMode`. Currently applies to the circular
    /// `RelayRemoteControlButtonStyle` controls (power, input, playback, volume, home/back/menu);
    /// the D-pad ring and color-key row are sized separately in their own views.
    var relayLargeButtonMode: Bool {
        get { self[LargeButtonModeKey.self] }
        set { self[LargeButtonModeKey.self] = newValue }
    }
}
