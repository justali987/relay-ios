import SwiftUI

/// Create/edit a Quick Action: name, reorderable steps, add/remove. See
/// docs/06-ux-screen-spec.md §8.
struct SceneEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let roomID: UUID
    let existingQuickAction: QuickAction?

    @State private var name: String
    @State private var steps: [QuickActionStep]
    @State private var isAddingStep = false

    init(roomID: UUID, existingQuickAction: QuickAction?) {
        self.roomID = roomID
        self.existingQuickAction = existingQuickAction
        _name = State(initialValue: existingQuickAction?.name ?? "")
        _steps = State(initialValue: existingQuickAction?.steps ?? [])
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("e.g. Movie Night", text: $name)
            }

            Section("Steps") {
                if steps.isEmpty {
                    Text("No steps yet.")
                        .foregroundStyle(Color.relayTextSecondary)
                }
                ForEach(steps) { step in
                    StepRow(step: step, roomID: roomID)
                }
                .onDelete { steps.remove(atOffsets: $0) }
                .onMove { steps.move(fromOffsets: $0, toOffset: $1) }

                Button {
                    isAddingStep = true
                } label: {
                    Label("Add Step", systemImage: "plus.circle")
                }
            }

            if existingQuickAction != nil {
                Section {
                    Button("Delete Quick Action", role: .destructive) {
                        Task {
                            if let id = existingQuickAction?.id {
                                await appState.deleteQuickAction(id)
                            }
                            dismiss()
                        }
                    }
                }
            }
        }
        .navigationTitle(existingQuickAction == nil ? "New Quick Action" : "Edit Quick Action")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || steps.isEmpty)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
        }
        .sheet(isPresented: $isAddingStep) {
            AddStepView(roomID: roomID) { step in
                steps.append(step)
            }
        }
    }

    private func save() async {
        var action = existingQuickAction ?? QuickAction(name: "", roomID: roomID, sortOrder: appState.quickActions(in: roomID).count)
        action.name = name.trimmingCharacters(in: .whitespaces)
        action.steps = steps
        await appState.upsert(quickAction: action)
        dismiss()
    }
}

private struct StepRow: View {
    @Environment(AppState.self) private var appState
    let step: QuickActionStep
    let roomID: UUID

    private var deviceName: String {
        appState.devices(in: roomID).first { $0.id == step.deviceID }?.name ?? "Unknown device"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(deviceName)
                .font(.relayBodyEmphasized)
            Text(CommandCatalog.label(for: step.command))
                .font(.relayCaption)
                .foregroundStyle(Color.relayTextSecondary)
        }
    }
}

private struct AddStepView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let roomID: UUID
    let onAdd: (QuickActionStep) -> Void

    @State private var selectedDeviceID: UUID?
    @State private var selectedCommand: RemoteCommand?

    private var roomDevices: [Device] {
        appState.devices(in: roomID)
    }

    private var availableCommands: [RemoteCommand] {
        guard let device = roomDevices.first(where: { $0.id == selectedDeviceID }) else { return [] }
        return CommandCatalog.all.filter { device.supports($0.requiredCapability) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Device") {
                    Picker("Device", selection: $selectedDeviceID) {
                        Text("Choose a device").tag(UUID?.none)
                        ForEach(roomDevices) { device in
                            Text(device.name).tag(Optional(device.id))
                        }
                    }
                }

                if selectedDeviceID != nil {
                    Section("Command") {
                        ForEach(availableCommands, id: \.self) { command in
                            Button(CommandCatalog.label(for: command)) {
                                selectedCommand = command
                            }
                            .foregroundStyle(selectedCommand == command ? Color.relayAccent : Color.relayTextPrimary)
                        }
                    }
                }
            }
            .navigationTitle("Add Step")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let deviceID = selectedDeviceID, let command = selectedCommand else { return }
                        onAdd(QuickActionStep(deviceID: deviceID, command: command))
                        dismiss()
                    }
                    .disabled(selectedDeviceID == nil || selectedCommand == nil)
                }
            }
        }
    }
}

/// A curated, non-parameterized subset of `RemoteCommand` offered when building a Quick Action step
/// — commands that need free-form input (keyboard text, arbitrary input names) aren't offered here
/// since a Quick Action step should be a one-tap, unambiguous action.
enum CommandCatalog {
    static let all: [RemoteCommand] = [
        .powerToggle, .volumeUp, .volumeDown, .mute, .home, .back,
        .play, .pause, .rewind, .fastForward,
    ]

    static func label(for command: RemoteCommand) -> String {
        switch command {
        case .powerToggle: "Power toggle"
        case .volumeUp: "Volume up"
        case .volumeDown: "Volume down"
        case .mute: "Mute"
        case .home: "Home"
        case .back: "Back"
        case .play: "Play"
        case .pause: "Pause"
        case .rewind: "Rewind"
        case .fastForward: "Fast forward"
        default: "Command"
        }
    }
}
