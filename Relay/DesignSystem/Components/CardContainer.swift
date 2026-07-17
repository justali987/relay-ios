import SwiftUI

/// The one reusable card surface every list/grid item (room cards, device rows, scene tiles) is
/// built on, so elevation/corner-radius/padding stay consistent without every feature screen
/// reimplementing a `RoundedRectangle` background.
struct CardContainer<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(RelaySpacing.md)
            .background(
                RoundedRectangle(cornerRadius: RelayRadius.large, style: .continuous)
                    .fill(Color.relaySurface)
            )
    }
}
