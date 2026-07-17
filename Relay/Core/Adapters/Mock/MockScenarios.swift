import Foundation

/// A fault or condition `MockAdapter` can simulate for a given mock device, so every screen (error
/// states included) is demonstrable and testable without real hardware.
enum MockFailureScenario: Sendable, Equatable {
    case none
    case highLatency(millis: Int)
    case disconnected
    case malformedResponse
    case pairingFailure(reason: String)
    case sleeping
    case wakeUnsupported
}

/// Canned mock devices covering the range of capability profiles and failure scenarios the UI
/// needs to demonstrate: a fully-capable device, a partially-capable one (to exercise
/// capability-gated rendering), one that's unreachable, and one that requires a pairing PIN.
enum MockScenarios {
    static let livingRoomFullyCapable = DiscoveredDevice(
        id: "mock-livingroom-01",
        name: "Living Room TV",
        brand: .mock,
        host: "10.0.0.21",
        rawIdentifiers: ["mock-livingroom-01"]
    )

    static let bedroomPartialCapability = DiscoveredDevice(
        id: "mock-bedroom-01",
        name: "Bedroom TV",
        brand: .mock,
        host: "10.0.0.22",
        rawIdentifiers: ["mock-bedroom-01"]
    )

    static let officeRequiresPIN = DiscoveredDevice(
        id: "mock-office-01",
        name: "Office Display",
        brand: .mock,
        host: "10.0.0.23",
        rawIdentifiers: ["mock-office-01"]
    )

    static let unreachableDevice = DiscoveredDevice(
        id: "mock-unreachable-01",
        name: "Garage TV",
        brand: .mock,
        host: "10.0.0.24",
        rawIdentifiers: ["mock-unreachable-01"]
    )

    static let allDiscoverable: [DiscoveredDevice] = [
        livingRoomFullyCapable, bedroomPartialCapability, officeRequiresPIN, unreachableDevice,
    ]

    static func scenario(forDeviceID id: String) -> MockFailureScenario {
        switch id {
        case officeRequiresPIN.id: .pairingFailure(reason: "")  // requires correct PIN; see MockAdapter.pair
        case unreachableDevice.id: .disconnected
        default: .none
        }
    }

    static func capabilities(forDeviceID id: String) -> Set<DeviceCapability> {
        switch id {
        case livingRoomFullyCapable.id:
            Set(DeviceCapability.allCases)
        case bedroomPartialCapability.id:
            [.volume, .mute, .dpad, .homeButton, .backButton]
        case officeRequiresPIN.id:
            [.volume, .mute, .dpad, .homeButton, .backButton, .playback, .keyboardInput]
        default:
            []
        }
    }
}
