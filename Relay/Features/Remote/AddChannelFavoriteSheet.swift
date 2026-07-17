import SwiftUI

/// Captures a label + channel digits for a new favorite. See docs/01-PRD.md "Competitive
/// additions" — this is the UI half of `AppState.addChannelFavorite`/`tuneToFavorite`.
struct AddChannelFavoriteSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let deviceID: UUID

    @State private var label = ""
    @State private var digits = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Favorite") {
                    TextField("Name (e.g. ESPN)", text: $label)
                    TextField("Channel number", text: $digits)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Add Favorite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await appState.addChannelFavorite(label: label, channelDigits: digits, toDeviceID: deviceID)
                            dismiss()
                        }
                    }
                    .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty || digits.isEmpty)
                }
            }
        }
    }
}
