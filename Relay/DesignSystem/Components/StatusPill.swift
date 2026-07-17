import SwiftUI

/// The shared connection-status indicator used on Home device rows, the Remote screen header, and
/// the Reliability Center — one component so status never renders inconsistently across screens.
struct StatusPill: View {
    let status: ConnectionStatus

    var body: some View {
        HStack(spacing: RelaySpacing.xs) {
            Circle()
                .fill(Color.statusColor(for: status))
                .frame(width: 8, height: 8)
            Text(status.displayName)
                .font(.relayCaption)
                .foregroundStyle(Color.relayTextSecondary)
        }
        .padding(.horizontal, RelaySpacing.sm)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Color.relaySurfaceElevated)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(status.displayName)
        .accessibilityHint(status.explanation)
    }
}

#Preview {
    VStack(spacing: RelaySpacing.sm) {
        ForEach(ConnectionStatus.allCases, id: \.self) { StatusPill(status: $0) }
    }
    .padding()
    .background(Color.relayBackground)
}
