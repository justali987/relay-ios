import XCTest

/// Covers the discovery-to-paired flow against the mock adapter. See docs/06-ux-screen-spec.md §2.
final class DiscoveryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITest_ResetState"]
        app.launch()
        return app
    }

    func testDiscoveryPopulatesMockDevicesIncrementally() {
        let app = launchApp()
        app.buttons["Find devices"].tap()

        // MockAdapter stages devices ~350ms apart rather than yielding them all at once — this
        // waits for the last one to confirm the incremental-populate behavior didn't stall.
        XCTAssertTrue(app.staticTexts["Living Room TV"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Garage TV"].waitForExistence(timeout: 5))
    }

    func testAddingADeviceLeadsToRoomAssignment() {
        let app = launchApp()
        app.buttons["Find devices"].tap()

        XCTAssertTrue(app.staticTexts["Living Room TV"].waitForExistence(timeout: 5))
        app.buttons["Add"].firstMatch.tap()

        XCTAssertTrue(app.navigationBars["Assign Room"].waitForExistence(timeout: 5))
        app.buttons["New room"].tap()
        app.textFields["e.g. Living Room"].tap()
        app.textFields["e.g. Living Room"].typeText("Living Room")
        app.buttons["Done"].tap()

        // Completing room assignment finishes onboarding and swaps to the main tab bar.
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 5))
    }
}
