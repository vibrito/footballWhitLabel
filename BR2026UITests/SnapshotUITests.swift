import XCTest

@MainActor
final class SnapshotUITests: XCTestCase {
    func testCaptureScreenshots() {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()

        let tabBar = app.tabBars.firstMatch
        _ = tabBar.waitForExistence(timeout: 10)

        tabBar.buttons.element(boundBy: 0).tap()
        sleep(5)
        snapshot("01Matchday")

        tabBar.buttons.element(boundBy: 1).tap()
        sleep(5)
        snapshot("02Fixtures")

        tabBar.buttons.element(boundBy: 2).tap()
        sleep(5)
        snapshot("03Standings")

        tabBar.buttons.element(boundBy: 3).tap()
        sleep(1)
        snapshot("04More")
    }
}
