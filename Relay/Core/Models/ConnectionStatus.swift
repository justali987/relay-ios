import Foundation

/// Shared status enum consumed by Home cards, the Remote screen header, and the Reliability
/// Center, so a device's status never disagrees across screens.
enum ConnectionStatus: String, Codable, Sendable, Equatable, CaseIterable {
    case connected
    case sleeping
    case unavailable
    case needsPairing

    var displayName: String {
        switch self {
        case .connected: "Connected"
        case .sleeping: "Sleeping"
        case .unavailable: "Unavailable"
        case .needsPairing: "Needs Pairing"
        }
    }

    /// Plain-language explanation shown in the Reliability Center and on device rows.
    var explanation: String {
        switch self {
        case .connected:
            "Relay can reach this device and send commands."
        case .sleeping:
            "This device is powered down or in standby. Relay will try to wake it if that's supported."
        case .unavailable:
            "Relay can't reach this device right now. Check that it's on the same Wi-Fi network."
        case .needsPairing:
            "This device needs to be paired again before Relay can control it."
        }
    }
}
