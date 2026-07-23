import SwiftUI

/// Static, in-app mirror of docs/02-capability-matrix.md and docs/03-feasibility-warnings.md. This
/// is the single place Relay commits to plain-language honesty about what it can and can't
/// control — no unverified compatibility claims (see PRD).
struct CompatibilityPageView: View {
    var body: some View {
        List {
            Section {
                Text(
                    "Relay controls devices over your home Wi-Fi network. iPhones have no infrared emitter, " +
                    "so Relay can't act as a traditional IR remote — every device below is controlled over " +
                    "the network, and support depends on that device's own network features."
                )
                .font(.relaySubheadline)
                .foregroundStyle(Color.relayTextSecondary)
            }

            ForEach(DeviceBrand.allCases.filter { $0 != .mock }) { brand in
                Section(brand.displayName) {
                    if !brand.isControlSupported {
                        Label("Not controllable by Relay", systemImage: "xmark.circle")
                            .foregroundStyle(Color.relayStatusUnavailable)
                        Text(unsupportedExplanation(for: brand))
                            .font(.relayCaption)
                            .foregroundStyle(Color.relayTextSecondary)
                    } else if !brand.isImplemented {
                        // Architecturally controllable, but the adapter isn't built yet — never
                        // shown as "Supported" and never offered a pairing attempt that can only
                        // fail. See docs/03-feasibility-warnings.md.
                        Label("Coming soon", systemImage: "clock")
                            .foregroundStyle(Color.relayStatusSleeping)
                        Text(verbatim: "\(brand.displayName) support is planned but not yet built. " +
                            "Pairing isn't available for this brand in this version.")
                            .font(.relayCaption)
                            .foregroundStyle(Color.relayTextSecondary)
                    } else {
                        if brand.isExperimental {
                            Label("Experimental support", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(Color.relayStatusSleeping)
                        } else {
                            Label("Supported", systemImage: "checkmark.circle")
                                .foregroundStyle(Color.relayStatusConnected)
                        }
                        ForEach(DeviceCapability.allCases, id: \.self) { capability in
                            HStack {
                                Text(capability.displayName)
                                Spacer()
                                Text(supportLevel(for: capability, brand: brand))
                                    .foregroundStyle(Color.relayTextSecondary)
                            }
                            .font(.relayCaption)
                        }
                    }
                }
            }

            Section("Power-on / wake") {
                Text(
                    "Turning a device on over Wi-Fi depends on that device's own network standby setting, " +
                    "which is often off by default and varies by model. Relay will attempt it where " +
                    "supported, but can't guarantee it works on every TV."
                )
                .font(.relayCaption)
                .foregroundStyle(Color.relayTextSecondary)
            }
        }
        .navigationTitle("Compatibility")
    }

    private func unsupportedExplanation(for brand: DeviceBrand) -> String {
        switch brand {
        case .appleTV:
            "Apple doesn't provide a public API for third-party apps to control an Apple TV the way " +
            "other platforms allow, so Relay can't offer direct control."
        default:
            "Not currently supported."
        }
    }

    /// Mirrors docs/02-capability-matrix.md — "Supported", "Model-dependent", or "Not supported".
    private func supportLevel(for capability: DeviceCapability, brand: DeviceBrand) -> String {
        switch (brand, capability) {
        case (.roku, .colorKeys):
            "Not supported"
        // Samsung's adapter drives keys over `SendRemoteKey`; text entry, app launch, input
        // selection and touchpad use separate Tizen channels not implemented in this version, so the
        // matrix must not claim them (see TizenAdapter's capability set).
        case (.samsungTizen, .keyboardInput), (.samsungTizen, .appLaunch),
             (.samsungTizen, .inputSelect), (.samsungTizen, .touchpad):
            "Not supported"
        case (.samsungTizen, .colorKeys):
            "Supported"
        case (.roku, .powerOn), (.lgWebOS, .powerOn), (.samsungTizen, .powerOn):
            "Model-dependent"
        case (.googleTV, _), (.fireTV, _):
            "Model-dependent"
        case (_, .colorKeys):
            "Model-dependent"
        default:
            "Supported"
        }
    }
}

#Preview {
    NavigationStack {
        CompatibilityPageView()
    }
}
