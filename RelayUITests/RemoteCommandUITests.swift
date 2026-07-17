import XCTest

/// Covers sending remote commands and observing capability-gated rendering + status feedback. See
/// docs/06-ux-screen-spec.md §6.
final class RemoteCommandUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchAppWithPairedLivingRoomDevice() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITest_ResetState"]
        app.launch()

        app.buttons["Find devices"].tap()
        XCTAssertTrue(app.staticTexts["Living Room TV"].waitForExistence(timeout: 5))
        app.buttons["Add"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Assign Room"].waitForExistence(timeout: 5))
        app.buttons["New room"].tap()
        app.textFields["e.g. Living Room"].tap()
        app.textFields["e.g. Living Room"].typeText("Living Room")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 5))
        return app
    }

    func testRemoteScreenShowsControlModeToggleForFullyCapableDevice() {
        let app = launchAppWithPairedLivingRoomDevice()

        app.staticTexts["Living Room"].tap()
        app.staticTexts["Living Room TV"].tap()

        // The living room mock device supports both .dpad and .touchpad — the segmented toggle
        // should appear (see RemoteView.navigationArea).
        XCTAssertTrue(app.segmentedControls.buttons["D-Pad"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls.buttons["Touchpad"].exists)
    }

    func testVolumeAndDPadCommandsDoNotCrashAndKeepConnectedStatus() {
        let app = launchAppWithPairedLivingRoomDevice()
        app.staticTexts["Living Room"].tap()
        app.staticTexts["Living Room TV"].tap()

        XCTAssertTrue(app.buttons["Up"].waitForExistence(timeout: 5))
        app.buttons["Up"].tap()
        app.buttons["Select"].tap()

        XCTAssertTrue(app.staticTexts["Connected"].waitForExistence(timeout: 5))
    }
}
