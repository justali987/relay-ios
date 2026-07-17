import SwiftUI
import UIKit

/// Per-device connection status, latency, pairing status, live capability list, and plain-English
/// troubleshooting — see docs/06-ux-screen-spec.md §9.
struct ReliabilityCenterView: View {
    @Environment(AppState.self) private var appState
    let deviceID: UUID

    @State private var diagnostics: DeviceDiagnostics?
    @State private var isRefreshing = false

    private var device: Device? {
        appState.devices.first { $0.id == deviceID }
    }

    var body: some View {
        List {
            if let device {
                Section("Status") {
                    LabeledContent("Connection") {
                        StatusPill(status: diagnostics?.status ?? device.status)
                    }
                    if let latency = diagnostics?.latencyMillis {
                        LabeledContent("Latency", value: "\(latency) ms")
                    }
                    if let lastResponse = diagnostics?.lastResponseAt ?? device.lastResponseAt {
                        LabeledContent("Last response", value: lastResponse.formatted(date: .omitted, time: .shortened))
                    }
                }

                Section("Capabilities") {
                    ForEach(DeviceCapability.allCases, id: \.self) { capability in
                        HStack {
                            Text(capability.displayName)
                            Spacer()
                            if device.supports(capability) {
                                Text("Supported")
                                    .foregroundStyle(Color.relayStatusConnected)
                            } else {
                                Text("Not available")
                                    .foregroundStyle(Color.relayTextSecondary)
                            }
                        }
                        .font(.relaySubheadline)
                    }
                }

                if let notes = diagnostics?.notes, !notes.isEmpty {
                    Section("Troubleshooting") {
                        ForEach(notes, id: \.self) { note in
                            Text(note)
                                .font(.relaySubheadline)
                                .foregroundStyle(Color.relayTextSecondary)
                        }
                    }
                }

                Section {
                    Button("Re-pair Device") {
                        Task { await appState.markNeedsRepairing(device.id) }
                    }
                    Text("Marks this device as needing to be paired again. Go to Settings > Devices & Pairing, or Home > Add manually, to finish re-pairing.")
                        .font(.relayCaption)
                        .foregroundStyle(Color.relayTextSecondary)

                    NavigationLink("Report a Compatibility Issue") {
                        CompatibilityFeedbackView(device: device)
                    }
                }
            }
        }
        .navigationTitle("Reliability Center")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await refresh() }
                } label: {
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task { await refresh() }
    }

    private func refresh() async {
        guard let device else { return }
        isRefreshing = true
        guard let adapter = await appState.adapterRegistry.adapter(for: device) else {
            isRefreshing = false
            return
        }
        diagnostics = await adapter.diagnostics(for: device)
        isRefreshing = false
    }
}

/// Minimal feedback form: model, OS, observed command set, and a free-text issue description — see
/// docs/06-ux-screen-spec.md §9. Submissions are local-only in this build (no backend wired yet).
private struct CompatibilityFeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    let device: Device

    @State private var issueDescription = ""

    var body: some View {
        Form {
            Section("Device") {
                LabeledContent("Brand", value: device.brand.displayName)
                LabeledContent("iOS Version", value: UIDevice.current.systemVersion)
            }
            Section("What went wrong?") {
                TextEditor(text: $issueDescription)
                    .frame(minHeight: 120)
            }
        }
        .navigationTitle("Compatibility Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Submit") {
                    dismiss()
                }
                .disabled(issueDescription.isEmpty)
            }
        }
    }
}
