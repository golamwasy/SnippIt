import XCTest

final class SnippItUITests: XCTestCase {
    @MainActor
    func testNotesReturnAfterQuittingAndRelaunching() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["SNIPPIT_TEST_LIBRARY"] = UUID().uuidString
        app.launch()

        let newNote = app.buttons["New Note"].firstMatch
        XCTAssertTrue(newNote.waitForExistence(timeout: 5))
        app.typeKey("n", modifierFlags: .command)
        let editor = app.textViews["noteEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.click()
        let text = "Remember this after restarting.\nSecond line\nThird line\n"
        editor.typeText(text)
        XCTAssertEqual(editor.value as? String, text)

        // No pause or manual Save before exiting.
        app.terminate()
        app.launch()
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertEqual(editor.value as? String, text)
        XCTAssertTrue(app.staticTexts["Saved on this Mac"].exists)

        // Clearing a note must also be durable.
        editor.click()
        editor.typeKey("a", modifierFlags: .command)
        editor.typeKey(.delete, modifierFlags: [])
        app.terminate()
        app.launch()
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertEqual(editor.value as? String, "")
        app.terminate()
    }

    @MainActor
    func testAutomaticTitleRenameAndTrashRecovery() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["SNIPPIT_TEST_LIBRARY"] = UUID().uuidString
        app.launch()
        app.typeKey("n", modifierFlags: .command)
        let editor = app.textViews["noteEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        let title = app.textFields["noteTitle"]
        // Focusing the title without editing it must not pin the automatic title.
        title.click()
        editor.click()
        editor.typeText("Weekend plans\nWalk by the sea.")
        XCTAssertEqual(title.value as? String, "Weekend plans")
        title.click()
        title.typeKey("a", modifierFlags: .command)
        title.typeText("My plans")
        title.typeKey(.return, modifierFlags: [])
        editor.click()
        editor.typeKey(.downArrow, modifierFlags: .command)
        editor.typeText("\nBring coffee.")
        XCTAssertEqual(title.value as? String, "My plans")

        app.descendants(matching: .any).matching(identifier: "noteActions").firstMatch.click()
        app.menuItems["Move to Recently Deleted"].click()
        XCTAssertFalse(editor.exists)
        app.buttons["Recently Deleted"].click()
        XCTAssertTrue(app.buttons["Restore"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["Restore"].firstMatch.click()
        app.buttons["Done"].click()
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertEqual(editor.value as? String, "Weekend plans\nWalk by the sea.\nBring coffee.")
        XCTAssertEqual(title.value as? String, "My plans")
        app.terminate()
        app.launch()
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertEqual(title.value as? String, "My plans")
        XCTAssertEqual(editor.value as? String, "Weekend plans\nWalk by the sea.\nBring coffee.")
        app.terminate()
    }

    @MainActor
    func testEditorWithWrappedAndScrolledLines() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["SNIPPIT_TEST_LIBRARY"] = UUID().uuidString
        app.launch()
        app.buttons["New Note"].firstMatch.click()
        let editor = app.textViews["noteEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.click()
        let wrapped = "This is a longer thought that wraps naturally in the editor. "
        let text = "A place for ideas\n\n" + String(repeating: wrapped, count: 6)
            + "\n\n" + (5...45).map { "Line \($0): a small note for later." }.joined(separator: "\n") + "\n"
        editor.typeText(text)
        XCTAssertEqual(editor.value as? String, text)

        editor.typeKey(.upArrow, modifierFlags: [.command])
        let top = XCTAttachment(screenshot: app.screenshot())
        top.name = "Editor — wrapped lines"
        top.lifetime = .keepAlways
        add(top)

        editor.typeKey(.downArrow, modifierFlags: [.command])
        let bottom = XCTAttachment(screenshot: app.screenshot())
        bottom.name = "Editor — scrolled lines"
        bottom.lifetime = .keepAlways
        add(bottom)
        app.terminate()
    }
}
