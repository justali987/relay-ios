import Foundation

/// Local-only persistence for rooms and devices — no account, no cloud sync (see PRD "Non-goals").
/// Backed by a JSON file in the app's Application Support directory. All mutation happens through
/// this actor so `RelayApp`'s in-memory `AppState` and disk state never drift apart.
actor DeviceStore {
    private struct Snapshot: Codable {
        var rooms: [Room]
        var devices: [Device]
        var quickActions: [QuickAction] = []
    }

    private let fileURL: URL
    private var snapshot: Snapshot

    init(fileURL: URL? = nil) {
        let resolvedURL = fileURL ?? DeviceStore.defaultFileURL()
        self.fileURL = resolvedURL
        self.snapshot = (try? Self.load(from: resolvedURL)) ?? Snapshot(rooms: [], devices: [], quickActions: [])
    }

    private static func defaultFileURL() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Relay", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("devices.json")
    }

    private static func load(from url: URL) throws -> Snapshot {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Snapshot.self, from: data)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Rooms

    func allRooms() -> [Room] { snapshot.rooms }

    func upsert(room: Room) {
        if let index = snapshot.rooms.firstIndex(where: { $0.id == room.id }) {
            snapshot.rooms[index] = room
        } else {
            snapshot.rooms.append(room)
        }
        persist()
    }

    func deleteRoom(id: UUID) {
        snapshot.rooms.removeAll { $0.id == id }
        for index in snapshot.devices.indices where snapshot.devices[index].roomID == id {
            snapshot.devices[index].roomID = nil
        }
        persist()
    }

    // MARK: - Devices

    func allDevices() -> [Device] { snapshot.devices }

    func device(id: UUID) -> Device? {
        snapshot.devices.first { $0.id == id }
    }

    func upsert(device: Device) {
        if let index = snapshot.devices.firstIndex(where: { $0.id == device.id }) {
            snapshot.devices[index] = device
        } else {
            snapshot.devices.append(device)
        }
        persist()
    }

    func deleteDevice(id: UUID) {
        snapshot.devices.removeAll { $0.id == id }
        for index in snapshot.rooms.indices {
            snapshot.rooms[index].deviceIDs.removeAll { $0 == id }
            if snapshot.rooms[index].primaryDeviceID == id {
                snapshot.rooms[index].primaryDeviceID = nil
            }
        }
        persist()
    }

    func devices(in roomID: UUID) -> [Device] {
        snapshot.devices.filter { $0.roomID == roomID }
    }

    // MARK: - Quick Actions

    func allQuickActions() -> [QuickAction] { snapshot.quickActions }

    func upsert(quickAction: QuickAction) {
        if let index = snapshot.quickActions.firstIndex(where: { $0.id == quickAction.id }) {
            snapshot.quickActions[index] = quickAction
        } else {
            snapshot.quickActions.append(quickAction)
        }
        persist()
    }

    func deleteQuickAction(id: UUID) {
        snapshot.quickActions.removeAll { $0.id == id }
        persist()
    }
}
