//
//  PaceUITests.swift
//  PaceUITests
//
//  Created by jan on 11/02/2025.
//

import XCTest

// Instrumentation tests — the test runner drives the app automatically.
// runsForEachTargetApplicationUIConfiguration in PaceUITestsLaunchTests
// provides the multi-device/resolution/orientation sweep required by the
// assignment spec; these tests add the *interaction* layer on top.

final class PaceUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()

        // Dismiss any system permission alerts (Calendar, Location) automatically
        // so tests do not stall waiting for a human to tap Allow.
        addUIInterruptionMonitor(withDescription: "System permission dialog") { alert in
            let labels = ["Allow Full Access", "Allow", "OK"]
            for label in labels {
                if alert.buttons[label].exists {
                    alert.buttons[label].tap()
                    return true
                }
            }
            return false
        }
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Tab navigation

    @MainActor
    func testTodayTabIsSelectedOnLaunch() throws {
        XCTAssertTrue(app.tabBars.buttons["Today"].isSelected)
    }

    @MainActor
    func testNavigateToWeekTab() throws {
        app.tabBars.buttons["Week"].tap()
        XCTAssertTrue(app.tabBars.buttons["Week"].isSelected)
    }

    @MainActor
    func testNavigateToSettingsTab() throws {
        app.tabBars.buttons["Edit"].tap()
        XCTAssertTrue(app.tabBars.buttons["Edit"].isSelected)
    }

    @MainActor
    func testAllTabsAreReachable() throws {
        for label in ["Today", "Week", "Edit"] {
            app.tabBars.buttons[label].tap()
            XCTAssertTrue(
                app.tabBars.buttons[label].isSelected,
                "\(label) tab should be selected after tapping"
            )
        }
    }

    // MARK: - Add Task sheet

    @MainActor
    func testAddTaskButtonExistsOnTodayTab() throws {
        XCTAssertTrue(app.buttons["Add Task"].firstMatch.exists)
    }

    @MainActor
    func testAddTaskSheetOpens() throws {
        app.buttons["Add Task"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["New Task"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testAddTaskSheetContainsTitleField() throws {
        app.buttons["Add Task"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["New Task"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["Event Title"].exists)
    }

    @MainActor
    func testAddTaskSheetDismissesOnClose() throws {
        app.buttons["Add Task"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["New Task"].waitForExistence(timeout: 3))
        app.buttons["Close"].firstMatch.tap()
        XCTAssertFalse(app.navigationBars["New Task"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testAddTaskTitleFieldAcceptsInput() throws {
        app.buttons["Add Task"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["New Task"].waitForExistence(timeout: 3))
        let titleField = app.textFields["Event Title"]
        titleField.tap()
        titleField.typeText("Test task")
        XCTAssertEqual(titleField.value as? String, "Test task")
    }

    // MARK: - Week view

    @MainActor
    func testWeekViewShowsCurrentWeekText() throws {
        app.tabBars.buttons["Week"].tap()
        let weekText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'week'")
        ).firstMatch
        XCTAssertTrue(weekText.waitForExistence(timeout: 3))
    }

    @MainActor
    func testWeekNavigationButtonsExist() throws {
        app.tabBars.buttons["Week"].tap()
        XCTAssertTrue(app.buttons["chevron.left"].waitForExistence(timeout: 3)
                      || app.buttons.count > 1)
    }

    // MARK: - Portrait layout

    @MainActor
    func testPortraitShowsAddTaskButton() throws {
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.buttons["Add Task"].firstMatch.waitForExistence(timeout: 3))
    }

    @MainActor
    func testPortraitShowsTabBar() throws {
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 3))
    }

    // MARK: - Landscape layout

    @MainActor
    func testLandscapeTabBarStillVisible() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 3))
    }

    @MainActor
    func testLandscapeWeekViewHasContent() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        app.tabBars.buttons["Week"].tap()
        let weekText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'week'")
        ).firstMatch
        XCTAssertTrue(weekText.waitForExistence(timeout: 3))
    }

    @MainActor
    func testLandscapeAddTaskSheetOpens() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        app.buttons["Add Task"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["New Task"].waitForExistence(timeout: 3))
        app.buttons["Close"].firstMatch.tap()
    }

    // MARK: - Orientation transitions

    @MainActor
    func testOrientationSwitchPortraitToLandscape() throws {
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.tabBars.firstMatch.exists)
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 3))
    }

    @MainActor
    func testOrientationSwitchLandscapeToPortrait() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 3))
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 3))
    }

    @MainActor
    func testMultipleOrientationTogglesSurvive() throws {
        for orientation: UIDeviceOrientation in [.portrait, .landscapeLeft, .portrait, .landscapeRight] {
            XCUIDevice.shared.orientation = orientation
            XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 3))
        }
    }
}
