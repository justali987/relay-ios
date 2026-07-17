import Foundation
import Observation

/// Top-level observable app state. Feature screens read/mutate through here rather than talking to
/// `DeviceStore`/`AdapterRegistry` directly, so there is one place that keeps in-memory state and
/// disk state from drifting apart.
@MainActor
@Observable
final class AppState {
    private(set) var rooms: [Room] = []
    private(set) var devices: [Device] = []
    private(set) var quickActions: [QuickAction] = []
    var lastUsedRoomID: UUID?
    var hasCompletedOnboarding: Bool

    let deviceStore: DeviceStore
    let tokenStore: KeychainTokenStore
    let adapterRegistry: AdapterRegistry
    let settings: AppSettings

    init(
        deviceStore: DeviceStore = DeviceStore(),
        tokenStore: KeychainTokenStore = KeychainTokenStore(),
        adapterRegistry: AdapterRegistry = .makeDefault(),
        settings: AppSettings = AppSettings()
    ) {
        self.deviceStore = deviceStore
        self.tokenStore = tokenStore
        self.adapterRegistry = adapterRegistry
        self.settings = settings
        self.hasCompletedOnboarding = settings.hasCompletedOnboarding
    }

    // MARK: - Load

    func loadFromDisk() async {
        rooms = await deviceStore.allRooms()
        devices = await deviceStore.allDevices()
        quickActions = await deviceStore.allQuickActions()
        lastUsedRoomID = settings.lastUsedRoomID
    }

    // MARK: - Rooms

    @discardableResult
    func addRoom(named name: String) async -> Room {
        let room = Room(name: name)
        rooms.append(room)
        await deviceStore.upsert(room: room)
        return room
    }

    func renameRoom(_ roomID: UUID, to name: String) async {
        guard let index = rooms.firstIndex(where: { $0.id == roomID }) else { return }
        rooms[index].name = name
        await deviceStore.upsert(room: rooms[index])
    }

    func deleteRoom(_ roomID: UUID) async {
        rooms.removeAll { $0.id == roomID }
        for index in devices.indices where devices[index].roomID == roomID {
            devices[index].roomID = nil
        }
        await deviceStore.deleteRoom(id: roomID)
        if lastUsedRoomID == roomID {
            lastUsedRoomID = nil
            settings.lastUsedRoomID = nil
        }
    }

    func devices(in roomID: UUID) -> [Device] {
        devices.filter { $0.roomID == roomID }
    }

    func markLastUsed(room roomID: UUID) {
        lastUsedRoomID = roomID
        settings.lastUsedRoomID = roomID
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        settings.hasCompletedOnboarding = true
    }

    // MARK: - Discovery

