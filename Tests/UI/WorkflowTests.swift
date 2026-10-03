import XCTest

@MainActor final class WorkflowTests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }
  func testCreateAndEditNotebook() {
    let app = XCUIApplication()
    app.launch()
    XCTAssertTrue(
      app.buttons["Create Document"].waitForExistence(timeout: 30), app.debugDescription)
    app.buttons["Create Document"].tap()
    XCTAssertTrue(app.buttons["Page details"].waitForExistence(timeout: 60), app.debugDescription)
    app.buttons["Page details"].tap()
    let title = app.textFields["page-title"]
    XCTAssertTrue(title.waitForExistence(timeout: 10))
    title.tap()
    title.typeText(
      String(repeating: XCUIKeyboardKey.delete.rawValue, count: 20) + "Review sketches")
    app.buttons["Insert"].tap()
    app.buttons["Rectangle"].tap()
    XCTAssertTrue(app.textFields["page-title"].value as? String == "Review sketches")
    let image = XCTAttachment(screenshot: app.screenshot())
    image.name = "Notebook canvas"
    image.lifetime = .keepAlways
    add(image)
    app.buttons["Page actions"].tap()
    app.buttons["Export notebook copy"].tap()
    XCTAssertTrue(app.buttons["Export"].waitForExistence(timeout: 20), app.debugDescription)
  }
}
