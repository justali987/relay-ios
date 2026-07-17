import SwiftUI

/// One device row within a Room Detail list. Tapping the row jumps straight into the Remote screen
/// — no intermediate confirmation (see docs/06-ux-screen-spec.md §5).
struct DeviceCardView: View {
    let device: Device
    let isPrimary: Bool

    var body: some View {
        CardContainer {
            HStack(spacing: RelaySpacing.md) {
                Image(systemName: "tv")
                    .font(.title3)
                    .foregroundStyle(Color.relayAccent)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: RelaySpacing.xs) {
                        Text(device.name)
                            .font(.relayBodyEmphasized)
                            .foregroundStyle(Color.relayTextPrimary)
                        if isPrimary {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.relayStatusSleeping)
                                .accessibilityLabel("Primary device")
                        }
                    }
                    Text(device.brand.displayName)
                        .font(.relayCaption)
                        .foregroundStyle(Color.relayTextSecondary)
                }

                Spacer()
                StatusPill(status: device.status)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.relayTextSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the remote for \(device.name)")
    }
}
