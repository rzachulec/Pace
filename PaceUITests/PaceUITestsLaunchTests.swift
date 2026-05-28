//
//  PaceUITestsLaunchTests.swift
//  PaceUITests
//
//  Created by jan on 11/02/2025.
//

import XCTest

// runsForEachTargetApplicationUIConfiguration = true makes Xcode repeat every
// test in this class for each device/OS/orientation configured in the scheme's
// test plan — covering different screen proportions, resolutions and pixel
// densities without duplicating test code.

final class PaceUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Launch screenshots

    @MainActor
    func testLaunchTodayTab() throws {
        let app = XCUIApplication()
        app.launch()
        attach(app.screenshot(), name: "01 — Today tab (portrait)")
    }

    @MainActor
    func testLaunchWeekTab() throws {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Week"].tap()
        attach(app.screenshot(), name: "02 — Week tab (portrait)")
    }

    @MainActor
    func testLaunchSettingsTab() throws {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Edit"].tap()
        attach(app.screenshot(), name: "03 — Settings tab (portrait)")
    }

    @MainActor
    func testLaunchLandscapeTodayTab() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launch()
        attach(app.screenshot(), name: "04 — Today tab (landscape)")
    }

    @MainActor
    func testLaunchLandscapeWeekTab() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Week"].tap()
        attach(app.screenshot(), name: "05 — Week tab (landscape)")
    }

    @MainActor
    func testLaunchAddTaskSheet() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Add Task"].firstMatch.tap()
        _ = app.navigationBars["New Task"].waitForExistence(timeout: 3)
        attach(app.screenshot(), name: "06 — Add Task sheet")
    }

    // MARK: - Helper

    private func attach(_ screenshot: XCUIScreenshot, name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
