//
//  SettingsWindowTests.swift
//  Media MuncherUITests
//
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import XCTest

final class SettingsWindowTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    // MARK: - Settings Window

    func testCmdCommaOpensSettings() throws {
        app.typeKey(",", modifierFlags: .command)

        let settingsWindow = app.windows["Media Muncher Settings"]
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 3), "Cmd+, should open Settings window")
    }

    func testSettingsWindowClosesWithCmdW() throws {
        app.typeKey(",", modifierFlags: .command)

        let settingsWindow = app.windows["Media Muncher Settings"]
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 3))

        app.typeKey("w", modifierFlags: .command)

        // The settings window should close
        XCTAssertTrue(settingsWindow.waitForNonExistence(timeout: 3), "Cmd+W should close Settings window")
    }

    // MARK: - Settings Controls

    func testOrganizeByDateTogglePresent() throws {
        app.typeKey(",", modifierFlags: .command)
        let settingsWindow = app.windows["Media Muncher Settings"]
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 3))

        let toggle = settingsWindow.checkBoxes["organizeByDateToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 2), "Organize by date toggle should be present")
    }

    func testRenameByDateTogglePresent() throws {
        app.typeKey(",", modifierFlags: .command)
        let settingsWindow = app.windows["Media Muncher Settings"]
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 3))

        let toggle = settingsWindow.checkBoxes["renameByDateToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 2), "Rename by date toggle should be present")
    }

    func testFilterTogglesPresent() throws {
        app.typeKey(",", modifierFlags: .command)
        let settingsWindow = app.windows["Media Muncher Settings"]
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 3))

        let images = settingsWindow.checkBoxes["filterImagesToggle"]
        let videos = settingsWindow.checkBoxes["filterVideosToggle"]
        let audio = settingsWindow.checkBoxes["filterAudioToggle"]
        let raw = settingsWindow.checkBoxes["filterRawToggle"]

        XCTAssertTrue(images.waitForExistence(timeout: 2), "Images filter toggle should be present")
        XCTAssertTrue(videos.exists, "Videos filter toggle should be present")
        XCTAssertTrue(audio.exists, "Audio filter toggle should be present")
        XCTAssertTrue(raw.exists, "RAW filter toggle should be present")
    }

    func testImportOptionsPresent() throws {
        app.typeKey(",", modifierFlags: .command)
        let settingsWindow = app.windows["Media Muncher Settings"]
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 3))

        let deleteOriginals = settingsWindow.checkBoxes["deleteOriginalsToggle"]
        let autoEject = settingsWindow.checkBoxes["autoEjectToggle"]

        XCTAssertTrue(deleteOriginals.waitForExistence(timeout: 2), "Delete originals toggle should be present")
        XCTAssertTrue(autoEject.exists, "Auto-eject toggle should be present")
    }
}
