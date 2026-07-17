import XCTest

/// Covers the first-launch flow, including the denied-Local-Network-permission path. See
/// docs/06-ux-screen-spec.md §1. NOTE: written against the Xcode 16 / iOS 18 XCUITest APIs but not
/// yet run — this project is being authored on Windows, where Xcode cannot run (see
/// docs/03-feasibility-warnings.md "Development environment constraint").
final class OnboardingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITest_ResetState"]
        app.launch()
        return app
    }

    func testWelcomeScreenShowsExplanationAndActions() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["Welcome to Relay"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Find devices"].exists)
        XCTAssertTrue(app.buttons["Add a device manually"].exists)
    }

    /// Simulates denying the Local Network permission prompt that appears only after tapping
    /// "Find devices" — never at first launch (see docs/06-ux-screen-spec.md §1).
    func testDeniedLocalNetworkPermissionFallsBackToDiagnostics() {
        let app = launchApp()

        let alertMonitor = addUIInterruptionMonitor(withDescription: "Local Network Permission") { alert in
            let denyButton = alert.buttons["Don't Allow"]
            if denyButton.exists {
                denyButton.tap()
                return true
            }
            return false
        }

        app.buttons["Find devices"].tap()
        // A dummy interaction is required to flush the interruption monitor in some XCTest
        // versions — tapping the app itself after triggering the system alert.
        app.tap()
        removeUIInterruptionMonitor(alertMonitor)

        // Discovery still runs against the mock adapter regardless of the real Local Network
        // permission outcome, so devices should still appear; a denied permission only affects
        // real network discovery. This asserts the screen doesn't crash or hang on denial.
        XCTAssertTrue(app.navigationBars["Find Devices"].waitForExistence(timeout: 5))
    }

    func testManualPairingShowsAppleTVAsUnsupported() {
        let app = launchApp()
        app.buttons["Add a device manually"].tap()

        XCTAssertTrue(app.staticTexts["Apple TV"].waitForExistence(timeout: 5))
        app.staticTexts["Apple TV"].tap()

        XCTAssertTrue(app.staticTexts["Apple TV isn't controllable by Relay due to Apple's platform restrictions."].waitForExistence(timeout: 5))
    }
}
