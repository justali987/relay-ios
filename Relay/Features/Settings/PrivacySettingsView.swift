import SwiftUI

/// Diagnostics export (off by default, redacted, explicit consent) and analytics opt-in (off by
/// default) — see docs/06-ux-screen-spec.md §11 and PRD trust commitments.
struct PrivacySettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var isExportConfirmationPresented = false
    @State private var isExportShareSheetPresented = false
    @State private var exportText: String = ""

    var body: some View {
        @Bindable var settings = appState.settings

        Form {
            Section {
                Toggle("Remember Keyboard History", isOn: $settings.keyboardHistoryEnabled)
            } footer: {
                Text("Recent keyboard entries stay on this device only. Turning this off also stops new entries from being saved.")
            }

            Section {
                Toggle("Share Anonymized Usage Data", isOn: $settings.analyticsOptIn)
            } footer: {
                Text(
                    "Reserved for a future update. Currently collects nothing regardless of this " +
                    "setting — Relay has no analytics implementation yet. If that changes, it will " +
                    "still never include device names, IP addresses, pairing tokens, or remote commands."
                )
            }

            Section {
                Button("Export Diagnostics…") {
                    isExportConfirmationPresented = true
                }
            } footer: {
                Text(
                    "Generates a report of device connection status for troubleshooting. Device names, " +
                    "IP addresses, and pairing tokens are redacted before anything is shared."
                )
            }
        }
        .navigationTitle("Privacy")
        .alert("Export Diagnostics?", isPresented: $isExportConfirmationPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Export") {
                exportText = DiagnosticsExporter.redactedReport(devices: appState.devices)
                isExportShareSheetPresented = true
            }
        } message: {
            Text("This creates a redacted report of device statuses. Nothing is sent anywhere until you choose to share it.")
        }
        .sheet(isPresented: $isExportShareSheetPresented) {
            ShareSheet(activityItems: [exportText])
        }
    }
}

/// Builds a diagnostics report with IPs, pairing tokens, and device names stripped by default —
/// see docs PRD "Local-first" and "redacted diagnostic export" commitments.
enum DiagnosticsExporter {
    static func redactedReport(devices: [Device]) -> String {
        var lines = ["Relay Diagnostics Report", "Generated: \(Date().formatted())", ""]
        for (index, device) in devices.enumerated() {
            lines.append("Device \(index + 1): \(device.brand.displayName)")
            lines.append("  Status: \(device.status.displayName)")
            lines.append("  Capabilities: \(device.capabilities.map(\.displayName).sorted().joined(separator: ", "))")
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}
// `ShareSheet` now lives in DesignSystem/Components/ShareSheet.swift (shared with Beta Feedback).
