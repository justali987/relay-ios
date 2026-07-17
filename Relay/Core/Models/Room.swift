import Foundation

/// A household room ("Living Room", "Bedroom"). Rooms hold references to `Device.id`s rather than
/// embedding devices, so a device's live status always comes from a single source of truth
/// (`DeviceStore`).
struct Room: Identifiable, Codable, Sendable, Equatable, Hashable {
    let id: UUID
    var name: String
    var deviceIDs: [UUID]
    var primaryDeviceID: UUID?

    init(id: UUID = UUID(), name: String, deviceIDs: [UUID] = [], primaryDeviceID: UUID? = nil) {
        self.id = id
        self.name = name
        self.deviceIDs = deviceIDs
        self.primaryDeviceID = primaryDeviceID
    }
}
