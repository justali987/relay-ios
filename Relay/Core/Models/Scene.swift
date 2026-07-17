import Foundation

// Named `QuickAction`, not `Scene` — SwiftUI already defines a `Scene` protocol for app scenes
// (WindowGroup, etc.) and reusing the name would collide across the codebase.

/// One step within a Quick Action: a single command sent to a single device.
struct QuickActionStep: Identifiable, Codable, Sendable, Equatable, Hashable {
    let id: UUID
    var deviceID: UUID
    var command: RemoteCommand

    init(id: UUID = UUID(), deviceID: UUID, command: RemoteCommand) {
        self.id = id
        self.deviceID = deviceID
        self.command = command
    }
}

/// A user-defined multi-device action ("Movie night", "Mute all"). Running one always reports a
/// per-device result — never a single blanket success/failure — see docs/06-ux-screen-spec.md §8.
struct QuickAction: Identifiable, Codable, Sendable, Equatable, Hashable {
    let id: UUID
    var name: String
    var roomID: UUID?
    var steps: [QuickActionStep]
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        name: String,
        roomID: UUID? = nil,
        steps: [QuickActionStep] = [],
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.roomID = roomID
        self.steps = steps
        self.sortOrder = sortOrder
    }
}

/// The outcome of running one step of a `QuickAction`, keyed for the per-device result list.
struct QuickActionStepResult: Identifiable, Sendable, Equatable {
    let id: UUID
    let deviceID: UUID
    let deviceName: String
    let succeeded: Bool
    let failureReason: String?

    init(deviceID: UUID, deviceName: String, succeeded: Bool, failureReason: String? = nil) {
        self.id = UUID()
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.succeeded = succeeded
        self.failureReason = failureReason
    }
}
