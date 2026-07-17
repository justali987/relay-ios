import UIKit

/// Wraps `UIFeedbackGenerator` and respects the user's Accessibility > Haptic Feedback toggle
/// (persisted via `AppSettings`), so every remote-button tap doesn't need to re-check that
/// preference inline.
@MainActor
final class HapticsHelper {
    static let shared = HapticsHelper()

    var isEnabled: Bool = true

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()

    private init() {}

    func controlTap() {
        guard isEnabled else { return }
        impactLight.impactOccurred()
    }

    func primaryAction() {
        guard isEnabled else { return }
        impactMedium.impactOccurred()
    }

    func commandFailed() {
        guard isEnabled else { return }
        notification.notificationOccurred(.error)
    }

    func commandSucceeded() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }
}
