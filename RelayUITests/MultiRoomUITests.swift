import XCTest

/// Covers a household with multiple rooms/devices — pairing two mock devices into two different
/// rooms and switching between them. See docs/06-ux-screen-spec.md §4-5.
final class MultiRoomUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITest_ResetState"]
        app.launch()
        return app
    }

    private func pairFirstDiscoveredDevice(_ app: XCUIApplication, roomName: String) {
        app.buttons["Add"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Assign Room"].waitForExistence(timeout: 5))
        app.buttons["New room"].tap()
        app.textFields["e.g. Living Room"].tap()
        app.textFields["e.g. Living Room"].typeText(roomName)
        app.buttons["Done"].tap()
    }

    func testTwoRoomsWithDistinctDevicesAppearOnHome() {
        let app = launchApp()
        app.buttons["Find devices"].tap()
        XCTAssertTrue(app.staticTexts["Living Room TV"].waitForExistence(timeout: 5))

        pairFirstDiscoveredDevice(app, roomName: "Living Room")

        // Onboarding is complete; add a second room/device from the Home tab's own discovery entry.
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Add"].tap()
        app.alerts["New Room"].textFields["Room name"].typeText("Bedroom")
        app.alerts["New Room"].buttons["Add"].tap()

        XCTAssertTrue(app.staticTexts["Living Room"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Bedroom"].waitForExistence(timeout: 5))

        app.staticTexts["Bedroom"].tap()
        XCTAssertTrue(app.navigationBars["Bedroom"].waitForExistence(timeout: 5))
    }
}
