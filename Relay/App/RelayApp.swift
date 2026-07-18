import SwiftUI

@main
struct RelayApp: App {
    @State private var appState: AppState

    init() {
        // Order matters: the reset must run BEFORE AppState is constructed, because AppState's
        // initializer reads `hasCompletedOnboarding` from UserDefaults. A stored-property
        // initializer (`= AppState()`) would run before this init body, capturing the stale flag —
        // so AppState is initialized here, explicitly after the reset. Without this, a UI test that
        // completes onboarding pollutes the shared simulator's state for every later test.
        UITestSupport.resetStateIfRequested()
        _appState = State(initialValue: AppState())
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
