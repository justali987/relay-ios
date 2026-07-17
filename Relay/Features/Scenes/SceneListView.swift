import SwiftUI

/// All Quick Actions across every room, grouped by room, plus entry points to add/edit. See
/// docs/06-ux-screen-spec.md §8. (Named "Scenes" in navigation to match the household mental model
/// — the underlying type is `QuickAction`, not SwiftUI's `Scene`.)
struct SceneListView: View {
    @Environment(AppState.self) private var appState
    @State private var isAddingAction = false

    var body: some View {
        List {
            ForEach(appState.rooms) { room in
                let actions = appState.quickActions(in: room.id)
                if !actions.isEmpty {
                    Section(room.name) {
                        ForEach(actions) { action in
                            NavigationLink {
                                SceneEditorView(roomID: room.id, existingQuickAction: action)
                            } label: {
                                QuickActionRow(quickAction: action)
                            }
                        }
                    }
                }
            }

            if appState.quickActions.isEmpty {
                ContentUnavailableView(
                    "No Quick Actions Yet",
                    systemImage: "square.grid.2x2",
                    description: Text("Create one to control several devices with a single tap.")
                )
            }
        }
        .navigationTitle("Scenes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddingAction = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(appState.rooms.isEmpty)
                .accessibilityLabel("Add Quick Action")
            }
        }
        .sheet(isPresented: $isAddingAction) {
            NavigationStack {
                if let firstRoom = appState.rooms.first {
                    SceneEditorView(roomID: firstRoom.id, existingQuickAction: nil)
                }
            }
        }
    }
}
