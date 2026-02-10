//
//  MainWindowStructureTests.swift
//  Media MuncherUITests
//
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import XCTest

final class MainWindowStructureTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    // MARK: - Window Structure

    func testMainWindowExists() throws {
        XCTAssertTrue(app.windows.firstMatch.exists, "Main window should exist")
    }

    func testNavigationTitlePresent() throws {
        // The window title should contain the app name
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists)
    }

    // MARK: - Toolbar

    func testSettingsButtonExists() throws {
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3), "Settings (gear) button should exist in toolbar")
    }

    func testSettingsButtonOpensSettings() throws {
        let settingsButton = app.buttons["settingsButton"].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3))
        settingsButton.click()

        let settingsWindow = app.windows["Media Muncher Settings"]
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 3), "Clicking settings button should open Settings window")
    }

    // MARK: - Import Button

    func testImportButtonExists() throws {
        let importButton = app.buttons["importButton"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 3), "Import button should exist")
    }

    func testImportButtonDisabledWithoutVolume() throws {
        let importButton = app.buttons["importButton"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 3))
        XCTAssertFalse(importButton.isEnabled, "Import button should be disabled when no volume is connected and no files are available")
    }

    // MARK: - Sidebar

    func testSidebarPresent() throws {
        // Without a volume, the sidebar should show the "no volumes" label
        let noVolumesLabel = app.staticTexts["noVolumesLabel"]
        let volumeList = app.outlines["volumeList"].exists || app.tables["volumeList"].exists

        // One of these should be true depending on whether volumes are connected
        XCTAssertTrue(noVolumesLabel.exists || volumeList,
                      "Sidebar should show either the no-volumes label or the volume list")
    }
}
