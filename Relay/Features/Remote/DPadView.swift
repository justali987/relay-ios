import SwiftUI

/// Cross-shaped directional pad with a center select button — the default navigation control mode.
/// See docs/06-ux-screen-spec.md §6.
struct DPadView: View {
    let onDirection: (DPadDirection) async -> Void

    private let ringSize: CGFloat = 220

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.remoteSurface)
                .frame(width: ringSize, height: ringSize)

            VStack(spacing: 0) {
                arrowButton(.up, systemImage: "chevron.up")
                HStack(spacing: 0) {
                    arrowButton(.left, systemImage: "chevron.left")
                    selectButton
                    arrowButton(.right, systemImage: "chevron.right")
                }
                arrowButton(.down, systemImage: "chevron.down")
            }
        }
        .frame(width: ringSize, height: ringSize)
    }

    private func arrowButton(_ direction: DPadDirection, systemImage: String) -> some View {
        Button {
            Task { await onDirection(direction) }
        } label: {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(width: 64, height: 64)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.remoteTextPrimary)
        .contentShape(Rectangle())
        .accessibilityLabel(directionLabel(direction))
    }

    private var selectButton: some View {
        Button {
            Task { await onDirection(.select) }
        } label: {
            Circle()
                .fill(Color.relayAccent)
                .frame(width: 64, height: 64)
                .overlay(
                    Text("OK")
                        .font(.relayBodyEmphasized)
                        .foregroundStyle(.white)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Select")
    }

    private func directionLabel(_ direction: DPadDirection) -> String {
        switch direction {
        case .up: "Up"
        case .down: "Down"
        case .left: "Left"
        case .right: "Right"
        case .select: "Select"
        }
    }
}

#Preview {
    DPadView(onDirection: { _ in })
        .padding()
        .background(Color.remoteBackground)
}
