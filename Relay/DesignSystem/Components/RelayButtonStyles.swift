import SwiftUI

/// The single filled call-to-action style used for primary actions ("Find devices", "Send").
struct RelayPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.relayBodyEmphasized)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: RelayHitTarget.minimum)
            .background(
                RoundedRectangle(cornerRadius: RelayRadius.medium, style: .continuous)
                    .fill(Color.relayAccent.opacity(isEnabled ? 1 : 0.4))
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Secondary/tertiary actions ("Add manually", "Rescan") — outline style, no competing weight
/// against the primary button.
struct RelaySecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.relayBodyEmphasized)
            .foregroundStyle(Color.relayAccent)
            .frame(maxWidth: .infinity)
            .frame(minHeight: RelayHitTarget.minimum)
            .background(
                RoundedRectangle(cornerRadius: RelayRadius.medium, style: .continuous)
                    .stroke(Color.relayAccent, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A remote-screen control button: large, dark-room-themed, with a distinct pressed state so a
/// tap's optimistic feedback is visible even before the command's result is known (see
/// docs/06-ux-screen-spec.md §6). Respects Reduce Motion (drops the scale/animation, keeps the
/// solid pressed-color swap) and Large Button Mode (scales the target up further).
struct RelayRemoteControlButtonStyle: ButtonStyle {
    var isPrimary: Bool = false
    @Environment(\.relayLargeButtonMode) private var isLargeButtonMode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let base = isPrimary ? RelayHitTarget.primaryControl : RelayHitTarget.minimum
        let size = isLargeButtonMode ? base * 1.3 : base

        configuration.label
            .font(isPrimary ? .relayTitle : .relayHeadline)
            .foregroundStyle(Color.remoteTextPrimary)
            .frame(minWidth: size, minHeight: size)
            .background(
                Circle()
                    .fill(configuration.isPressed ? Color.remoteControlPressed : Color.remoteControlIdle)
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
