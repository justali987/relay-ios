import SwiftUI

/// Scans the local network for compatible devices. Populates incrementally as results arrive
/// (never a blocking spinner) and falls back to plain-language diagnostics after ~15 seconds of no
/// results — see docs/06-ux-screen-spec.md §2.
struct DiscoveryView: View {
    @Environment(AppState.self) private var appState

    private enum Phase: Equatable {
        case scanning
        case timedOut
    }

    @State private var phase: Phase = .scanning
    @State private var discoveredDevices: [DiscoveredDevice] = []
    @State private var pairingTarget: DiscoveredDevice?
    @State private var pairedDeviceAwaitingRoom: Device?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RelaySpacing.lg) {
                header

                ForEach(discoveredDevices) { device in
                    DiscoveredDeviceRow(device: device) {
                        pairingTarget = device
                    }
                }

                if phase == .timedOut {
                    DiagnosticsPanel(onRescan: restartScan)
                }
            }
            .padding(RelaySpacing.md)
        }
        .background(Color.relayBackground.ignoresSafeArea())
        .navigationTitle("Find Devices")
        .navigationBarTitleDisplayMode(.inline)
        .task { await runDiscovery() }
        .sheet(item: $pairingTarget) { target in
            PairingSheet(discovered: target) { paired in
                pairingTarget = nil
                pairedDeviceAwaitingRoom = paired
            }
        }
        .sheet(item: $pairedDeviceAwaitingRoom) { device in
            // Completing this sheet sets `appState.hasCompletedOnboarding`, which `RootView` is
            // observing — the whole onboarding stack is replaced by `MainTabView` automatically,
            // so there's nothing further to do here on completion.
            AssignRoomView(pairedDevice: device, onFinished: {})
                .environment(appState)
        }
    }

    private var header: some View {
        HStack(spacing: RelaySpacing.sm) {
            if phase == .scanning {
                ProgressView()
                Text("Scanning your network…")
                    .font(.relayBody)
                    .foregroundStyle(Color.relayTextSecondary)
            } else {
                Text("\(discoveredDevices.count) device(s) found")
                    .font(.relayBody)
                    .foregroundStyle(Color.relayTextSecondary)
            }
        }
    }

    private func runDiscovery() async {
        phase = .scanning
        discoveredDevices = []

        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            if discoveredDevices.isEmpty {
                phase = .timedOut
            }
        }

        for await device in appState.discoverAllDevices() {
            var updated = discoveredDevices
            updated.append(device)
            discoveredDevices = DiscoveryResult.merge(updated)
        }

        timeoutTask.cancel()
        if discoveredDevices.isEmpty {
            phase = .timedOut
        }
    }

    private func restartScan() {
        Task { await runDiscovery() }
    }
}

private struct DiscoveredDeviceRow: View {
    let device: DiscoveredDevice
    let onAdd: () -> Void

    var body: some View {
        CardContainer {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.relayBodyEmphasized)
                        .foregroundStyle(Color.relayTextPrimary)
                    Text(device.brand.displayName)
                        .font(.relayCaption)
                        .foregroundStyle(Color.relayTextSecondary)
                }
                Spacer()
                Button("Add", action: onAdd)
                    .buttonStyle(RelaySecondaryButtonStyle())
                    .fixedSize()
            }
        }
    }
}

private struct DiagnosticsPanel: View {
    let onRescan: () -> Void

    private let tips = [
        "Make sure your iPhone and TV are on the same Wi-Fi network.",
        "Turn off any VPN temporarily.",
        "Guest or isolated Wi-Fi networks block discovery — use your main network.",
        "Some TVs need network control enabled in their settings.",
    ]

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: RelaySpacing.md) {
                Text("No devices found yet")
                    .font(.relayHeadline)
                    .foregroundStyle(Color.relayTextPrimary)

                VStack(alignment: .leading, spacing: RelaySpacing.sm) {
                    ForEach(tips, id: \.self) { tip in
                        Label(tip, systemImage: "checkmark.circle")
                            .font(.relaySubheadline)
                            .foregroundStyle(Color.relayTextSecondary)
                    }
                }

                Button("Rescan", action: onRescan)
                    .buttonStyle(RelayPrimaryButtonStyle())

                NavigationLink("Add manually") {
                    ManualPairingView()
                }
                .buttonStyle(RelaySecondaryButtonStyle())
            }
        }
    }
}

#Preview {
    NavigationStack {
        DiscoveryView()
            .environment(AppState())
    }
}
