//
//  pinch_promptsUITests.swift
//  pinch promptsUITests
//
//  Created by Michael Lee on 4/17/26.
//

import XCTest

final class pinch_promptsUITests: XCTestCase {
    private enum AccessibilityIdentifier {
        static let conversationScrollView = "conversation-scroll-view"
        static let promptNavigatorCloseButton = "prompt-navigator-close-button"
    }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testPinchInOpensPromptNavigatorAndAllowsReopenAfterClose() throws {
        let app = XCUIApplication()
        app.launch()

        let conversationScrollView = app.scrollViews[AccessibilityIdentifier.conversationScrollView]
        XCTAssertTrue(conversationScrollView.waitForExistence(timeout: 2))

        let closeButton = app.buttons[AccessibilityIdentifier.promptNavigatorCloseButton]

        conversationScrollView.pinch(withScale: 0.5, velocity: 1.0)
        XCTAssertTrue(closeButton.waitForExistence(timeout: 2))

        closeButton.tap()
        XCTAssertTrue(closeButton.waitForNonExistence(timeout: 2))

        conversationScrollView.pinch(withScale: 0.5, velocity: 1.0)
        XCTAssertTrue(closeButton.waitForExistence(timeout: 2))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
