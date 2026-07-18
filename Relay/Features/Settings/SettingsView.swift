import SwiftUI

/// Settings hub — see docs/04-information-architecture.md.
struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var settings = appState.settings

        List {
            Section {
                NavigationLink("Devices & Pairing") { DevicesPairingView() }
                NavigationLink("Accessibility") { AccessibilitySettingsView() }
                NavigationLink("Privacy") { PrivacySettingsView() }
            }

            Section {
                NavigationLink("Relay Plus") { RelayPlusView() }
            }

            Section {
                Toggle("Demo Mode", isOn: $settings.demoModeEnabled)
            } footer: {
                Text("Adds simulated devices so you can explore Relay without a real TV. Turn this on, then tap Find devices on the Home tab.")
            }

            Section {
                NavigationLink("Compatibility") { CompatibilityPageView() }
                NavigationLink("About & Support") { AboutSupportView() }
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(AppState())
    }
}
