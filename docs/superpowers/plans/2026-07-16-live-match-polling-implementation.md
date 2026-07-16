# Live Match Polling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Matchday, Fixtures, and Match Detail automatically refresh every 30 seconds while a
match is `.live`, without the user pulling to refresh, pausing while the app is backgrounded
and refreshing immediately on return.

**Architecture:** A new stateless `LivePoller` helper runs a cancellable `Task` loop from
inside each screen's `.task(id:)` modifier — no manual `Task` storage or `.cancel()`
bookkeeping, since SwiftUI's structured concurrency cancels it automatically on disappear or
`id:` change. Each of the three ViewModels exposes a plain `hasLiveMatch`/`isLive` computed
property (unit-testable) that `LivePoller` polls to decide whether to keep going.

**Tech Stack:** Swift Concurrency (`Task`, `Task.sleep(for:)`), SwiftUI `.task(id:)` +
`@Environment(\.scenePhase)`, Swift Testing.

## Global Constraints

- Poll interval: 30 seconds, only while a `.live` match is present in the screen's current
  data (from `docs/superpowers/specs/2026-07-16-live-match-polling-design.md`).
- Scope: Matchday, Fixtures, Match Detail only. Standings is unaffected.
- No `UIKit`, no force-unwraps outside tests, `@Observable` over `ObservableObject` — repo
  conventions from `CLAUDE.md`.
- Unit test ViewModels/Services, not Views — View-layer tasks in this plan are verified via
  build + manual simulator check instead of Swift Testing.
- Use `MockMatchService`-family test doubles already in the test target
  (`StubMatchService`, declared in `BR2026Tests/ViewModels/MatchdayViewModelTests.swift`,
  visible target-wide) — no SwiftData container in unit tests.

---

### Task 1: `LivePoller` helper

**Files:**
- Create: `BR2026/Services/LivePoller.swift`
- Test: `BR2026Tests/Services/LivePollerTests.swift`

**Interfaces:**
- Produces: `LivePoller.run(interval: Duration, shouldContinue: () -> Bool, action: () async -> Void) async` — a `@MainActor` static function. Tasks 2-4 call this from each ViewModel's `pollWhileLive()`.

- [ ] **Step 1: Write the failing test**

```swift
// BR2026Tests/Services/LivePollerTests.swift
import Testing
@testable import BR2026

@Suite("LivePoller")
@MainActor
struct LivePollerTests {
    @Test("does not call action when shouldContinue is false from the start")
    func neverCallsActionWhenShouldContinueIsFalse() async {
        var actionCallCount = 0

        await LivePoller.run(interval: .seconds(30), shouldContinue: { false }, action: { actionCallCount += 1 })

        #expect(actionCallCount == 0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: FAIL to build — `Cannot find 'LivePoller' in scope`

- [ ] **Step 3: Write minimal implementation**

```swift
// BR2026/Services/LivePoller.swift
import Foundation

