import SwiftUI

/// Card grid of rooms — the app's Home destination. See docs/06-ux-screen-spec.md §4.
struct RoomListView: View {
    @Environment(AppState.self) private var appState
    @State private var isAddingRoom = false
    @State private var newRoomName = ""

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: RelaySpacing.md)]

    var body: some View {
        ScrollView {
            if appState.rooms.isEmpty {
                ContentUnavailableView(
                    "No Rooms Yet",
                    systemImage: "sofa",
                    description: Text("Add a room to start pairing devices.")
                )
                .padding(.top, RelaySpacing.xxl)
            } else {
                LazyVGrid(columns: columns, spacing: RelaySpacing.md) {
                    ForEach(appState.rooms) { room in
                        NavigationLink {
                            RoomDetailView(roomID: room.id)
                        } label: {
                            RoomCard(room: room)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(RelaySpacing.md)
            }
        }
        .background(Color.relayBackground.ignoresSafeArea())
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddingRoom = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add room")
            }
        }
        .alert("New Room", isPresented: $isAddingRoom) {
            TextField("Room name", text: $newRoomName)
            Button("Cancel", role: .cancel) { newRoomName = "" }
            Button("Add") {
                Task {
                    await appState.addRoom(named: newRoomName)
                    newRoomName = ""
                }
            }
            .disabled(newRoomName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}

private struct RoomCard: View {
    @Environment(AppState.self) private var appState
    let room: Room

    private var primaryDevice: Device? {
        guard let id = room.primaryDeviceID else { return nil }
        return appState.devices(in: room.id).first { $0.id == id }
    }

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: RelaySpacing.sm) {
                HStack {
                    Image(systemName: "tv")
                        .font(.title2)
                        .foregroundStyle(Color.relayAccent)
                    Spacer()
                    if let primaryDevice {
                        StatusPill(status: primaryDevice.status)
                    }
                }

                Text(room.name)
                    .font(.relayHeadline)
                    .foregroundStyle(Color.relayTextPrimary)

                Text(primaryDevice?.name ?? "No devices yet")
                    .font(.relayCaption)
                    .foregroundStyle(Color.relayTextSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    NavigationStack {
        RoomListView()
            .environment(AppState())
    }
}
