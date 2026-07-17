import SwiftUI

/// Shown right after a successful pairing (from either Discovery or Manual Pairing) to assign the
/// new device to a room, creating one if this is the user's first device. Completing this step
/// finishes onboarding — see docs/04-information-architecture.md first-launch flow.
struct AssignRoomView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let pairedDevice: Device
    /// Called after the device has been assigned and onboarding is complete, so the presenting
    /// view can pop back to the root.
    var onFinished: () -> Void

    @State private var selectedRoomID: UUID?
    @State private var newRoomName: String = ""
    @State private var isCreatingNewRoom: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Add \(pairedDevice.name) to a room") {
                    ForEach(appState.rooms) { room in
                        Button {
                            selectedRoomID = room.id
                            isCreatingNewRoom = false
                        } label: {
                            HStack {
                                Text(room.name)
                                    .foregroundStyle(Color.relayTextPrimary)
                                Spacer()
                                if selectedRoomID == room.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.relayAccent)
                                }
                            }
                        }
                    }

                    Button {
                        isCreatingNewRoom = true
                        selectedRoomID = nil
                    } label: {
                        Label("New room", systemImage: "plus.circle")
                    }
                }

                if isCreatingNewRoom {
                    Section("Room name") {
                        TextField("e.g. Living Room", text: $newRoomName)
                    }
                }
            }
            .navigationTitle("Assign Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { Task { await finish() } }
                        .disabled(!canFinish)
                }
            }
            .onAppear {
                if appState.rooms.isEmpty {
                    isCreatingNewRoom = true
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private var canFinish: Bool {
        selectedRoomID != nil || (isCreatingNewRoom && !newRoomName.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    private func finish() async {
        let roomID: UUID
        if isCreatingNewRoom {
            let name = newRoomName.trimmingCharacters(in: .whitespaces)
            let created = await appState.addRoom(named: name)
            roomID = created.id
        } else if let selectedRoomID {
            roomID = selectedRoomID
        } else {
            return
        }

        await appState.addPairedDevice(pairedDevice, toRoom: roomID)
        appState.markLastUsed(room: roomID)
        appState.completeOnboarding()
        onFinished()
    }
}
