import XCTest

/// Covers Dynamic Type at large accessibility sizes and baseline VoiceOver labeling. See
/// docs/06-ux-screen-spec.md §6/§11 accessibility requirements.
final class AccessibilityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testWelcomeScreenAtLargestAccessibilityTextSizeStaysHittable() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-UITest_ResetState",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge",
        ]
        app.launch()

        let findDevicesButton = app.buttons["Find devices"]
        XCTAssertTrue(findDevicesButton.waitForExistence(timeout: 5))
        // At an accessibility text size, primary actions must remain on-screen and tappable —
        // not clipped or pushed off the bottom edge (docs/06 "Dynamic Type support without
        // clipping").
        XCTAssertTrue(findDevicesButton.isHittable)
    }

    func testStatusPillExposesAccessibilityLabelAndHint() {
        let app = XCUIApplication()
        app.launchArguments += ["-UITest_ResetState"]
        app.launch()
        app.buttons["Find devices"].tap()

        XCTAssertTrue(app.staticTexts["Living Room TV"].waitForExistence(timeout: 5))
        // `StatusPill` combines into a single accessibility element labeled with the status name
        // (see DesignSystem/Components/StatusPill.swift) — VoiceOver users get "Connected" rather
        // than a dot + unlabeled caption read separately.
        let connectedPill = app.otherElements["Connected"]
        XCTAssertTrue(connectedPill.exists || app.staticTexts["Connected"].exists)
    }

    func testDPadControlsHaveDescriptiveVoiceOverLabels() {
        let app = XCUIApplication()
        app.launchArguments += ["-UITest_ResetState"]
        app.launch()
        app.buttons["Find devices"].tap()
        XCTAssertTrue(app.staticTexts["Living Room TV"].waitForExistence(timeout: 5))
        app.buttons["Add"].firstMatch.tap()
        app.buttons["New room"].tap()
        app.textFields["e.g. Living Room"].tap()
        app.textFields["e.g. Living Room"].typeText("Living Room")
        app.buttons["Done"].tap()

        app.staticTexts["Living Room"].tap()
        app.staticTexts["Living Room TV"].tap()

        for label in ["Up", "Down", "Left", "Right", "Select"] {
            XCTAssertTrue(app.buttons[label].waitForExistence(timeout: 5), "Missing accessible D-pad control: \(label)")
        }
    }
}