    /// Fans discovery out across every registered adapter (mock included) and forwards each result
    /// as it arrives, undeduplicated — the caller accumulates and runs `DiscoveryResult.merge` so
    /// the incremental "populate as found" UX (docs/06-ux-screen-spec.md §2) isn't blocked on a
    /// full merge pass.
    func discoverAllDevices() -> AsyncStream<DiscoveredDevice> {
        AsyncStream { continuation in
            let task = Task {
                let adapters = await adapterRegistry.allAdapters
                await withTaskGroup(of: Void.self) { group in
                    for adapter in adapters {
                        group.addTask {
                            for await device in adapter.discover() {
                                continuation.yield(device)
                            }
                        }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Pairing

    /// Pairs with a discovered device via its owning adapter. Does not add the device to any room —
    /// the caller (Discovery/Manual Pairing flow) still needs to assign a room before persisting it
    /// via `addPairedDevice`.
    func pair(_ discovered: DiscoveredDevice, code: String? = nil) async throws -> Device {
        guard let adapter = await adapterRegistry.adapter(for: discovered.brand) else {
            throw AdapterError.notPaired
        }
        return try await adapter.pair(with: discovered, code: code)
    }

    // MARK: - Devices

    /// Adds a freshly-paired device to a room, marking it primary if the room has none yet.
    func addPairedDevice(_ device: Device, toRoom roomID: UUID) async {
        var device = device
        device.roomID = roomID
        devices.append(device)
        await deviceStore.upsert(device: device)

        if let index = rooms.firstIndex(where: { $0.id == roomID }) {
            rooms[index].deviceIDs.append(device.id)
            if rooms[index].primaryDeviceID == nil {
                rooms[index].primaryDeviceID = device.id
            }
            await deviceStore.upsert(room: rooms[index])
        }
    }

    func renameDevice(_ deviceID: UUID, to name: String) async {
        guard let index = devices.firstIndex(where: { $0.id == deviceID }) else { return }
        devices[index].name = name
        await deviceStore.upsert(device: devices[index])
    }

    func addChannelFavorite(label: String, channelDigits: String, toDeviceID deviceID: UUID) async {
        guard let index = devices.firstIndex(where: { $0.id == deviceID }) else { return }
        devices[index].channelFavorites.append(ChannelFavorite(label: label, channelDigits: channelDigits))
        await deviceStore.upsert(device: devices[index])
    }

    func removeChannelFavorite(_ favoriteID: UUID, fromDeviceID deviceID: UUID) async {
        guard let index = devices.firstIndex(where: { $0.id == deviceID }) else { return }
        devices[index].channelFavorites.removeAll { $0.id == favoriteID }
        await deviceStore.upsert(device: devices[index])
    }

    func removeDevice(_ deviceID: UUID) async {
        devices.removeAll { $0.id == deviceID }
        await deviceStore.deleteDevice(id: deviceID)
        await tokenStore.removeToken(forDeviceID: deviceID)
        for index in rooms.indices {
            rooms[index].deviceIDs.removeAll { $0 == deviceID }
            if rooms[index].primaryDeviceID == deviceID {
                rooms[index].primaryDeviceID = nil
            }
        }
    }

    func setPrimary(_ deviceID: UUID, inRoom roomID: UUID) async {
        guard let index = rooms.firstIndex(where: { $0.id == roomID }) else { return }
        rooms[index].primaryDeviceID = deviceID
        await deviceStore.upsert(room: rooms[index])
    }

    /// Flags a device as needing to be paired again, without removing it from its room — used by
    /// the Reliability Center's "Re-pair Device" action. The user re-pairs via Manual Pairing;
    /// there's no in-place re-pair flow yet (see docs/07-implementation-plan.md milestone 7).
    func markNeedsRepairing(_ deviceID: UUID) async {
        guard let index = devices.firstIndex(where: { $0.id == deviceID }) else { return }
        devices[index].status = .needsPairing
        await deviceStore.upsert(device: devices[index])
        await tokenStore.removeToken(forDeviceID: deviceID)
    }

    /// Refreshes one device's live status from its owning adapter and persists the result.
    @discardableResult
    func refreshStatus(for deviceID: UUID) async -> ConnectionStatus? {
        guard let index = devices.firstIndex(where: { $0.id == deviceID }) else { return nil }
        let device = devices[index]
        guard let adapter = await adapterRegistry.adapter(for: device) else { return nil }

        let status = await adapter.checkHealth(device)
        devices[index].status = status
        devices[index].lastResponseAt = status == .connected ? Date() : device.lastResponseAt
        await deviceStore.upsert(device: devices[index])
        return status
    }

    /// Sends one command to a device, capability-gated at the call site (the UI should never offer
    /// a control the device doesn't support, but this guard exists so a programming mistake fails
    /// safely rather than silently).
    func send(_ command: RemoteCommand, toDeviceID deviceID: UUID) async throws {
        guard let device = devices.first(where: { $0.id == deviceID }) else {
            throw AdapterError.notPaired
        }
        guard let adapter = await adapterRegistry.adapter(for: device) else {
            throw AdapterError.notPaired
        }
        try await adapter.send(command, to: device)
    }

    /// Tunes to a saved channel favorite by sending its digits sequentially through the existing
    /// `.channelDigit` command — no adapter plumbing beyond `.channelControl` is needed for this.
    func tuneToFavorite(_ favorite: ChannelFavorite, onDeviceID deviceID: UUID) async throws {
        for character in favorite.channelDigits {
            guard let digit = character.wholeNumberValue else { continue }
            try await send(.channelDigit(digit), toDeviceID: deviceID)
        }
    }

    // MARK: - Quick Actions

    func quickActions(in roomID: UUID) -> [QuickAction] {
        quickActions.filter { $0.roomID == roomID }.sorted { $0.sortOrder < $1.sortOrder }
    }

    func upsert(quickAction: QuickAction) async {
        if let index = quickActions.firstIndex(where: { $0.id == quickAction.id }) {
            quickActions[index] = quickAction
        } else {
            quickActions.append(quickAction)
        }
        await deviceStore.upsert(quickAction: quickAction)
    }

    func deleteQuickAction(_ id: UUID) async {
        quickActions.removeAll { $0.id == id }
        await deviceStore.deleteQuickAction(id: id)
    }

    func reorderQuickActions(_ reordered: [QuickAction]) async {
        for (index, action) in reordered.enumerated() {
            var updated = action
            updated.sortOrder = index
            if let existingIndex = quickActions.firstIndex(where: { $0.id == action.id }) {
                quickActions[existingIndex] = updated
            }
            await deviceStore.upsert(quickAction: updated)
        }
    }

    /// Runs every step of a Quick Action and returns a per-device result — never a single blanket
    /// success/failure (see docs/06-ux-screen-spec.md §8).
    func run(_ quickAction: QuickAction) async -> [QuickActionStepResult] {
        var results: [QuickActionStepResult] = []
        for step in quickAction.steps {
            let deviceName = devices.first { $0.id == step.deviceID }?.name ?? "Unknown device"
            do {
                try await send(step.command, toDeviceID: step.deviceID)
                results.append(QuickActionStepResult(deviceID: step.deviceID, deviceName: deviceName, succeeded: true))
            } catch {
                let reason = (error as? AdapterError).map(Self.describe) ?? "Command failed."
                results.append(QuickActionStepResult(deviceID: step.deviceID, deviceName: deviceName, succeeded: false, failureReason: reason))
            }
        }
        return results
    }

    private static func describe(_ error: AdapterError) -> String {
        switch error {
        case .timeout: "Timed out."
        case .unreachable: "Device unreachable."
        case .pairingRejected: "Pairing was rejected."
        case .pairingCodeRequired: "Pairing code required."
        case .unsupportedCommand: "Not supported on this device."
        case .malformedResponse: "Received an unexpected response."
        case .notPaired: "Device isn't paired."
        case .notImplemented: "Not yet supported."
        }
    }
}
