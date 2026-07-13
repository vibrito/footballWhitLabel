import XCTest

@MainActor
final class SnapshotUITests: XCTestCase {
    private var targetBundleID: String {
        // The scheme declares this variable so xcodebuild can forward it when explicitly
        // passed as a build setting (see the screenshots lane) — but that declaration
        // means it's always present in the environment, just empty when nothing was
        // passed (e.g. plain `scan`/`fastlane test`), not absent. Nil-coalescing alone
        // wouldn't catch that.
        let value = ProcessInfo.processInfo.environment["SNAPSHOT_BUNDLE_ID"]
        return (value?.isEmpty ?? true) ? "com.vibrito.br2026" : value!
    }

    func testCaptureScreenshots() {
        let app = XCUIApplication(bundleIdentifier: targetBundleID)
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
