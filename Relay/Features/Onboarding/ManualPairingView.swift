import SwiftUI

/// Manual pairing by brand + host, for when discovery fails or the user prefers to enter details
/// directly. Apple TV is shown but not selectable for pairing — it links to the Compatibility page
/// instead, per docs/03-feasibility-warnings.md.
struct ManualPairingView: View {
    @Environment(AppState.self) private var appState

    @State private var selectedBrand: DeviceBrand?
    @State private var host: String = ""
    @State private var deviceName: String = ""
    @State private var pairingTarget: DiscoveredDevice?
    @State private var pairedDeviceAwaitingRoom: Device?

    private var selectableBrands: [DeviceBrand] {
        DeviceBrand.allCases.filter { $0 != .mock }
    }

    var body: some View {
        Form {
            Section("Brand") {
                ForEach(selectableBrands) { brand in
                    Button {
                        handleSelection(of: brand)
                    } label: {
                        HStack {
                            Text(brand.displayName)
                                .foregroundStyle(Color.relayTextPrimary)
                            if brand.isExperimental {
                                Text("Experimental")
                                    .font(.relayCaption)
                                    .foregroundStyle(Color.relayStatusSleeping)
                            }
                            Spacer()
                            if selectedBrand == brand {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.relayAccent)
                            }
                        }
                    }
                }
            }

            if let selectedBrand, !selectedBrand.isControlSupported {
                Section {
                    Text("Apple TV isn't controllable by Relay due to Apple's platform restrictions.")
                        .font(.relaySubheadline)
                        .foregroundStyle(Color.relayTextSecondary)
                    NavigationLink("See what Relay can control") {
                        CompatibilityPageView()
                    }
                }
            } else if let selectedBrand {
                Section("Device details") {
                    TextField("Name (optional)", text: $deviceName)
                    TextField("IP address", text: $host)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                if selectedBrand.isExperimental {
                    Section {
                        Text("Fire TV support is experimental — some or all controls may not work on your model.")
                            .font(.relaySubheadline)
                            .foregroundStyle(Color.relayTextSecondary)
                    }
                }

                Section {
                    Button("Continue") { beginPairing(brand: selectedBrand) }
                        .disabled(host.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .navigationTitle("Manual Pairing")
        .sheet(item: $pairingTarget) { target in
            PairingSheet(discovered: target) { paired in
                pairingTarget = nil
                pairedDeviceAwaitingRoom = paired
            }
        }
        .sheet(item: $pairedDeviceAwaitingRoom) { device in
            AssignRoomView(pairedDevice: device, onFinished: {})
                .environment(appState)
        }
    }

    private func handleSelection(of brand: DeviceBrand) {
        selectedBrand = brand
        host = ""
        deviceName = ""
    }

    private func beginPairing(brand: DeviceBrand) {
        let name = deviceName.trimmingCharacters(in: .whitespaces)
        pairingTarget = DiscoveredDevice(
            id: UUID().uuidString,
            name: name.isEmpty ? brand.displayName : name,
            brand: brand,
            host: host.trimmingCharacters(in: .whitespaces),
            rawIdentifiers: []
        )
    }
}

#Preview {
    NavigationStack {
        ManualPairingView()
            .environment(AppState())
    }
}
