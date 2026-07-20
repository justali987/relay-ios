import Foundation
import Observation

/// Lightweight, non-secret user preferences backed by `UserDefaults`. Pairing tokens and device
/// data do NOT live here — see `KeychainTokenStore` and `DeviceStore`.
///
/// Every setting is a real STORED property, initialized from `UserDefaults` at construction and
/// written through on `didSet`. This used to be computed get/set pairs reading `UserDefaults`
/// directly — values persisted fine, but `@Observable` only instruments stored properties, so
/// SwiftUI never registered a dependency on any of them: a toggle could flip in Settings and no
/// other view (or even that Settings screen, reliably) would re-render. That silently broke
/// several "toggle something in Accessibility settings" features — see docs/08-launch-runbook.md's
/// critique-panel notes.
@MainActor
@Observable
final class AppSettings {
    private let defaults: UserDefaults

    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    var lastUsedRoomID: UUID? {
        didSet { defaults.set(lastUsedRoomID?.uuidString, forKey: Keys.lastUsedRoomID) }
    }

    /// Defaults to true — haptics are on unless the user turns them off in Accessibility settings.
    /// Seeded into `HapticsHelper.shared` once at app startup (`AppState.loadFromDisk`), since that
    /// helper is a plain singleton with no observation of its own.
    var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Keys.hapticsEnabled) }
    }

    /// Mirrors `RemoteView`'s linear control rows (power/input, playback, volume, home/back/menu,
    /// color keys) for left-handed use. Deliberately does NOT mirror the D-pad/touchpad navigation
    /// area — flipping directional semantics (does a mirrored "left" arrow still mean .left?) is
    /// ambiguous enough that it's left alone rather than guessed at.
    var leftHandedLayout: Bool {
        didSet { defaults.set(leftHandedLayout, forKey: Keys.leftHandedLayout) }
    }

    /// Scales up primary remote control targets beyond their already-larger-than-minimum default
    /// size — see `RelayHitTarget` and `RelayRemoteControlButtonStyle`.
    var largeButtonMode: Bool {
        didSet { defaults.set(largeButtonMode, forKey: Keys.largeButtonMode) }
    }

    /// Reduces the Remote screen to power/volume/navigation/home-back only — no scenes, keyboard,
    /// or settings access. See `RemoteView`'s capability-gating, which also gates on this flag.
    var simplifiedGuestMode: Bool {
        didSet { defaults.set(simplifiedGuestMode, forKey: Keys.simplifiedGuestMode) }
    }

    /// Off by default. When on, simulated devices appear in discovery so the app can be explored
    /// without a real TV — a real user never sees mock devices, but App Review (which can't reach
    /// hardware) and curious users can flip this on. Forced on under UI tests, and reachable
    /// pre-onboarding via `WelcomeView`'s "Explore with a demo" link. See
    /// `AppState.discoverAllDevices`.
    var demoModeEnabled: Bool {
        didSet { defaults.set(demoModeEnabled, forKey: Keys.demoModeEnabled) }
    }

    /// Defaults to true; the user can disable keyboard-entry history from Privacy settings.
    var keyboardHistoryEnabled: Bool {
        didSet { defaults.set(keyboardHistoryEnabled, forKey: Keys.keyboardHistoryEnabled) }
    }

    /// Off by default — analytics are opt-in only (see PRD trust commitments). Currently has no
    /// consumer: nothing in Relay records or transmits analytics yet, so toggling this on collects
    /// nothing. See docs/legal/privacy-policy.md.
    var analyticsOptIn: Bool {
        didSet { defaults.set(analyticsOptIn, forKey: Keys.analyticsOptIn) }
    }

    private(set) var recentKeyboardEntries: [String] {
        didSet { defaults.set(recentKeyboardEntries, forKey: Keys.recentKeyboardEntries) }
    }

    /// Distinct calendar days on which at least one successful remote *visit* occurred (see
    /// `AppState.markRemoteScreenVisited`), used to gate the review prompt (5 visits across >= 3
    /// distinct days — see docs/06 review-prompt rule).
    private var successfulSessionDates: [Date] {
        didSet {
            defaults.set(successfulSessionDates.map(\.timeIntervalSince1970), forKey: Keys.successfulSessionDates)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        lastUsedRoomID = defaults.string(forKey: Keys.lastUsedRoomID).flatMap(UUID.init)
        hapticsEnabled = defaults.object(forKey: Keys.hapticsEnabled) as? Bool ?? true
        leftHandedLayout = defaults.bool(forKey: Keys.leftHandedLayout)
        largeButtonMode = defaults.bool(forKey: Keys.largeButtonMode)
        simplifiedGuestMode = defaults.bool(forKey: Keys.simplifiedGuestMode)
        demoModeEnabled = defaults.bool(forKey: Keys.demoModeEnabled)
        keyboardHistoryEnabled = defaults.object(forKey: Keys.keyboardHistoryEnabled) as? Bool ?? true
        analyticsOptIn = defaults.bool(forKey: Keys.analyticsOptIn)
        recentKeyboardEntries = defaults.stringArray(forKey: Keys.recentKeyboardEntries) ?? []
        successfulSessionDates = (defaults.array(forKey: Keys.successfulSessionDates) as? [TimeInterval])?
            .map(Date.init(timeIntervalSince1970:)) ?? []
    }

    private enum Keys {
        static let hasCompletedOnboarding = "relay.hasCompletedOnboarding"
        static let lastUsedRoomID = "relay.lastUsedRoomID"
        static let hapticsEnabled = "relay.hapticsEnabled"
        static let leftHandedLayout = "relay.leftHandedLayout"
        static let largeButtonMode = "relay.largeButtonMode"
        static let simplifiedGuestMode = "relay.simplifiedGuestMode"
        static let keyboardHistoryEnabled = "relay.keyboardHistoryEnabled"
        static let analyticsOptIn = "relay.analyticsOptIn"
        static let successfulSessionDates = "relay.successfulSessionDates"
        static let demoModeEnabled = "relay.demoModeEnabled"
        static let recentKeyboardEntries = "relay.recentKeyboardEntries"
    }

    private static let maxRecentKeyboardEntries = 10

    /// No-ops when `keyboardHistoryEnabled` is off, so callers don't need to guard every call site.
    func recordKeyboardEntry(_ text: String) {
        guard keyboardHistoryEnabled, !text.isEmpty else { return }
        var entries = recentKeyboardEntries
        entries.removeAll { $0 == text }
        entries.insert(text, at: 0)
        if entries.count > Self.maxRecentKeyboardEntries {
            entries = Array(entries.prefix(Self.maxRecentKeyboardEntries))
        }
        recentKeyboardEntries = entries
    }

    func clearKeyboardHistory() {
        recentKeyboardEntries = []
    }

    /// Records one qualifying visit to the Remote screen (see `AppState.markRemoteScreenVisited`)
    /// — deliberately NOT called per command, or every keypress would count as a "session" and the
    /// 5-sessions-across-3-days rule would be met within seconds of the first pairing.
    func recordSuccessfulSession(on date: Date) {
        successfulSessionDates.append(date)
    }

    var qualifiesForReviewPrompt: Bool {
        let calendar = Calendar.current
        let distinctDays = Set(successfulSessionDates.map { calendar.startOfDay(for: $0) })
        return successfulSessionDates.count >= 5 && distinctDays.count >= 3
    }
}
