import Foundation

/// Lets `RelayUITests` start from a deterministic clean slate. Tests launch the app with
/// `-UITest_ResetState` (see `XCUIApplication.launchArguments` in the UI test target) so onboarding,
/// pairing, and rooms always begin from a known-empty state rather than whatever the simulator's
/// prior run left behind.
enum UITestSupport {
    static func resetStateIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-UITest_ResetState") else { return }

        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Relay", isDirectory: true)
        try? FileManager.default.removeItem(at: dir.appendingPathComponent("devices.json"))

        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }

        // The UI suite drives discovery against the mock devices, which now only appear when Demo
        // Mode is on (so real users don't see them). Force it on for the test run, after the reset
        // above has cleared defaults and before AppState reads them.
        UserDefaults.standard.set(true, forKey: "relay.demoModeEnabled")
    }
}
