import SwiftUI

/// Shared "run this Quick Action" row used by both `RoomDetailView` and `SceneListView`. Running an
/// action always shows a per-device result — never a single blanket "Done" — see
/// docs/06-ux-screen-spec.md §8.
struct QuickActionRow: View {
    @Environment(AppState.self) private var appState
    let quickAction: QuickAction

    @State private var isRunning = false
    @State private var results: [QuickActionStepResult]?

    var body: some View {
        Button {
            Task { await run() }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(quickAction.name)
                        .font(.relayBodyEmphasized)
                        .foregroundStyle(Color.relayTextPrimary)
                    Text("\(quickAction.steps.count) device\(quickAction.steps.count == 1 ? "" : "s")")
                        .font(.relayCaption)
                        .foregroundStyle(Color.relayTextSecondary)
                }
                Spacer()
                if isRunning {
                    ProgressView()
                } else {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.relayAccent)
                }
            }
        }
        .disabled(isRunning || quickAction.steps.isEmpty)
        .sheet(item: Binding(
            get: { results.map { ResultsWrapper(results: $0) } },
            set: { _ in results = nil }
        )) { wrapper in
            QuickActionResultsView(quickActionName: quickAction.name, results: wrapper.results)
        }
    }

    private func run() async {
        isRunning = true
        results = await appState.run(quickAction)
        isRunning = false
    }
}

private struct ResultsWrapper: Identifiable {
    let id = UUID()
    let results: [QuickActionStepResult]
}

private struct QuickActionResultsView: View {
    @Environment(\.dismiss) private var dismiss
    let quickActionName: String
    let results: [QuickActionStepResult]

    var body: some View {
        NavigationStack {
            List(results) { result in
                HStack {
                    Image(systemName: result.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(result.succeeded ? Color.relayStatusConnected : Color.relayStatusUnavailable)
                    VStack(alignment: .leading) {
                        Text(result.deviceName)
                        if let reason = result.failureReason {
                            Text(reason)
                                .font(.relayCaption)
                                .foregroundStyle(Color.relayTextSecondary)
                        }
                    }
                }
            }
            .navigationTitle(quickActionName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
