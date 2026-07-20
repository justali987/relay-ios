import SwiftUI

/// Scans the local network for compatible devices. Populates incrementally as results arrive
/// (never a blocking spinner) and falls back to plain-language diagnostics after ~15 seconds of no
/// results — see docs/06-ux-screen-spec.md §2.
struct DiscoveryView: View {
    @Environment(AppState.self) private var appState

    private enum Phase: Equatable {
        case scanning
        case found
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

    /// Was previously a two-way if/else that treated "found results" and "timed out empty" as the
    /// same branch — the "N device(s) found" text lived in the branch that only runs when the list
    /// is EMPTY, so it always read "0 device(s) found," and there was no phase to move to once
    /// scanning actually finished, so the spinner ran forever even after devices appeared.
    @ViewBuilder
    private var header: some View {
        switch phase {
        case .scanning:
            HStack(spacing: RelaySpacing.sm) {
                ProgressView()
                Text("Scanning your network…")
                    .font(.relayBody)
                    .foregroundStyle(Color.relayTextSecondary)
            }
        case .found:
            HStack {
                Text("\(discoveredDevices.count) device\(discoveredDevices.count == 1 ? "" : "s") found")
                    .font(.relayBody)
                    .foregroundStyle(Color.relayTextSecondary)
                Spacer()
                Button("Rescan", action: restartScan)
                    .font(.relayCaption)
                    .foregroundStyle(Color.relayAccent)
            }
        case .timedOut:
            EmptyView()
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
        phase = discoveredDevices.isEmpty ? .timedOut : .found
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
