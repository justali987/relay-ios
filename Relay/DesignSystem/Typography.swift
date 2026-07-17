import SwiftUI

/// Relay's type scale. Every font is defined relative to a Dynamic Type text style so accessibility
/// text sizes scale correctly — never a fixed point size (see docs/06 Accessibility requirements).
extension Font {
    static let relayLargeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let relayTitle = Font.system(.title2, design: .rounded, weight: .semibold)
    static let relayHeadline = Font.system(.headline, design: .rounded, weight: .semibold)
    static let relayBody = Font.system(.body, design: .default, weight: .regular)
    static let relayBodyEmphasized = Font.system(.body, design: .default, weight: .semibold)
    static let relayCaption = Font.system(.caption, design: .default, weight: .medium)
    static let relaySubheadline = Font.system(.subheadline, design: .default, weight: .regular)

    /// Fixed-width digits for channel numbers and latency readouts, still Dynamic-Type-scaled.
    static let relayMonospacedDigits = Font.system(.title3, design: .monospaced, weight: .semibold)
}
