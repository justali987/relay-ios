import SwiftUI
import UIKit

/// Structured device-compatibility feedback for the TestFlight beta (see docs/08-launch-runbook.md).
/// Captures the fields that actually drive the pre-launch fix list — TV brand/model/OS, how pairing
/// went, and which commands fail — plus auto-filled app/OS/device info shown to the tester so they
/// know exactly what's shared. Relay has no backend, so the result is a plain-text report the tester
/// sends via the system share sheet (Mail, Messages, etc.).
struct BetaFeedbackView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var brand: DeviceBrand = .roku
    @State private var model = ""
    @State private var tvOSVersion = ""
    @State private var pairingResult: PairingResult = .succeeded
    @State private var failingCommands: Set<DeviceCapability> = []
    @State private var notes = ""
    @State private var isSharePresented = false
    @State private var report = ""

    private enum PairingResult: String, CaseIterable, Identifiable {
        case succeeded = "Succeeded"
        case neededRetries = "Needed retries"
        case failed = "Failed"
        var id: String { rawValue }
    }

    /// The command families a tester is most likely to find broken on a given TV.
    private let reportableCommands: [DeviceCapability] = [
        .powerOn, .volume, .dpad, .homeButton, .backButton, .playback, .keyboardInput, .inputSelect, .channelControl,
    ]

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        Form {
            Section("Your TV") {
                Picker("Brand", selection: $brand) {
                    ForEach(DeviceBrand.allCases.filter { $0 != .mock }) { brand in
                        Text(brand.displayName).tag(brand)
                    }
                }
                TextField("Model (e.g. TCL 55S446)", text: $model)
                    .autocorrectionDisabled()
                TextField("TV software version (if known)", text: $tvOSVersion)
                    .autocorrectionDisabled()
            }

            Section("Pairing") {
                Picker("Result", selection: $pairingResult) {
                    ForEach(PairingResult.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section {
                ForEach(reportableCommands, id: \.self) { capability in
                    Toggle(capability.displayName, isOn: Binding(
                        get: { failingCommands.contains(capability) },
                        set: { isOn in
                            if isOn { failingCommands.insert(capability) } else { failingCommands.remove(capability) }
                        }
                    ))
                }
            } header: {
                Text("Commands that don't work")
            } footer: {
                Text("Leave all off if everything you tried worked.")
            }

            Section("Anything else?") {
                TextEditor(text: $notes)
                    .frame(minHeight: 100)
            }

            Section {
                LabeledContent("App version", value: appVersion)
                LabeledContent("iOS", value: UIDevice.current.systemVersion)
                LabeledContent("iPhone", value: UIDevice.current.model)
            } header: {
                Text("Included automatically")
            } footer: {
                Text("Only what you see here is shared. No device names, IP addresses, or pairing tokens are included. You choose where the report goes.")
            }
        }
        .navigationTitle("Beta Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Share Report") {
                    report = buildReport()
                    isSharePresented = true
                }
                .disabled(model.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .sheet(isPresented: $isSharePresented) {
            ShareSheet(activityItems: [report])
        }
    }

    private func buildReport() -> String {
        let failing = failingCommands.isEmpty
            ? "None reported"
            : reportableCommands.filter(failingCommands.contains).map(\.displayName).joined(separator: ", ")
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        return """
        Relay beta feedback
        ───────────────────
        TV brand:        \(brand.displayName)
        TV model:        \(model.trimmingCharacters(in: .whitespaces))
        TV software:     \(tvOSVersion.isEmpty ? "Not provided" : tvOSVersion)
        Pairing result:  \(pairingResult.rawValue)
        Failing commands: \(failing)

        Notes:
        \(trimmedNotes.isEmpty ? "None" : trimmedNotes)

        App \(appVersion) · iOS \(UIDevice.current.systemVersion) · \(UIDevice.current.model)
        """
    }
}
