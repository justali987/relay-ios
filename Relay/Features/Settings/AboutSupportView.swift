import SwiftUI

/// Version info, compatibility link, and the general feedback form — see
/// docs/06-ux-screen-spec.md §11.
struct AboutSupportView: View {
    @State private var isFeedbackPresented = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Version", value: appVersion)
                NavigationLink("Compatibility") { CompatibilityPageView() }
            }

            Section {
                NavigationLink("Send Beta Feedback") { BetaFeedbackView() }
                Button("Send Feedback") {
                    isFeedbackPresented = true
                }
            } footer: {
                Text("On the beta? Beta Feedback captures your TV model and which commands work, so we can prioritize fixes by device.")
            }

            Section {
                Text(
                    "Relay finds and controls compatible devices on your home Wi-Fi. Nothing leaves " +
                    "your home unless you explicitly choose to export or share diagnostics."
                )
                .font(.relayCaption)
                .foregroundStyle(Color.relayTextSecondary)
            }
        }
        .navigationTitle("About & Support")
        .sheet(isPresented: $isFeedbackPresented) {
            GeneralFeedbackView()
        }
    }
}

private struct GeneralFeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("How can we help?") {
                    TextEditor(text: $message)
                        .frame(minHeight: 150)
                }
            }
            .navigationTitle("Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { dismiss() }
                        .disabled(message.isEmpty)
                }
            }
        }
    }
}