// @MainActor because every current caller (MatchdayViewModel, FixturesViewModel,
// MatchDetailViewModel) is itself @MainActor-isolated — avoids any ambiguity about which
// actor the shouldContinue/action closures run on.
@MainActor
enum LivePoller {
    static func run(interval: Duration, shouldContinue: () -> Bool, action: () async -> Void) async {
        while !Task.isCancelled && shouldContinue() {
            try? await Task.sleep(for: interval)
            guard !Task.isCancelled && shouldContinue() else { break }
            await action()
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: All tests pass, including `LivePollerTests`.

- [ ] **Step 5: Commit**

```bash
git add BR2026/Services/LivePoller.swift BR2026Tests/Services/LivePollerTests.swift
git commit -m "Add LivePoller: a cancellable Task-loop helper for live-match polling"
```

---

### Task 2: `MatchdayViewModel` — `hasLiveMatch`, `refreshIfNeeded`, `pollWhileLive`

**Files:**
- Modify: `BR2026/ViewModels/MatchdayViewModel.swift`
- Modify: `BR2026Tests/ViewModels/MatchdayViewModelTests.swift`

**Interfaces:**
- Consumes: `LivePoller.run(interval:shouldContinue:action:)` from Task 1.
- Produces: `MatchdayViewModel.hasLiveMatch: Bool`, `MatchdayViewModel.refreshIfNeeded() async`, `MatchdayViewModel.pollWhileLive() async` — Task 5 (`MatchdayView`) calls `refreshIfNeeded()` and `pollWhileLive()`.

- [ ] **Step 1: Write the failing tests**

Add to `BR2026Tests/ViewModels/MatchdayViewModelTests.swift` (inside the existing
`MatchdayViewModelTests` struct, alongside the other `@Test` methods — the file already
declares `private let team` and a `date(day:hour:)` helper used below):

```swift
@Test("hasLiveMatch is true when any match is live")
func hasLiveMatchTrueWhenLive() async {
    let live = Match(
        id: 1, utcDate: date(day: 10, hour: 15), status: .live, matchday: 1, stage: "REGULAR_SEASON",
        homeTeam: team, awayTeam: team, homeScore: 1, awayScore: 0, winner: nil, venue: nil, minute: 30
    )
    let service = StubMatchService(matches: [live], standings: [])
    let themeStore = TeamThemeStore(setting: StubTeamThemeSetting(), service: service)
    let viewModel = MatchdayViewModel(service: service, themeStore: themeStore)

    await viewModel.load()

    #expect(viewModel.hasLiveMatch == true)
}

@Test("hasLiveMatch is false when no match is live")
func hasLiveMatchFalseWhenNoneLive() async {
    let scheduled = Match(
        id: 1, utcDate: date(day: 10, hour: 15), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
        homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
    )
    let service = StubMatchService(matches: [scheduled], standings: [])
    let themeStore = TeamThemeStore(setting: StubTeamThemeSetting(), service: service)
    let viewModel = MatchdayViewModel(service: service, themeStore: themeStore)

    await viewModel.load()

    #expect(viewModel.hasLiveMatch == false)
}

@Test("refreshIfNeeded does the one-time cache-then-refresh on its first call")
func refreshIfNeededFirstCallLoadsOnce() async {
    let scheduled = Match(
        id: 1, utcDate: date(day: 10, hour: 15), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
        homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
    )
    let service = StubMatchService(matches: [scheduled], standings: [])
    let themeStore = TeamThemeStore(setting: StubTeamThemeSetting(), service: service)
    let viewModel = MatchdayViewModel(service: service, themeStore: themeStore)

    await viewModel.refreshIfNeeded()

    #expect(service.fetchMatchesCallCount == 1)
}

@Test("refreshIfNeeded refetches on every subsequent call")
func refreshIfNeededSubsequentCallsAlwaysRefetch() async {
    let scheduled = Match(
        id: 1, utcDate: date(day: 10, hour: 15), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
        homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
    )
    let service = StubMatchService(matches: [scheduled], standings: [])
    let themeStore = TeamThemeStore(setting: StubTeamThemeSetting(), service: service)
    let viewModel = MatchdayViewModel(service: service, themeStore: themeStore)

    await viewModel.refreshIfNeeded()
    await viewModel.refreshIfNeeded()
    await viewModel.refreshIfNeeded()

    #expect(service.fetchMatchesCallCount == 3)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: FAIL to build — `Value of type 'MatchdayViewModel' has no member 'hasLiveMatch'` (and `refreshIfNeeded`).

- [ ] **Step 3: Write minimal implementation**

In `BR2026/ViewModels/MatchdayViewModel.swift`, add these three members (anywhere inside
the class body — e.g. directly after the existing `load()` method):

```swift
var hasLiveMatch: Bool {
    matches.contains { $0.status == .live }
}

// Distinguishes "first activation" (cache-then-refresh-once, matching loadOnce()'s
// existing semantics) from "returning from background" (always refetch) — see the
// design doc for why this can't just be two independent .task modifiers.
func refreshIfNeeded() async {
    if hasLoadedOnce {
        await load()
    } else {
        await loadOnce()
    }
}

func pollWhileLive() async {
    await LivePoller.run(interval: .seconds(30), shouldContinue: { hasLiveMatch }, action: { await load() })
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add BR2026/ViewModels/MatchdayViewModel.swift BR2026Tests/ViewModels/MatchdayViewModelTests.swift
git commit -m "Add MatchdayViewModel.hasLiveMatch/refreshIfNeeded/pollWhileLive"
```

---

### Task 3: `FixturesViewModel` — same three members

**Files:**
- Modify: `BR2026/ViewModels/FixturesViewModel.swift`
- Modify: `BR2026Tests/ViewModels/FixturesViewModelTests.swift`

**Interfaces:**
- Consumes: `LivePoller.run(interval:shouldContinue:action:)` from Task 1.
- Produces: `FixturesViewModel.hasLiveMatch: Bool`, `FixturesViewModel.refreshIfNeeded() async`, `FixturesViewModel.pollWhileLive() async` — Task 6 (`FixturesView`) calls `refreshIfNeeded()` and `pollWhileLive()`.

- [ ] **Step 1: Write the failing tests**

Add to `BR2026Tests/ViewModels/FixturesViewModelTests.swift` (this file declares `team`
locally per test rather than as a shared property — follow that existing convention):

```swift
@Test("hasLiveMatch is true when any match is live")
func hasLiveMatchTrueWhenLive() async {
    let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)
    let live = Match(
        id: 1, utcDate: Date(), status: .live, matchday: 1, stage: "REGULAR_SEASON",
        homeTeam: team, awayTeam: team, homeScore: 1, awayScore: 0, winner: nil, venue: nil, minute: 30
    )
    let service = StubMatchService(matches: [live], standings: [])
    let viewModel = FixturesViewModel(service: service)

    await viewModel.load()

    #expect(viewModel.hasLiveMatch == true)
}

@Test("hasLiveMatch is false when no match is live")
func hasLiveMatchFalseWhenNoneLive() async {
    let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)
    let scheduled = Match(
        id: 1, utcDate: Date(), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
        homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
    )
    let service = StubMatchService(matches: [scheduled], standings: [])
    let viewModel = FixturesViewModel(service: service)

    await viewModel.load()

    #expect(viewModel.hasLiveMatch == false)
}

@Test("refreshIfNeeded does the one-time cache-then-refresh on its first call")
func refreshIfNeededFirstCallLoadsOnce() async {
    let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)
    let scheduled = Match(
        id: 1, utcDate: Date(), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
        homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
    )
    let service = StubMatchService(matches: [scheduled], standings: [])
    let viewModel = FixturesViewModel(service: service)

    await viewModel.refreshIfNeeded()

    #expect(service.fetchMatchesCallCount == 1)
}

@Test("refreshIfNeeded refetches on every subsequent call")
func refreshIfNeededSubsequentCallsAlwaysRefetch() async {
    let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)
    let scheduled = Match(
        id: 1, utcDate: Date(), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
        homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
    )
    let service = StubMatchService(matches: [scheduled], standings: [])
    let viewModel = FixturesViewModel(service: service)

