import SwiftUI

/// First screen shown on a fresh install. Local Network permission is NOT requested here — only
/// when the user taps "Find devices", which pushes into `DiscoveryView` and starts a scan (see
/// docs/06-ux-screen-spec.md §1).
///
/// Without a real device, "Find devices" and "Add a device manually" are both dead ends — Manual
/// Pairing excludes the mock brand, and Discovery excludes mock devices unless Demo Mode is on
/// (see `AppState.discoverAllDevices`). Demo Mode itself lives in Settings, which is only
/// reachable once onboarding completes — so without the button below, a user (or an App Review
/// tester) with no compatible TV has no way to ever get past this screen. See
/// docs/08-launch-runbook.md's App Review notes, which point here.
struct WelcomeView: View {
    @Environment(AppState.self) private var appState
    @State private var isDemoDiscoveryPresented = false

    var body: some View {
        NavigationStack {
            VStack(spacing: RelaySpacing.xl) {
                Spacer()

                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(Color.relayAccent)
                    .accessibilityHidden(true)

                VStack(spacing: RelaySpacing.sm) {
                    Text("Welcome to Relay")
                        .font(.relayLargeTitle)
                        .foregroundStyle(Color.relayTextPrimary)

                    Text("Relay finds compatible devices on your home Wi-Fi. Nothing leaves your home.")
                        .font(.relayBody)
                        .foregroundStyle(Color.relayTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, RelaySpacing.lg)
                }

                Spacer()

                VStack(spacing: RelaySpacing.md) {
                    NavigationLink {
                        DiscoveryView()
                    } label: {
                        Text("Find devices")
                    }
                    .buttonStyle(RelayPrimaryButtonStyle())

                    NavigationLink {
                        ManualPairingView()
                    } label: {
                        Text("Add a device manually")
                    }
                    .buttonStyle(RelaySecondaryButtonStyle())

                    Button {
                        appState.settings.demoModeEnabled = true
                        isDemoDiscoveryPresented = true
                    } label: {
                        Text("Don't have a device yet? Explore with a demo")
                            .font(.relayCaption)
                            .underline()
                    }
                    .foregroundStyle(Color.relayTextSecondary)
                    .padding(.top, RelaySpacing.xs)
                    .accessibilityHint("Turns on Demo Mode and shows simulated devices so you can try Relay without a real TV.")
                }
                .padding(.horizontal, RelaySpacing.lg)
                .padding(.bottom, RelaySpacing.xl)
            }
            .background(Color.relayBackground.ignoresSafeArea())
            .navigationDestination(isPresented: $isDemoDiscoveryPresented) {
                DiscoveryView()
            }
        }
    }
}

#Preview {
    WelcomeView()
        .environment(AppState())
}
