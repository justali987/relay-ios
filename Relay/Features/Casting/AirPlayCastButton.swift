import SwiftUI
import AVKit

/// Wraps `AVRoutePickerView` — Apple's public AirPlay route picker. Deliberately independent of
/// `DeviceAdapter`/`AdapterRegistry`: it doesn't send commands to a paired device over any of
/// Relay's own protocol adapters, it hands off to the system's own AirPlay routing to whatever
/// receiver the user picks (including an Apple TV or HomePod). See docs/02-capability-matrix.md
/// "AirPlay casting (not a per-adapter capability)".
///
/// Scope honesty: this is the picker itself (system audio routing / screen mirroring), not a
/// media browser — Relay has no photo/video/music library of its own to cast. A fuller "pick a
/// photo and cast it" flow would layer a media picker + `AVPlayer` on top of this; not yet built.
struct AirPlayCastButton: UIViewRepresentable {
    var tintColor: UIColor = .white

    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = tintColor
        view.activeTintColor = tintColor
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = tintColor
        uiView.activeTintColor = tintColor
    }
}
