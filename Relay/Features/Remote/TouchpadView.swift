import SwiftUI

/// A trackpad-style alternative to the D-pad for devices whose adapter reports `.touchpad` support
/// (typically Google TV / Android TV). Relative drag deltas are sent as they accumulate past a small
/// threshold, and a tap-without-drag sends a select/click. See docs/06-ux-screen-spec.md §6.
struct TouchpadView: View {
    let onMove: (Double, Double) async -> Void
    let onTap: () async -> Void

    @State private var lastTranslation: CGSize = .zero
    @State private var didDrag = false

    var body: some View {
        RoundedRectangle(cornerRadius: RelayRadius.control, style: .continuous)
            .fill(Color.remoteSurface)
            .frame(height: 220)
            .overlay(
                Image(systemName: "hand.draw")
                    .font(.largeTitle)
                    .foregroundStyle(Color.remoteTextSecondary.opacity(0.3))
            )
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        didDrag = true
                        let dx = value.translation.width - lastTranslation.width
                        let dy = value.translation.height - lastTranslation.height
                        lastTranslation = value.translation
                        Task { await onMove(dx, dy) }
                    }
                    .onEnded { _ in
                        lastTranslation = .zero
                    }
            )
            .onTapGesture {
                guard !didDrag else { didDrag = false; return }
                Task { await onTap() }
            }
            .accessibilityLabel("Touchpad")
            .accessibilityHint("Drag to move the pointer, tap to select")
    }
}

#Preview {
    TouchpadView(onMove: { _, _ in }, onTap: {})
        .padding()
        .background(Color.remoteBackground)
}
