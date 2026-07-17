import Foundation

enum DPadDirection: String, Codable, Sendable {
    case up, down, left, right, select
}

/// Cable-box-style color keys. Roku's ECP has no equivalent keypress, so no adapter maps this for
/// Roku devices — see docs/02-capability-matrix.md.
enum ColorKey: String, Codable, Sendable, CaseIterable {
    case red, green, yellow, blue
}

/// Every command Relay can ask an adapter to send. Not every device supports every case — the
/// Remote screen only offers a control when the corresponding `DeviceCapability` is present.
enum RemoteCommand: Codable, Sendable, Equatable, Hashable {
    case powerToggle
    case volumeUp
    case volumeDown
    case mute
    case dpad(DPadDirection)
    case touchpadMove(dx: Double, dy: Double)
    case touchpadTap
    case home
    case back
    case play
    case pause
    case rewind
    case fastForward
    case keyboardText(String)
    case selectInput(String)
    case channelDigit(Int)
    case launchApp(String)
    case menu
    case colorKey(ColorKey)

    /// The capability that must be present on a device before this command can be offered.
    var requiredCapability: DeviceCapability {
        switch self {
        case .powerToggle: .powerOn
        case .volumeUp, .volumeDown, .mute: .volume
        case .dpad: .dpad
        case .touchpadMove, .touchpadTap: .touchpad
        case .home: .homeButton
        case .back: .backButton
        case .play, .pause, .rewind, .fastForward: .playback
        case .keyboardText: .keyboardInput
        case .selectInput: .inputSelect
        case .channelDigit: .channelControl
        case .launchApp: .appLaunch
        case .menu: .menuButton
        case .colorKey: .colorKeys
        }
    }
}
