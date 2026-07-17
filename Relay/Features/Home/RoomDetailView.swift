import SwiftUI

/// Devices in one room plus its scoped Quick Actions — see docs/06-ux-screen-spec.md §5.
struct RoomDetailView: View {
    @Environment(AppState.self) private var appState
    let roomID: UUID

    private var room: Room? {
        appState.rooms.first { $0.id == roomID }
    }

    private var roomDevices: [Device] {
        appState.devices(in: roomID)
    }

    private var roomQuickActions: [QuickAction] {
        appState.quickActions(in: roomID)
    }

    var body: some View {
        List {
            Section("Devices") {
                if roomDevices.isEmpty {
                    ContentUnavailableView(
                        "No Devices Yet",
                        systemImage: "tv.badge.wifi",
                        description: Text("Pair a device from the Home tab's discovery flow to add it here.")
                    )
                } else {
                    ForEach(roomDevices) { device in
                        NavigationLink {
                            RemoteView(deviceID: device.id)
                        } label: {
                            DeviceCardView(device: device, isPrimary: device.id == room?.primaryDeviceID)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing) {
                            Button("Remove", role: .destructive) {
                                Task { await appState.removeDevice(device.id) }
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if device.id != room?.primaryDeviceID {
                                Button("Make Primary") {
                                    Task { await appState.setPrimary(device.id, inRoom: roomID) }
                                }
                                .tint(Color.relayAccent)
                            }
                        }
                    }
                }
            }

            if !roomQuickActions.isEmpty {
                Section("Quick Actions") {
                    ForEach(roomQuickActions) { action in
                        QuickActionRow(quickAction: action)
                    }
                }
            }
        }
        .navigationTitle(room?.name ?? "Room")
        .onAppear {
            appState.markLastUsed(room: roomID)
        }
    }
}
