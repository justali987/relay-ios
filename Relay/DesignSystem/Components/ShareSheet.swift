import SwiftUI
import UIKit

/// Thin wrapper over `UIActivityViewController` for presenting the system share sheet from SwiftUI.
/// Shared by Privacy (diagnostics export) and Beta Feedback (report export) — both hand the user a
/// redacted/structured text blob to send however they choose, since Relay has no backend of its own.
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
