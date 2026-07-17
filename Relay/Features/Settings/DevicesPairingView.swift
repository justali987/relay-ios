import SwiftUI

/// Lists every paired device across all rooms with rename/remove/re-pair actions. See
/// docs/04-information-architecture.md Settings section.
struct DevicesPairingView: View {
    @Environment(AppState.self) private var appState
    @State private var renamingDevice: Device?
    @State private var renameText = ""

    var body: some View {
        List {
            ForEach(appState.rooms) { room in
                let devices = appState.devices(in: room.id)
                if !devices.isEmpty {
                    Section(room.name) {
                        ForEach(devices) { device in
                            row(for: device)
                        }
                    }
                }
            }

            if appState.devices.isEmpty {
                ContentUnavailableView(
                    "No Devices Paired",
                    systemImage: "tv.badge.wifi",
                    description: Text("Pair a device from the Home tab.")
                )
            }
        }
        .navigationTitle("Devices & Pairing")
        .alert("Rename Device", isPresented: Binding(
            get: { renamingDevice != nil },
            set: { if !$0 { renamingDevice = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if let device = renamingDevice {
                    Task { await rename(device, to: renameText) }
                }
            }
        }
    }

    private func row(for device: Device) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name).font(.relayBodyEmphasized)
                Text(device.brand.displayName)
                    .font(.relayCaption)
                    .foregroundStyle(Color.relayTextSecondary)
            }
            Spacer()
            StatusPill(status: device.status)
        }
        .swipeActions(edge: .trailing) {
            Button("Remove", role: .destructive) {
                Task { await appState.removeDevice(device.id) }
            }
        }
        .swipeActions(edge: .leading) {
            Button("Rename") {
                renamingDevice = device
                renameText = device.name
            }
            .tint(Color.relayAccent)
            Button("Re-pair") {
                Task { await appState.markNeedsRepairing(device.id) }
            }
            .tint(Color.relayStatusSleeping)
        }
    }

    private func rename(_ device: Device, to newName: String) async {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        await appState.renameDevice(device.id, to: trimmed)
    }
}
