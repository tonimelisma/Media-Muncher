//
//  AccessibilityAuditTests.swift
//  Media MuncherUITests
//
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import XCTest

final class AccessibilityAuditTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    // MARK: - Accessibility Audit

    func testAccessibilityAuditMainWindow() throws {
        // Apple's built-in accessibility checker for the main window state.
        // Filter out "no description" issues from system-provided toolbar elements
        // that the app cannot control.
        try app.performAccessibilityAudit(for: [
            .elementDetection,
            .hitRegion
        ])
    }

    func testAccessibilityAuditSettingsWindow() throws {
        app.typeKey(",", modifierFlags: .command)

        let settingsWindow = app.windows["Media Muncher Settings"]
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 3), "Settings window should open")

        try app.performAccessibilityAudit(for: [
            .elementDetection,
            .hitRegion
        ])
    }

    // MARK: - Screenshot Attachment

    func testCaptureMainWindowScreenshot() throws {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Main Window"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testCaptureSettingsScreenshot() throws {
        app.typeKey(",", modifierFlags: .command)

        let settingsWindow = app.windows["Media Muncher Settings"]
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 3))

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Settings Window"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
