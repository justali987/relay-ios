import SwiftUI

/// The 4-tab shell shown once onboarding is complete — see docs/04-information-architecture.md.
struct MainTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            NavigationStack {
                RoomListView()
            }
            .tabItem { Label("Home", systemImage: "house") }

            NavigationStack {
                ResumeRemoteView()
            }
            .tabItem { Label("Remote", systemImage: "appletvremote.gen1") }

            NavigationStack {
                SceneListView()
            }
            .tabItem { Label("Scenes", systemImage: "square.grid.2x2") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

/// The Remote tab's landing point: jumps straight to the last-used room's primary device, or an
/// empty state directing the user to Home if nothing has been used yet.
private struct ResumeRemoteView: View {
    @Environment(AppState.self) private var appState

    private var resumedDevice: Device? {
        guard let roomID = appState.lastUsedRoomID,
              let room = appState.rooms.first(where: { $0.id == roomID }),
              let primaryID = room.primaryDeviceID else { return nil }
        return appState.devices(in: roomID).first { $0.id == primaryID }
    }

    var body: some View {
        if let device = resumedDevice {
            RemoteView(deviceID: device.id)
        } else {
            ContentUnavailableView(
                "No Remote Yet",
                systemImage: "appletvremote.gen1",
                description: Text("Add a device from the Home tab to start controlling it here.")
            )
        }
    }
}
