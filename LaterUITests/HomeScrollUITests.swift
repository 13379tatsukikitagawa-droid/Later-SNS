import XCTest

/// v88/v89 A:黄緑の # ・ レンズの 上から なぞっても Home が たてに 動く
final class HomeScrollUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-debugRoute", "home", "-debugMock", "1", "-debugBackdrop", "1", "-debugPhoto", "d"]
        app.launch()
        return app
    }

    private func assertScrolls(dx: CGFloat, dy: CGFloat, file: StaticString = #filePath, line: UInt = #line) {
        let app = launch()
        let label = app.staticTexts["YESTERDAY"].firstMatch
        XCTAssertTrue(label.waitForExistence(timeout: 12), "下の かたまりが 見つからない", file: file, line: line)
        let before = label.frame.minY
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: dx, dy: dy))
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: dx, dy: max(0.02, dy - 0.28))))
        sleep(1)
        XCTAssertLessThan(label.frame.minY, before - 40, "たてに スクロール しなかった (dx \\(dx), dy \\(dy))", file: file, line: line)
    }

    func testScrollFromLeftHashBar() { assertScrolls(dx: 0.10, dy: 0.32) }
    func testScrollFromRightHashBar() { assertScrolls(dx: 0.90, dy: 0.32) }
    func testScrollFromLens() { assertScrolls(dx: 0.50, dy: 0.45) }
}
