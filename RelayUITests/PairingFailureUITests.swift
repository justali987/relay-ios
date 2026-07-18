import XCTest

/// Covers pairing failure and recovery: wrong PIN, PIN-required, and an unreachable device. See
/// docs/06-ux-screen-spec.md §3.
final class PairingFailureUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITest_ResetState"]
        app.launch()
        return app
    }

    func testWrongPINShowsRejectionAndAllowsRetry() {
        let app = launchApp()
        app.buttons["Find devices"].tap()

        XCTAssertTrue(app.staticTexts["Office Display"].waitForExistence(timeout: 5))
        app.buttons.matching(identifier: "Add").element(boundBy: 2).tap() // Office Display is the third discovered device

        XCTAssertTrue(app.textFields["PIN"].waitForExistence(timeout: 5))
        app.textFields["PIN"].tap()
        app.textFields["PIN"].typeText("0000")
        app.buttons["Pair"].tap()

        XCTAssertTrue(app.staticTexts["Incorrect PIN. Check the code shown on the TV."].waitForExistence(timeout: 5))

        // Recovery: correct PIN should succeed on retry. The field still holds "0000" from the
        // first attempt, and typeText appends — clear it first, or the value becomes "00001234"
        // and pairing fails again.
        let pinField = app.textFields["PIN"]
        pinField.tap()
        let existing = (pinField.value as? String) ?? ""
        if !existing.isEmpty {
            pinField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        }
        pinField.typeText("1234")
        app.buttons["Pair"].tap()

        XCTAssertTrue(app.navigationBars["Assign Room"].waitForExistence(timeout: 5))
    }

    func testUnreachableDeviceShowsClearError() {
        let app = launchApp()
        app.buttons["Find devices"].tap()

        XCTAssertTrue(app.staticTexts["Garage TV"].waitForExistence(timeout: 5))
        app.buttons.matching(identifier: "Add").element(boundBy: 3).tap() // Garage TV is the fourth discovered device

        XCTAssertTrue(app.staticTexts["Couldn't reach Garage TV. Make sure it's powered on and connected."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Try again"].exists)
    }
}
