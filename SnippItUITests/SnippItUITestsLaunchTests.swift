//
//  SnippItUITestsLaunchTests.swift
//  SnippItUITests
//
//  Created by Golam Wasy Arnob on 18.12.2024.
//

import XCTest

final class SnippItUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchEnvironment["SNIPPIT_TEST_LIBRARY"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["New Note"].firstMatch.waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
