import Foundation
import Observation

/// Lightweight, non-secret user preferences backed by `UserDefaults`. Pairing tokens and device
/// data do NOT live here — see `KeychainTokenStore` and `DeviceStore`.
@MainActor
@Observable
final class AppSettings {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Keys.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Keys.hasCompletedOnboarding) }
    }

    var lastUsedRoomID: UUID? {
        get { (defaults.string(forKey: Keys.lastUsedRoomID)).flatMap(UUID.init) }
        set { defaults.set(newValue?.uuidString, forKey: Keys.lastUsedRoomID) }
    }

    /// Defaults to true — haptics are on unless the user turns them off in Accessibility settings.
    var hapticsEnabled: Bool {
        get { defaults.object(forKey: Keys.hapticsEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.hapticsEnabled) }
    }

    var leftHandedLayout: Bool {
        get { defaults.bool(forKey: Keys.leftHandedLayout) }
        set { defaults.set(newValue, forKey: Keys.leftHandedLayout) }
    }

    var largeButtonMode: Bool {
        get { defaults.bool(forKey: Keys.largeButtonMode) }
        set { defaults.set(newValue, forKey: Keys.largeButtonMode) }
    }

    var simplifiedGuestMode: Bool {
        get { defaults.bool(forKey: Keys.simplifiedGuestMode) }
        set { defaults.set(newValue, forKey: Keys.simplifiedGuestMode) }
    }

    /// Defaults to true; the user can disable keyboard-entry history from Privacy settings.
    var keyboardHistoryEnabled: Bool {
        get { defaults.object(forKey: Keys.keyboardHistoryEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.keyboardHistoryEnabled) }
    }

    private static let recentKeyboardEntriesKey = "relay.recentKeyboardEntries"
    private static let maxRecentKeyboardEntries = 10

    var recentKeyboardEntries: [String] {
        defaults.stringArray(forKey: Self.recentKeyboardEntriesKey) ?? []
    }

    /// No-ops when `keyboardHistoryEnabled` is off, so callers don't need to guard every call site.
    func recordKeyboardEntry(_ text: String) {
        guard keyboardHistoryEnabled, !text.isEmpty else { return }
        var entries = recentKeyboardEntries
        entries.removeAll { $0 == text }
        entries.insert(text, at: 0)
        if entries.count > Self.maxRecentKeyboardEntries {
            entries = Array(entries.prefix(Self.maxRecentKeyboardEntries))
        }
        defaults.set(entries, forKey: Self.recentKeyboardEntriesKey)
    }

    func clearKeyboardHistory() {
        defaults.removeObject(forKey: Self.recentKeyboardEntriesKey)
    }

    /// Off by default — analytics are opt-in only (see PRD trust commitments).
    var analyticsOptIn: Bool {
        get { defaults.bool(forKey: Keys.analyticsOptIn) }
        set { defaults.set(newValue, forKey: Keys.analyticsOptIn) }
    }

    /// Distinct calendar days on which at least one successful remote session occurred, used to
    /// gate the review prompt (5 sessions across >= 3 distinct days — see docs/06 review-prompt rule).
    private var successfulSessionDates: [Date] {
        get {
            (defaults.array(forKey: Keys.successfulSessionDates) as? [TimeInterval])?.map(Date.init(timeIntervalSince1970:)) ?? []
        }
        set {
            defaults.set(newValue.map(\.timeIntervalSince1970), forKey: Keys.successfulSessionDates)
        }
    }

    func recordSuccessfulSession(on date: Date) {
        successfulSessionDates.append(date)
    }

    var qualifiesForReviewPrompt: Bool {
        let calendar = Calendar.current
        let distinctDays = Set(successfulSessionDates.map { calendar.startOfDay(for: $0) })
        return successfulSessionDates.count >= 5 && distinctDays.count >= 3
    }
}
