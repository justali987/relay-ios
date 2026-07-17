import SwiftUI

@main
struct RelayApp: App {
    @State private var appState = AppState()

    init() {
        UITestSupport.resetStateIfRequested()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .task {
                    await appState.loadFromDisk()
                }
        }
    }
}

/// Gates between the first-launch Onboarding flow and the main tab experience. Onboarding is a
/// full-screen sequence, not a tab — see docs/04-information-architecture.md.
struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.hasCompletedOnboarding {
            MainTabView()
        } else {
            WelcomeView()
        }
    }
}
