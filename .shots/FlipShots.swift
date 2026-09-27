import XCTest

final class FlipShots: XCTestCase {
    var app: XCUIApplication!
    let out = ProcessInfo.processInfo.environment["SHOT_DIR"] ?? "/tmp"
    func shot(_ n: String) {
        Thread.sleep(forTimeInterval: 0.9)
        try? app.windows.firstMatch.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(out)/\(n).png"))
    }
    func testFlip() {
        app = XCUIApplication(); app.launchArguments = ["-FFLocalOnly", "-FFTab", "train"]; app.launch()
        Thread.sleep(forTimeInterval: 2)
        app.buttons["Exercises"].tap(); shot("f1-top")
        let chest = app.buttons["Chest"].firstMatch
        // swipe up starting on the body: page should scroll
        let start = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        start.press(forDuration: 0.05, thenDragTo: app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)))
        shot("f2-scrolled")
        // horizontal swipe on the body flips it
        let body = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        body.press(forDuration: 0.05, thenDragTo: app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.46)))
        shot("f3-swiped")
        XCTAssert(app.buttons["Lower back"].exists, "swipe did not flip to back")
        app.buttons["Show front"].tap(); shot("f4-button")
        XCTAssert(chest.exists)
        app.buttons["Show favourites"].tap(); shot("f5-favs")
    }
}
