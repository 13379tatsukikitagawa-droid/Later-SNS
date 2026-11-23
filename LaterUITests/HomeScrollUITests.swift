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
        let label = app.staticTexts["Today"].firstMatch   // P56 E で YESTERDAY は 日本語に なった
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

    /// v132 3章:Today の チェキ(指で 傾く)の 上から なぞっても Home が たてに 動く
    func testScrollFromTodayCheki() {
        let app = XCUIApplication()
        app.launchArguments += ["-debugRoute", "home", "-debugShots", "3", "-debugSection", "today:120"]
        app.launch()
        let label = app.staticTexts["Today"].firstMatch
        XCTAssertTrue(label.waitForExistence(timeout: 12), "Today が 見つからない")
        sleep(2)
        let before = label.frame.minY
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.23, dy: 0.36))
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.23, dy: 0.08)))
        sleep(1)
        XCTAssertLessThan(label.frame.minY, before - 40, "チェキの 上から スクロール しなかった")
    }
}