    await viewModel.refreshIfNeeded()
    await viewModel.refreshIfNeeded()
    await viewModel.refreshIfNeeded()

    #expect(service.fetchMatchesCallCount == 3)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: FAIL to build — `Value of type 'FixturesViewModel' has no member 'hasLiveMatch'` (and `refreshIfNeeded`).

- [ ] **Step 3: Write minimal implementation**

In `BR2026/ViewModels/FixturesViewModel.swift`, add (e.g. directly after `load()`):

```swift
var hasLiveMatch: Bool {
    matches.contains { $0.status == .live }
}

func refreshIfNeeded() async {
    if hasLoadedOnce {
        await load()
    } else {
        await loadOnce()
    }
}

func pollWhileLive() async {
    await LivePoller.run(interval: .seconds(30), shouldContinue: { hasLiveMatch }, action: { await load() })
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add BR2026/ViewModels/FixturesViewModel.swift BR2026Tests/ViewModels/FixturesViewModelTests.swift
git commit -m "Add FixturesViewModel.hasLiveMatch/refreshIfNeeded/pollWhileLive"
```

---

### Task 4: `MatchDetailViewModel` — `isLive`, `pollWhileLive`

**Files:**
- Modify: `BR2026/ViewModels/MatchDetailViewModel.swift`
- Modify: `BR2026Tests/ViewModels/MatchDetailViewModelTests.swift`

**Interfaces:**
- Consumes: `LivePoller.run(interval:shouldContinue:action:)` from Task 1.
- Produces: `MatchDetailViewModel.isLive: Bool`, `MatchDetailViewModel.pollWhileLive() async` — Task 7 (`MatchDetailView`) calls `pollWhileLive()`. No `refreshIfNeeded()` here — unlike Matchday/Fixtures, each `MatchDetailViewModel` instance is freshly created per sheet presentation, so there's no "first activation" ambiguity; `load()` is always the right call.

- [ ] **Step 1: Write the failing tests**

Add to `BR2026Tests/ViewModels/MatchDetailViewModelTests.swift` (inside the existing
struct, which already declares `private let team`):

```swift
@Test("isLive is true when the match status is live")
func isLiveTrueWhenLive() {
    let match = Match(
        id: 42, utcDate: Date(), status: .live, matchday: 1, stage: "REGULAR_SEASON",
        homeTeam: team, awayTeam: team, homeScore: 1, awayScore: 0, winner: nil, venue: nil, minute: 30
    )
    let service = StubMatchService(matches: [match], standings: [])
    let viewModel = MatchDetailViewModel(match: match, service: service)

    #expect(viewModel.isLive == true)
}

@Test("isLive is false when the match status is not live")
func isLiveFalseWhenNotLive() {
    let match = Match(
        id: 42, utcDate: Date(), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
        homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
    )
    let service = StubMatchService(matches: [match], standings: [])
    let viewModel = MatchDetailViewModel(match: match, service: service)

    #expect(viewModel.isLive == false)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: FAIL to build — `Value of type 'MatchDetailViewModel' has no member 'isLive'`.

- [ ] **Step 3: Write minimal implementation**

In `BR2026/ViewModels/MatchDetailViewModel.swift`, add (directly after `load()`):

```swift
var isLive: Bool {
    match.status == .live
}

func pollWhileLive() async {
    await LivePoller.run(interval: .seconds(30), shouldContinue: { isLive }, action: { await load() })
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add BR2026/ViewModels/MatchDetailViewModel.swift BR2026Tests/ViewModels/MatchDetailViewModelTests.swift
git commit -m "Add MatchDetailViewModel.isLive/pollWhileLive"
```

---

### Task 5: Wire `MatchdayView` to poll

**Files:**
- Modify: `BR2026/Views/Matchday/MatchdayView.swift`

**Interfaces:**
- Consumes: `MatchdayViewModel.refreshIfNeeded()`, `MatchdayViewModel.pollWhileLive()` from Task 2.

- [ ] **Step 1: Add the scenePhase environment property**

In `BR2026/Views/Matchday/MatchdayView.swift`, add alongside the existing
`@Environment(\.themeTokens) private var themeTokens`:

```swift
@Environment(\.scenePhase) private var scenePhase
```

- [ ] **Step 2: Replace the existing `.task` modifier**

Find:

```swift
                .task { await viewModel.loadOnce() }
```

Replace with:

```swift
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    await viewModel.refreshIfNeeded()
                    await viewModel.pollWhileLive()
                }
```

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Manual verification**

Install and launch `BR2026` on a simulator (`simctl install` + `simctl launch`, the
pattern already established in this project). Confirm Matchday still shows content
immediately (cache-then-refresh still works) and the app doesn't crash or hang. A full
live-polling behavior check happens in Task 8 once all three screens are wired.

- [ ] **Step 5: Commit**

```bash
git add BR2026/Views/Matchday/MatchdayView.swift
git commit -m "Wire MatchdayView to poll while a live match is on screen"
```

---

### Task 6: Wire `FixturesView` to poll

**Files:**
- Modify: `BR2026/Views/Fixtures/FixturesView.swift`

**Interfaces:**
- Consumes: `FixturesViewModel.refreshIfNeeded()`, `FixturesViewModel.pollWhileLive()` from Task 3.

- [ ] **Step 1: Add the scenePhase environment property**

In `BR2026/Views/Fixtures/FixturesView.swift`, add alongside the existing
`@Environment(\.themeTokens) private var themeTokens`:

```swift
@Environment(\.scenePhase) private var scenePhase
```

- [ ] **Step 2: Replace the existing `.task` modifier**

Find:

```swift
            .task { await viewModel.loadOnce() }
```

Replace with:

```swift
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                await viewModel.refreshIfNeeded()
                await viewModel.pollWhileLive()
            }
