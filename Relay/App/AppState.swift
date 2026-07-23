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
    /// In-memory only, resets each launch — a lightweight guard so `markRemoteScreenVisited`
    /// requests a review at most once per session. Apple's own StoreKit API separately throttles
    /// how often the system actually displays the prompt (about 3x/year), independent of this.
    private var hasRequestedReviewThisLaunch = false

    let deviceStore: DeviceStore
    let tokenStore: KeychainTokenStore
    let adapterRegistry: AdapterRegistry
    let settings: AppSettings

    init(
        deviceStore: DeviceStore = DeviceStore(),
        tokenStore: KeychainTokenStore = KeychainTokenStore(),
        adapterRegistry: AdapterRegistry? = nil,
        settings: AppSettings = AppSettings()
    ) {
        self.deviceStore = deviceStore
        self.tokenStore = tokenStore
        // The default registry needs the same `tokenStore` the app persists to, so token-based
        // adapters (Tizen today) read/write the one Keychain store — hence it's built here rather
        // than as a default argument, which couldn't reference `tokenStore`.
        self.adapterRegistry = adapterRegistry ?? .makeDefault(tokenStore: tokenStore)
        self.settings = settings
        self.hasCompletedOnboarding = settings.hasCompletedOnboarding
    }

    // MARK: - Load

    func loadFromDisk() async {
        rooms = await deviceStore.allRooms()
        devices = await deviceStore.allDevices()
        quickActions = await deviceStore.allQuickActions()
        lastUsedRoomID = settings.lastUsedRoomID
        // HapticsHelper is a plain singleton with no observation of its own — seed it from the
        // persisted preference once at startup. Previously this only happened via an incidental
        // `.onChange` in AccessibilitySettingsView, so a user who turned haptics off had them
        // silently return on every relaunch until they revisited that exact screen.
        HapticsHelper.shared.isEnabled = settings.hapticsEnabled
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

    /// Fans discovery out across the real protocol adapters and forwards each result as it arrives,
    /// undeduplicated — the caller accumulates and runs `DiscoveryResult.merge` so the incremental
    /// "populate as found" UX (docs/06-ux-screen-spec.md §2) isn't blocked on a full merge pass.
    ///
    /// The simulated `MockAdapter` is included ONLY when Demo Mode is on. In a normal install that
    /// keeps fake "Living Room TV" devices out of a real user's discovery list; with Demo Mode on
    /// (Settings, or forced under UI test) it surfaces them so the app — and App Review, which
    /// can't reach real TVs — can exercise the whole flow without hardware.
    func discoverAllDevices() -> AsyncStream<DiscoveredDevice> {
        let includeMock = settings.demoModeEnabled
        return AsyncStream { continuation in
            let task = Task {
                let adapters = await adapterRegistry.allAdapters
                    .filter { $0.brand != .mock || includeMock }
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
        guard let device = devices.first(where: { $0.id == deviceID }) else { return nil }
        guard let adapter = await adapterRegistry.adapter(for: device) else { return nil }

        // `checkHealth` is a real network round-trip and a suspension point — other MainActor
        // mutations (e.g. removeDevice) can run while it's in flight and reorder/shrink `devices`.
        // Re-locate the index by id AFTER the await rather than reusing one captured before it, so
        // this never writes into the wrong slot or indexes past the end of a shrunk array.
        let status = await adapter.checkHealth(device)
        guard let index = devices.firstIndex(where: { $0.id == deviceID }) else { return status }
        devices[index].status = status
        devices[index].lastResponseAt = status == .connected ? Date() : device.lastResponseAt
        await deviceStore.upsert(device: devices[index])
        return status
    }

    /// Records one qualifying visit to the Remote screen and reports whether this is a good moment
    /// to request an App Store review. Deliberately per-*visit* (call once when `RemoteView`
    /// appears), not per-command — recording on every keypress would satisfy "5 sessions" within
    /// seconds of first pairing a device, which isn't what "5 successful sessions across 3 distinct
    /// days" (docs/06-ux-screen-spec.md review-prompt rule) means. At most one `true` result per
    /// app launch; the caller is expected to call the real `requestReview()` action when this
    /// returns `true`, never during setup or an error state.
    @discardableResult
    func markRemoteScreenVisited() -> Bool {
        settings.recordSuccessfulSession(on: Date())
        guard settings.qualifiesForReviewPrompt, !hasRequestedReviewThisLaunch else { return false }
        hasRequestedReviewThisLaunch = true
        return true
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

    /// Attempts to wake a sleeping device via its adapter. `RokuAdapter.wake` (the one real
    /// implementation so far) is best-effort and may throw `.unsupportedCommand` even when
    /// `.powerOn` is otherwise supported — see docs/03-feasibility-warnings.md on how unreliable
    /// network wake is across brands/models.
    func wake(deviceID: UUID) async throws {
        guard let device = devices.first(where: { $0.id == deviceID }) else {
            throw AdapterError.notPaired
        }
        guard let adapter = await adapterRegistry.adapter(for: device) else {
            throw AdapterError.notPaired
        }
        try await adapter.wake(device)
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
                results.append(QuickActionStepResult(
                    deviceID: step.deviceID, deviceName: deviceName, succeeded: false, failureReason: reason
                ))
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
