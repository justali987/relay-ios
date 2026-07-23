import SwiftUI

/// Shared pairing flow used by both Discovery and Manual Pairing. Attempts to pair without a code
/// first; if the adapter reports `pairingCodeRequired`, switches to a PIN entry state — this is how
/// Relay supports both no-pairing-needed adapters (Roku) and on-screen-code adapters (webOS,
/// Tizen) with one screen. See docs/06-ux-screen-spec.md §3.
struct PairingSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let discovered: DiscoveredDevice
    var onPaired: (Device) -> Void

    @State private var code: String = ""
    @State private var isPairing = true
    @State private var needsCode = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: RelaySpacing.lg) {
                Spacer()

                Image(systemName: needsCode ? "number" : "wifi")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.relayAccent)

                if needsCode {
                    VStack(spacing: RelaySpacing.sm) {
                        // `discovered.name` is untrusted device-supplied text (e.g. Roku's
                        // friendly-device-name, readable from any device on the LAN). Interpolating
                        // it into a string literal binds to LocalizedStringKey, which SwiftUI
                        // parses as Markdown — a crafted name like "[tap here](evil.url)" would
                        // render as a styled, tappable link. `verbatim:` renders it as plain text.
                        Text(verbatim: "Enter the code shown on \(discovered.name)")
                            .font(.relayHeadline)
                            .multilineTextAlignment(.center)
                        TextField("PIN", text: $code)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(.relayTitle)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 160)
                    }
                } else if isPairing {
                    VStack(spacing: RelaySpacing.sm) {
                        Text(verbatim: "Pairing with \(discovered.name)…")
                            .font(.relayHeadline)
                            .multilineTextAlignment(.center)
                        if discovered.brand.requiresOnScreenApproval {
                            // webOS/Tizen show an "Allow this device?" prompt on the TV; without this
                            // hint the user just sees a spinner and doesn't know to accept it.
                            Text("Look at your TV and choose Allow if it asks to let Relay connect.")
                                .font(.relaySubheadline)
                                .foregroundStyle(Color.relayTextSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.relaySubheadline)
                        .foregroundStyle(Color.relayStatusUnavailable)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                if needsCode || errorMessage != nil {
                    Button(needsCode ? "Pair" : "Try again") {
                        Task { await attemptPair() }
                    }
                    .buttonStyle(RelayPrimaryButtonStyle())
                    .disabled(needsCode && code.isEmpty)
                }
            }
            .padding(RelaySpacing.lg)
            .background(Color.relayBackground.ignoresSafeArea())
            .navigationTitle("Pair Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await attemptPair() }
        }
        .interactiveDismissDisabled(isPairing)
    }

    private func attemptPair() async {
        isPairing = true
        errorMessage = nil

        do {
            let device = try await appState.pair(discovered, code: needsCode ? code : nil)
            isPairing = false
            onPaired(device)
        } catch AdapterError.pairingCodeRequired {
            needsCode = true
            isPairing = false
        } catch AdapterError.pairingRejected(let reason) {
            errorMessage = reason
            isPairing = false
        } catch AdapterError.unreachable {
            errorMessage = "Couldn't reach \(discovered.name). Make sure it's powered on and connected."
            isPairing = false
        } catch AdapterError.notImplemented {
            // Defensive — the UI shouldn't offer this path for a brand where isImplemented is
            // false (see ManualPairingView), but never surface "try again" for something that can
            // never succeed.
            errorMessage = "\(discovered.brand.displayName) support isn't available in this version of Relay yet."
            isPairing = false
        } catch {
            errorMessage = "Pairing failed. Please try again."
            isPairing = false
        }
    }
}
