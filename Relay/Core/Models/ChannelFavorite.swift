import Foundation

/// A saved channel shortcut. Tuning to one just sends its digits through the existing
/// `.channelDigit` command sequentially (see `AppState.tuneToFavorite`) — no adapter plumbing or
/// new capability beyond `.channelControl` is needed. See docs/01-PRD.md "Competitive additions".
struct ChannelFavorite: Identifiable, Codable, Sendable, Equatable, Hashable {
    let id: UUID
    var label: String
    /// Digits only (e.g. "704") — validated by the add-favorite UI, not re-validated here.
    var channelDigits: String

    init(id: UUID = UUID(), label: String, channelDigits: String) {
        self.id = id
        self.label = label
        self.channelDigits = channelDigits
    }
}