```

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Manual verification**

Install and launch `BR2026`, switch to the Fixtures tab, confirm the round picker and
match list still populate normally.

- [ ] **Step 5: Commit**

```bash
git add BR2026/Views/Fixtures/FixturesView.swift
git commit -m "Wire FixturesView to poll while a live match is on screen"
```

---

### Task 7: Wire `MatchDetailView` to poll

**Files:**
- Modify: `BR2026/Views/MatchDetail/MatchDetailView.swift`

**Interfaces:**
- Consumes: `MatchDetailViewModel.pollWhileLive()` from Task 4.

- [ ] **Step 1: Add the scenePhase environment property**

In `BR2026/Views/MatchDetail/MatchDetailView.swift`, add alongside the existing
`@Environment(\.themeTokens) private var themeTokens`:

```swift
@Environment(\.scenePhase) private var scenePhase
```

- [ ] **Step 2: Replace the existing `.task` modifier**

Find:

```swift
        .task { await viewModel.load() }
```

Replace with:

```swift
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await viewModel.load()
            await viewModel.pollWhileLive()
        }
```

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Manual verification**

Install and launch `BR2026`, tap a match card to present Match Detail, confirm the
timeline still loads and the sheet dismisses normally.

- [ ] **Step 5: Commit**

```bash
git add BR2026/Views/MatchDetail/MatchDetailView.swift
git commit -m "Wire MatchDetailView to poll while its match is live"
```

---

### Task 8: Full verification across all 6 targets

**Files:** None (verification only).

- [ ] **Step 1: Run the full unit test suite**

Run: `eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: All tests pass (existing suite + the new `LivePollerTests` and ViewModel tests
from Tasks 1-4).

