import Foundation

/// A paired, controllable device. `capabilities` is always populated by the owning adapter's live
/// probe at pairing time (and refreshed on reconnect) — never assumed from `brand` alone, since real
/// support varies by model even within one brand.
///
/// "Primary in its room" is tracked only on `Room.primaryDeviceID` — deliberately not duplicated
/// here, so there's a single source of truth for which device a room's Home card represents.
struct Device: Identifiable, Codable, Sendable, Equatable, Hashable {
    let id: UUID
    var name: String
    var brand: DeviceBrand
    var host: String
    var capabilities: Set<DeviceCapability>
    var status: ConnectionStatus
    var roomID: UUID?
    var lastResponseAt: Date?
    /// Opaque adapter-specific identifier (e.g. Roku's device serial, webOS client key request id).
    /// Never a secret — actual pairing tokens live in the Keychain via `KeychainTokenStore`.
    var adapterDeviceID: String
    /// Only meaningful alongside `.channelControl` — see `AppState.tuneToFavorite`.
    var channelFavorites: [ChannelFavorite]

    init(
        id: UUID = UUID(),
        name: String,
        brand: DeviceBrand,
        host: String,
        capabilities: Set<DeviceCapability> = [],
        status: ConnectionStatus = .needsPairing,
        roomID: UUID? = nil,
        lastResponseAt: Date? = nil,
        adapterDeviceID: String,
        channelFavorites: [ChannelFavorite] = []
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.host = host
        self.capabilities = capabilities
        self.status = status
        self.roomID = roomID
        self.lastResponseAt = lastResponseAt
        self.adapterDeviceID = adapterDeviceID
        self.channelFavorites = channelFavorites
    }

    func supports(_ capability: DeviceCapability) -> Bool {
        capabilities.contains(capability)
    }
}
