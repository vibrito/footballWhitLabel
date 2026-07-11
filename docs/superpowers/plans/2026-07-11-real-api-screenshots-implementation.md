# Real API Screenshots Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the `screenshots` fastlane lane capture App Store screenshots against the real
live API instead of `MockMatchService`, per
`docs/superpowers/specs/2026-07-11-real-api-screenshots-design.md`.

**Architecture:** Delete the snapshot-specific mock override in `Championship.swift` so service
selection is identical for snapshot and normal launches (live API first, mock only as a
missing-key fallback). Delete the test that covers the removed method. Bump the UI test's fixed
sleeps to tolerate real network latency. Update CLAUDE.md to describe the new behavior.

**Tech Stack:** Swift Testing (`@Test`, `@Suite`), XCUITest (`BR2026UITests`), fastlane
`snapshot`.

## Global Constraints

- No force-unwraps (`!`) outside tests. (CLAUDE.md Coding Guidelines)
- `Secrets.xcconfig` must be configured with a real API key for the `screenshots` lane to
  produce non-empty screenshots going forward — this plan doesn't add a new check for that; the
  existing `LiveMatchService.makeFromBundle` throw-and-fall-back-to-mock behavior already covers
  a missing key. (Design spec, Service Selection)
- No CI workflow exists for the `screenshots` lane — no CI-secrets handling in scope. (Design
  spec, Out of Scope)

---

## Task 1: Remove snapshot-forces-mock service selection

**Files:**
- Modify: `BR2026/App/Championship.swift`
- Delete: `BR2026Tests/App/ChampionshipServiceSelectionTests.swift`

**Interfaces:**
- Removes: `ChampionshipApp.shouldUseMockService(arguments:)` (static method, previously
  consumed only by `makeService()` and the deleted test — no other call sites exist in the
  codebase).
- `makeService()` keeps its existing signature (`private func makeService() -> MatchService`)
  and its existing missing-key fallback to `MockMatchService()` — only the snapshot-specific
  branch is removed.

- [ ] **Step 1: Delete the snapshot-forces-mock branch in `Championship.swift`**

Current `makeService()` (for reference — this is what's in the file today):

```swift
    static func shouldUseMockService(arguments: [String]) -> Bool {
        arguments.contains("-FASTLANE_SNAPSHOT")
    }

    private func makeService() -> MatchService {
        // fastlane's `snapshot` action passes -FASTLANE_SNAPSHOT as a launch argument (not an
        // environment variable); screenshots must use fixed mock data regardless of the live
        // season/API state.
        if Self.shouldUseMockService(arguments: ProcessInfo.processInfo.arguments) {
            return MockMatchService()
        }
        // Falls back to mock data if Secrets.xcconfig hasn't been set up yet, so the app
        // still runs in Simulator before a real API key is configured.
        let context = ModelContext(modelContainer)
        if let live = try? LiveMatchService.makeFromBundle(config: config, modelContext: context) {
            return live
        }
        return MockMatchService()
    }
```

Replace it with:

```swift
    private func makeService() -> MatchService {
        // Falls back to mock data if Secrets.xcconfig hasn't been set up yet, so the app
        // still runs in Simulator before a real API key is configured. This also covers
        // fastlane's `screenshots` lane — screenshots are captured against the real API.
        let context = ModelContext(modelContainer)
        if let live = try? LiveMatchService.makeFromBundle(config: config, modelContext: context) {
            return live
        }
        return MockMatchService()
    }
```

- [ ] **Step 2: Delete the now-obsolete test file**

```bash
rm BR2026Tests/App/ChampionshipServiceSelectionTests.swift
```

- [ ] **Step 3: Run the full test suite to confirm nothing else references the removed method**

Run: `bundle exec fastlane test`
Expected: PASS, no references to `shouldUseMockService` remain (the suite would fail to compile
otherwise, since it's a `@testable import` of `BR2026`).

- [ ] **Step 4: Commit**

```bash
git add BR2026/App/Championship.swift BR2026Tests/App/ChampionshipServiceSelectionTests.swift
git commit -m "Always use the real API for service selection, including screenshots"
```

---

## Task 2: Tolerate real network latency in the screenshot UI test

**Files:**
- Modify: `BR2026UITests/SnapshotUITests.swift`

**Interfaces:**
- No new interfaces — this task only changes literal `sleep(...)` durations inside
  `testCaptureScreenshots()`. Nothing else in the codebase calls into this file.

- [ ] **Step 1: Bump the fixed sleeps**

Current `BR2026UITests/SnapshotUITests.swift`:

```swift
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
        sleep(2)
        snapshot("01Matchday")

        tabBar.buttons.element(boundBy: 1).tap()
        sleep(1)
        snapshot("02Fixtures")

        tabBar.buttons.element(boundBy: 2).tap()
        sleep(1)
        snapshot("03Standings")

        tabBar.buttons.element(boundBy: 3).tap()
        sleep(1)
        snapshot("04More")
    }
}
```

Replace it with (every tab now fetches over the real network, including the `04More` tab's
predecessor `03Standings`, so every wait is bumped, not just the first):

```swift
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
```

(`04More` stays at `sleep(1)` — that tab is static content with no `MatchService` call, per
`MoreViewModel`.)

- [ ] **Step 2: Commit**

```bash
git add BR2026UITests/SnapshotUITests.swift
git commit -m "Give screenshot capture more time for real network responses"
```

---

## Task 3: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md:200-205`

**Interfaces:** None — documentation only.

- [ ] **Step 1: Replace the outdated snapshot-determinism paragraph**

Current (`CLAUDE.md:200-205`):

```markdown
`BR2026UITests` is a dedicated XCUITest target (not part of the Swift Testing unit suite),
used only by the `screenshots` lane — its tab navigation taps `tabBars.buttons` by index
(SwiftUI `TabView` tab bar buttons don't propagate `.accessibilityIdentifier`, verified
empirically). `Championship.swift` returns `MockMatchService` whenever the `-FASTLANE_SNAPSHOT`
launch argument is present (which `snapshot` sets automatically via `app.launchArguments`), so
screenshots are deterministic regardless of the live season/API state.
```

Replace with:

```markdown
`BR2026UITests` is a dedicated XCUITest target (not part of the Swift Testing unit suite),
used only by the `screenshots` lane — its tab navigation taps `tabBars.buttons` by index
(SwiftUI `TabView` tab bar buttons don't propagate `.accessibilityIdentifier`, verified
empirically). The `screenshots` lane hits the real live API — `Secrets.xcconfig` must be
configured with a real API key before running it (see Backend API section), and captured
screenshots reflect whatever matches/standings are live or scheduled at capture time.
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "Document that the screenshots lane now hits the real API"
```
