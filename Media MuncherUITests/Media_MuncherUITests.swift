//
//  Media_MuncherUITests.swift
//  Media MuncherUITests
//
//  Created by Toni Melisma on 2/13/25.
//

import XCTest

final class Media_MuncherUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it's important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testShowsNoVolumePlaceholder() throws {
        let app = XCUIApplication()
        app.launch()

        // Expect the placeholder text to be visible when no removable volumes are attached.
        let placeholder = app.staticTexts["Select a volume to begin"]
        XCTAssertTrue(placeholder.waitForExistence(timeout: 3), "The no-volume placeholder should appear on launch when no removable devices are present.")
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
