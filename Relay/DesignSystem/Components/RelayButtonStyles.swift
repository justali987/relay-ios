import SwiftUI

/// The single filled call-to-action style used for primary actions ("Find devices", "Send").
struct RelayPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

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
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Secondary/tertiary actions ("Add manually", "Rescan") — outline style, no competing weight
/// against the primary button.
struct RelaySecondaryButtonStyle: ButtonStyle {
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
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A remote-screen control button: large, dark-room-themed, with a distinct pressed state so a
/// tap's optimistic feedback is visible even before the command's result is known (see
/// docs/06-ux-screen-spec.md §6).
struct RelayRemoteControlButtonStyle: ButtonStyle {
    var isPrimary: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isPrimary ? .relayTitle : .relayHeadline)
            .foregroundStyle(Color.remoteTextPrimary)
            .frame(
                minWidth: isPrimary ? RelayHitTarget.primaryControl : RelayHitTarget.minimum,
                minHeight: isPrimary ? RelayHitTarget.primaryControl : RelayHitTarget.minimum
            )
            .background(
                Circle()
                    .fill(configuration.isPressed ? Color.remoteControlPressed : Color.remoteControlIdle)
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
