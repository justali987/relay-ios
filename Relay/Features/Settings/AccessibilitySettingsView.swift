import SwiftUI

/// Large-button mode, left-handed layout, simplified/guest mode, and haptics — these toggle
/// Relay-specific preferences; system-level Dynamic Type/Reduce Motion/Reduce Transparency are
/// respected automatically rather than reimplemented here. See docs/06-ux-screen-spec.md §11–12.
struct AccessibilitySettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var settings = appState.settings

        Form {
            Section {
                Toggle("Large Button Mode", isOn: $settings.largeButtonMode)
                Toggle("Left-Handed Layout", isOn: $settings.leftHandedLayout)
                Toggle("Haptic Feedback", isOn: $settings.hapticsEnabled)
            }

            Section {
                Toggle("Simplified / Guest Mode", isOn: $settings.simplifiedGuestMode)
            } footer: {
                Text("Shows a reduced remote with just power, volume, navigation, and home/back — no scenes, keyboard, or settings access.")
            }

            Section {
                Text("Relay follows your system Dynamic Type, Reduce Motion, and Reduce Transparency settings automatically. Adjust those in iOS Settings > Accessibility.")
                    .font(.relayCaption)
                    .foregroundStyle(Color.relayTextSecondary)
            }
        }
        .navigationTitle("Accessibility")
        .onChange(of: settings.hapticsEnabled) { _, newValue in
            HapticsHelper.shared.isEnabled = newValue
        }
    }
}
