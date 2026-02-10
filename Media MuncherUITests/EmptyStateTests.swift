//
//  EmptyStateTests.swift
//  Media MuncherUITests
//
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import XCTest

final class EmptyStateTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    // MARK: - Empty State (No Volume)

    func testEmptyStateGuidanceShown() throws {
        // Without a USB volume connected, either the "select a volume" label
        // or the "no volumes" label should be visible
        let selectVolumeLabel = app.staticTexts["selectVolumeLabel"]
        let noVolumesLabel = app.staticTexts["noVolumesLabel"]

        let eitherExists = selectVolumeLabel.waitForExistence(timeout: 3) || noVolumesLabel.exists
        XCTAssertTrue(eitherExists, "Empty state should show guidance text when no volume is connected")
    }

    func testNoMediaGridWhenNoVolume() throws {
        // The media grid should not be visible when there's no volume
        let mediaGrid = app.otherElements["mediaGrid"]
        // Give the app a moment to settle, then check
        _ = app.windows.firstMatch.waitForExistence(timeout: 2)
        XCTAssertFalse(mediaGrid.exists, "Media grid should not be visible when no volume is selected")
    }

    func testErrorBannerNotVisibleOnLaunch() throws {
        // There should be no error banner on a clean launch
        _ = app.windows.firstMatch.waitForExistence(timeout: 2)
        let errorBanner = app.otherElements["errorBanner"]
        XCTAssertFalse(errorBanner.exists, "Error banner should not be visible on a clean launch")
    }
}