- [ ] **Step 2: Build all 6 targets**

Run (repeat for each scheme — `BR2026`, `PremierLeague2026`, `Ligue12026`,
`PrimeiraLiga2026`, `ScottishPremiership2026`, `LaLiga2026`):

```bash
xcodebuild -project BR2026.xcodeproj -scheme <Scheme> -destination 'generic/platform=iOS Simulator' -skipMacroValidation build
```

Expected: `** BUILD SUCCEEDED **` for all six — confirms the shared Matchday/Fixtures/Match
Detail code compiles cleanly for every championship target, not just BR2026.

- [ ] **Step 3: Manual live-polling check**

Install and launch `BR2026` on a simulator. Navigate to a match currently `.live` in the
mock/live data (Matchday's hero card or a Fixtures row showing the `LiveChip`). Wait ~30
seconds without touching the screen; confirm the score/minute updates in place with no
user interaction (compare against the backend's current value, or watch `minute` tick
forward if the data source updates it). Background the app (Home button / swipe up),
wait a few seconds, then foreground it again; confirm a refresh happens immediately on
return rather than after another 30-second wait.

- [ ] **Step 4: Confirm Match Detail's score sync assumption**

While Matchday or Fixtures shows a live match, tap it to present Match Detail as a sheet.
Leave the sheet open through a live score change (or wait ~30s if the backend's mock data
updates on a timer). Confirm the score shown in Match Detail's header updates without
closing and reopening the sheet — this validates the design's assumption that the
presenting screen's poll loop keeps running underneath a presented `.sheet` and that
shared `Match` object identity carries the update through. If this does NOT hold (the
score shown in Match Detail goes stale while the sheet is open), stop and flag it — the
design's Match Detail section would need revisiting (an explicit single-match refetch,
which the design deliberately avoided since no such endpoint exists).

No commit for this task — verification only.
