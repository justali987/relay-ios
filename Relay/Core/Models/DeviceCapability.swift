import Foundation

/// A single controllable capability a device may or may not support. UI never renders a control
/// whose capability is absent from `Device.capabilities` — see docs/02-capability-matrix.md.
enum DeviceCapability: String, Codable, Sendable, CaseIterable, Hashable {
    case powerOn
    case powerOff
    case volume
    case mute
    case dpad
    case touchpad
    case homeButton
    case backButton
    case playback          // play / pause / rewind / fast-forward
    case keyboardInput
    case inputSelect
    case channelControl
    case appLaunch
    case healthCheck
    case menuButton
    /// Cable-box-style red/green/yellow/blue keys. Not offered for Roku — ECP has no equivalent
    /// keypress. See docs/02-capability-matrix.md.
    case colorKeys
    /// Saved channel shortcuts. Only meaningful alongside `.channelControl` — see
    /// `AppState.tuneToFavorite`, which sends a favorite's digits through the existing
    /// `.channelDigit` command rather than needing separate adapter plumbing.
    case channelFavorites

    var displayName: String {
        switch self {
        case .powerOn: "Power on"
        case .powerOff: "Power off"
        case .volume: "Volume"
        case .mute: "Mute"
        case .dpad: "Directional navigation"
        case .touchpad: "Touchpad"
        case .homeButton: "Home"
        case .backButton: "Back"
        case .playback: "Playback controls"
        case .keyboardInput: "Keyboard text entry"
        case .inputSelect: "Input / source selection"
        case .channelControl: "Channel controls"
        case .appLaunch: "App launching"
        case .healthCheck: "Connection health check"
        case .menuButton: "Menu / options"
        case .colorKeys: "Color keys"
        case .channelFavorites: "Channel favorites"
        }
    }
}

/// A brand/protocol family. Deliberately separate from `DeviceCapability` — brand tells you which
/// adapter owns a device, capability tells you what that specific device instance actually supports.
enum DeviceBrand: String, Codable, Sendable, CaseIterable, Identifiable {
    case roku
    case lgWebOS
    case samsungTizen
    case googleTV
    case fireTV
    case appleTV
    case mock

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .roku: "Roku"
        case .lgWebOS: "LG (webOS)"
        case .samsungTizen: "Samsung (Tizen)"
        case .googleTV: "Google TV / Android TV"
        case .fireTV: "Fire TV"
        case .appleTV: "Apple TV"
        case .mock: "Mock Device"
        }
    }

    /// Whether Relay offers real control for this brand in the current build. `false` renders as
    /// "Not controllable" in Manual Pairing rather than a broken flow — see
    /// docs/03-feasibility-warnings.md.
    var isControlSupported: Bool {
        switch self {
        case .appleTV: false
        default: true
        }
    }

    /// Whether this brand's adapter is best-effort/experimental rather than fully supported.
    var isExperimental: Bool {
        self == .fireTV
    }

    /// Whether this brand has a real, working `DeviceAdapter` in the current build — distinct from
    /// `isControlSupported`, which is about platform *feasibility* (Apple TV is never controllable
    /// no matter the engineering effort). LG/Samsung/Google TV/Fire TV are architecturally
    /// controllable but their adapters are still stubs that throw `.notImplemented` — see
    /// docs/07-implementation-plan.md milestone 8. UI must not claim "Supported" or offer a
    /// doomed pairing attempt for a brand where this is `false`.
    var isImplemented: Bool {
        switch self {
        case .roku, .mock: true
        case .lgWebOS, .samsungTizen, .googleTV, .fireTV, .appleTV: false
        }
    }
}
