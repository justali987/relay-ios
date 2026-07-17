import SwiftUI

/// Color tokens for Relay's design system: a refined dark-graphite palette with a single restrained
/// accent, rather than gradients or brand-color clutter (see docs/06 design direction). Every token
/// adapts to light/dark mode except `remote*`, which is deliberately fixed-dark for the "dark room"
/// Remote screen regardless of system appearance.
extension Color {
    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    // MARK: - Surfaces

    static let relayBackground = dynamic(
        light: UIColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1),
        dark: UIColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1)
    )

    static let relaySurface = dynamic(
        light: .white,
        dark: UIColor(red: 0.14, green: 0.14, blue: 0.16, alpha: 1)
    )

    static let relaySurfaceElevated = dynamic(
        light: UIColor(red: 0.94, green: 0.94, blue: 0.96, alpha: 1),
        dark: UIColor(red: 0.19, green: 0.19, blue: 0.22, alpha: 1)
    )

    static let relayDivider = dynamic(
        light: UIColor(white: 0, alpha: 0.08),
        dark: UIColor(white: 1, alpha: 0.08)
    )

    // MARK: - Text

    static let relayTextPrimary = dynamic(
        light: UIColor(white: 0.08, alpha: 1),
        dark: UIColor(white: 0.96, alpha: 1)
    )

    static let relayTextSecondary = dynamic(
        light: UIColor(white: 0.35, alpha: 1),
        dark: UIColor(white: 0.7, alpha: 1)
    )

    // MARK: - Accent (restrained electric blue; amber reserved for warnings/sleeping state)

    static let relayAccent = dynamic(
        light: UIColor(red: 0.11, green: 0.45, blue: 0.98, alpha: 1),
        dark: UIColor(red: 0.30, green: 0.58, blue: 1.0, alpha: 1)
    )

    static let relayAccentMuted = relayAccent.opacity(0.14)

    // MARK: - Status (shared across Home, Remote header, Reliability Center)

    static let relayStatusConnected = Color(red: 0.20, green: 0.78, blue: 0.44)
    static let relayStatusSleeping = Color(red: 0.95, green: 0.69, blue: 0.20)
    static let relayStatusUnavailable = Color(red: 0.92, green: 0.33, blue: 0.31)
    static let relayStatusNeedsPairing = Color(white: 0.6)

    static func statusColor(for status: ConnectionStatus) -> Color {
        switch status {
        case .connected: .relayStatusConnected
        case .sleeping: .relayStatusSleeping
        case .unavailable: .relayStatusUnavailable
        case .needsPairing: .relayStatusNeedsPairing
        }
    }

    // MARK: - Remote screen ("dark room" theme — fixed dark regardless of system appearance)

    static let remoteBackground = Color(red: 0.05, green: 0.05, blue: 0.07)
    static let remoteSurface = Color(red: 0.11, green: 0.11, blue: 0.14)
    static let remoteControlIdle = Color(red: 0.17, green: 0.17, blue: 0.20)
    static let remoteControlPressed = Color(red: 0.24, green: 0.24, blue: 0.28)
    static let remoteTextPrimary = Color(white: 0.96)
    static let remoteTextSecondary = Color(white: 0.65)
}
