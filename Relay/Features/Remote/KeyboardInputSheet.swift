import SwiftUI

/// Presented as a sheet over the Remote screen so the D-pad remains one swipe-down away. Sends
/// text explicitly via a Send button rather than per-keystroke, and keeps a local-only recent-entry
/// list the user can disable or clear from Privacy settings. See docs/06-ux-screen-spec.md §7.
struct KeyboardInputSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let deviceID: UUID

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: RelaySpacing.lg) {
                TextField("Type to send…", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .font(.relayBody)
                    .focused($isFocused)
                    .submitLabel(.send)
                    .onSubmit { send() }

                if appState.settings.keyboardHistoryEnabled, !appState.settings.recentKeyboardEntries.isEmpty {
                    recentEntries
                }

                Spacer()
            }
            .padding(RelaySpacing.md)
            .navigationTitle("Keyboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { send() }
                        .disabled(text.isEmpty)
                }
            }
            .onAppear { isFocused = true }
        }
    }

    private var recentEntries: some View {
        VStack(alignment: .leading, spacing: RelaySpacing.sm) {
            HStack {
                Text("Recent")
                    .font(.relayCaption)
                    .foregroundStyle(Color.relayTextSecondary)
                Spacer()
                Button("Clear") { appState.settings.clearKeyboardHistory() }
                    .font(.relayCaption)
            }
            ForEach(appState.settings.recentKeyboardEntries, id: \.self) { entry in
                Button(entry) {
                    text = entry
                    send()
                }
                .font(.relayBody)
                .foregroundStyle(Color.relayTextPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func send() {
        guard !text.isEmpty else { return }
        let sentText = text
        Task {
            try? await appState.send(.keyboardText(sentText), toDeviceID: deviceID)
        }
        appState.settings.recordKeyboardEntry(sentText)
        text = ""
    }
}
