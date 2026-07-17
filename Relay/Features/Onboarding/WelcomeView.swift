import SwiftUI

/// First screen shown on a fresh install. Local Network permission is NOT requested here — only
/// when the user taps "Find devices", which pushes into `DiscoveryView` and starts a scan (see
/// docs/06-ux-screen-spec.md §1).
struct WelcomeView: View {
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
                }
                .padding(.horizontal, RelaySpacing.lg)
                .padding(.bottom, RelaySpacing.xl)
            }
            .background(Color.relayBackground.ignoresSafeArea())
        }
    }
}

#Preview {
    WelcomeView()
        .environment(AppState())
}
