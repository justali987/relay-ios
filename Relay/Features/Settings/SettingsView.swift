import SwiftUI

/// Settings hub — see docs/04-information-architecture.md.
struct SettingsView: View {
    var body: some View {
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
