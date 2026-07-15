# Matchday Hero Card Team Affinity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a Team Theme is selected, the Matchday hero card features that team's next
match instead of the earliest match league-wide.

**Architecture:** `TeamThemeStore` gains a public `selectedOption: TeamThemeOption?`
property (it already resolves this internally, just never exposed it). `MatchdayViewModel`
gains a `TeamThemeStore` dependency and its `nextMatch` computed property gains a
first-priority branch for the selected team's own match, falling through to the existing
league-wide-earliest logic unchanged.

**Tech Stack:** SwiftUI (iOS 26+), Swift Testing, `@Observable`/`@MainActor`.

## Global Constraints

- The selected Team Theme (via `TeamThemeStore.selectedOption`) is the single source of
  truth for "the user's team" — no Team Icon-based affinity, no multi-team support.
- The hero card always features the selected team's next live-or-scheduled match
  regardless of how far out it is, or whether a different match is live right now — this
  is a personalized card, not a "what's happening now" card.
- Falls back to exactly today's existing league-wide-earliest-match logic when no team is
  selected or the selected team has no live/scheduled match — that fallback expression must
  not change.
- No force-unwraps (`!`) outside of tests. `@Observable`/`@MainActor`, matching every
  existing pattern in this codebase.
- Full test suite (`bundle exec fastlane test`, after
  `export PATH="$(rbenv root)/shims:$PATH"`) must pass at 100% after every task.

---

### Task 1: Expose `TeamThemeStore.selectedOption`

**Files:**
- Modify: `BR2026/Services/TeamThemeStore.swift`
- Test: `BR2026Tests/Services/TeamThemeStoreTests.swift`

**Interfaces:**
- Produces: `TeamThemeStore.selectedOption: TeamThemeOption?` (read-only from outside),
  kept in sync with the store's existing persisted selection — consumed by Task 2's
  `MatchdayViewModel`.

- [ ] **Step 1: Write the failing tests**

Add these four tests to `BR2026Tests/Services/TeamThemeStoreTests.swift` (append inside the
existing `TeamThemeStoreTests` struct, alongside the other `@Test` functions — the file
already has a `palmeirasColors` fixture and a `StubTeamThemeSetting`/`StubMatchService` at
the bottom you can reuse exactly as the existing tests do):

```swift
@Test("loadOnce() with a persisted selection populates selectedOption")
func loadOnceSetsSelectedOption() async {
    let setting = StubTeamThemeSetting(selectedThemeID: TeamThemeOption.palmeirasHome.rawValue)
    let service = StubMatchService(matches: [], standings: [])
    service.cachedTeamThemeColorSetOverride = palmeirasColors
    let store = TeamThemeStore(setting: setting, service: service)

    await store.loadOnce()

    #expect(store.selectedOption == .palmeirasHome)
}

@Test("loadOnce() with no persisted selection leaves selectedOption nil")
func loadOnceWithNoSelectionLeavesSelectedOptionNil() async {
    let setting = StubTeamThemeSetting()
    let service = StubMatchService(matches: [], standings: [])
    let store = TeamThemeStore(setting: setting, service: service)

    await store.loadOnce()

    #expect(store.selectedOption == nil)
}

@Test("select() updates selectedOption to the newly selected option")
func selectUpdatesSelectedOption() async {
    let setting = StubTeamThemeSetting()
    let service = StubMatchService(matches: [], standings: [])
    service.cachedTeamThemeColorSetOverride = palmeirasColors
    let store = TeamThemeStore(setting: setting, service: service)

    await store.select(.palmeirasHome)

    #expect(store.selectedOption == .palmeirasHome)
}

@Test("select(nil) clears selectedOption back to nil")
func selectNilClearsSelectedOption() async {
    let setting = StubTeamThemeSetting()
    let service = StubMatchService(matches: [], standings: [])
    service.cachedTeamThemeColorSetOverride = palmeirasColors
    let store = TeamThemeStore(setting: setting, service: service)
    await store.select(.palmeirasHome)
    #expect(store.selectedOption == .palmeirasHome)

    await store.select(nil)

    #expect(store.selectedOption == nil)
}

@Test("select() leaves selectedOption unchanged when color resolution fails")
func selectLeavesSelectedOptionUnchangedOnFailure() async {
    let setting = StubTeamThemeSetting()
    let service = StubMatchService(matches: [], standings: [])
    // No cachedTeamThemeColorSetOverride set, and fetchTeamThemeColorSet's default
    // StubMatchService behavior throws unless an override is provided — matches the
    // existing "both cache and fetch fail" test's setup.
    let store = TeamThemeStore(setting: setting, service: service)

    let succeeded = await store.select(.palmeirasHome)

    #expect(succeeded == false)
    #expect(store.selectedOption == nil)
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:BR2026Tests/TeamThemeStoreTests -quiet
```

Expected: FAIL — `value of type 'TeamThemeStore' has no member 'selectedOption'`.

- [ ] **Step 3: Write the implementation**

In `BR2026/Services/TeamThemeStore.swift`, add the new stored property next to the existing
`tokens`:

```swift
private(set) var tokens = ThemeTokens()
private(set) var selectedOption: TeamThemeOption?
```

Update `loadOnce()` to set it right after resolving `option`:

```swift
func loadOnce() async {
    guard !hasLoadedOnce else { return }
    hasLoadedOnce = true
    guard let selectedID = setting.selectedThemeID,
          let option = TeamThemeOption.allCases.first(where: { $0.rawValue == selectedID }) else { return }
    selectedOption = option
    await apply(option)
}
```

Update `select(_:)` to set it in lockstep with the existing persisted-ID writes, and leave
it untouched on the failure path (mirrors exactly how `tokens` already behaves on that same
failure path):

```swift
@discardableResult
func select(_ option: TeamThemeOption?) async -> Bool {
    guard let option else {
        setting.setSelectedThemeID(nil)
        selectedOption = nil
        tokens = ThemeTokens()
        return true
    }
    guard let colors = await resolveColors(teamID: option.teamID)?[option.kit] else { return false }
    setting.setSelectedThemeID(option.rawValue)
    selectedOption = option
    tokens = ThemeTokens.themed(
        mainColorHex: option.mainColorOverrideHex ?? colors.mainColorHex,
        fontColorHex: option.fontColorOverrideHex ?? colors.fontColorHex,
        tabSelectionColorHex: option.tabSelectionColorOverrideHex,
        pillFillColorHex: option.pillFillColorOverrideHex,
        gradientDarkAmount: option.gradientDarkAmountOverride ?? -0.75,
        usesDiagonalSashBackground: option.usesDiagonalSashBackground
    )
    return true
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:BR2026Tests/TeamThemeStoreTests -quiet
```

Expected: PASS, all tests in the suite green (the 5 new ones plus every pre-existing one
unaffected).

- [ ] **Step 5: Commit**

```bash
git add BR2026/Services/TeamThemeStore.swift BR2026Tests/Services/TeamThemeStoreTests.swift
git commit -m "Expose TeamThemeStore.selectedOption"
```

---

### Task 2: Feature the selected team's match in Matchday's hero card

**Files:**
- Modify: `BR2026/ViewModels/MatchdayViewModel.swift`
- Modify: `BR2026/Views/Matchday/MatchdayView.swift`
- Modify: `BR2026/Views/Root/ContentView.swift`
- Test: `BR2026Tests/ViewModels/MatchdayViewModelTests.swift`

**Interfaces:**
- Consumes: `TeamThemeStore.selectedOption: TeamThemeOption?` (Task 1),
  `TeamThemeOption.teamID: Int` (existing), `Team.id: Int` (existing).
- Produces: `MatchdayViewModel.init(service:themeStore:)`,
  `MatchdayView.init(service:themeStore:)` — consumed by `ContentView`.

- [ ] **Step 1: Write the failing tests**

`MatchdayViewModelTests.swift`'s existing 8 tests all construct
`MatchdayViewModel(service:)` — each needs a `themeStore:` argument added. Since none of
those 8 tests are about team affinity, give them all a `TeamThemeStore` with nothing
selected, so today's behavior is preserved exactly. Replace every occurrence of:

```swift
let viewModel = MatchdayViewModel(service: service)
```

with:

```swift
let themeStore = TeamThemeStore(setting: StubTeamThemeSetting(), service: service)
let viewModel = MatchdayViewModel(service: service, themeStore: themeStore)
```

(8 occurrences — in `nextMatchIsEarliestUpcoming`, `nextMatchPrefersLiveMatch`,
`otherMatchesForNextMatchDayFiltersAndSorts`, `splitsOtherMatchesByFinishedStatus`,
`emptyWhenNothingUpcoming`, `loadKeepsCachedDataWhenRefreshFails`,
`loadReplacesCacheWithFreshDataOnSuccess`, `loadOnceOnlyFetchesOnce`.)

Then add these four new tests to the same `MatchdayViewModelTests` struct:

```swift
@Test("nextMatch features the selected team's own match over an earlier league-wide match")
func nextMatchFeaturesSelectedTeam() async {
    let selectedTeam = Team(id: TeamThemeOption.palmeirasHome.teamID, name: "Palmeiras", shortName: "PAL", crestURL: nil)
    let otherTeam = Team(id: 999, name: "Other FC", shortName: "OFC", crestURL: nil)
    let earlierLeagueWideMatch = Match(
        id: 1, utcDate: date(day: 10, hour: 12), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
        homeTeam: otherTeam, awayTeam: otherTeam, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
    )
    let selectedTeamsLaterMatch = Match(
        id: 2, utcDate: date(day: 11, hour: 12), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
        homeTeam: selectedTeam, awayTeam: otherTeam, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
    )
    let service = StubMatchService(matches: [earlierLeagueWideMatch, selectedTeamsLaterMatch], standings: [])
    service.cachedTeamThemeColorSetOverride = TeamThemeColorSet(
        home: TeamThemeColors(mainColorHex: "006437", fontColorHex: "ffffff"),
        away: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "035336"),
        third: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "2c5434")
    )
    let themeStore = TeamThemeStore(setting: StubTeamThemeSetting(), service: service)
    await themeStore.select(.palmeirasHome)
    let viewModel = MatchdayViewModel(service: service, themeStore: themeStore)

    await viewModel.load()

    #expect(viewModel.nextMatch?.id == 2)
}

@Test("nextMatch features the selected team's own match even when a different match is live right now")
func nextMatchFeaturesSelectedTeamOverLiveMatchElsewhere() async {
    let selectedTeam = Team(id: TeamThemeOption.palmeirasHome.teamID, name: "Palmeiras", shortName: "PAL", crestURL: nil)
    let otherTeam = Team(id: 999, name: "Other FC", shortName: "OFC", crestURL: nil)
    let liveElsewhere = Match(
        id: 1, utcDate: date(day: 10, hour: 12), status: .live, matchday: 1, stage: "REGULAR_SEASON",
        homeTeam: otherTeam, awayTeam: otherTeam, homeScore: 1, awayScore: 0, winner: nil, venue: nil, minute: 40
    )
    let selectedTeamsMatch = Match(
        id: 2, utcDate: date(day: 12, hour: 12), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
        homeTeam: selectedTeam, awayTeam: otherTeam, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
    )
    let service = StubMatchService(matches: [liveElsewhere, selectedTeamsMatch], standings: [])
    service.cachedTeamThemeColorSetOverride = TeamThemeColorSet(
        home: TeamThemeColors(mainColorHex: "006437", fontColorHex: "ffffff"),
        away: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "035336"),
        third: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "2c5434")
    )
    let themeStore = TeamThemeStore(setting: StubTeamThemeSetting(), service: service)
    await themeStore.select(.palmeirasHome)
    let viewModel = MatchdayViewModel(service: service, themeStore: themeStore)

    await viewModel.load()

    #expect(viewModel.nextMatch?.id == 2)
}

@Test("nextMatch falls back to the league-wide earliest match when the selected team has none live/scheduled")
func nextMatchFallsBackWhenSelectedTeamHasNoMatch() async {
    let selectedTeam = Team(id: TeamThemeOption.palmeirasHome.teamID, name: "Palmeiras", shortName: "PAL", crestURL: nil)
    let otherTeam = Team(id: 999, name: "Other FC", shortName: "OFC", crestURL: nil)
    let selectedTeamsFinishedMatch = Match(
        id: 1, utcDate: date(day: 9, hour: 12), status: .finished, matchday: 1, stage: "REGULAR_SEASON",
        homeTeam: selectedTeam, awayTeam: otherTeam, homeScore: 2, awayScore: 1, winner: "HOME_TEAM", venue: nil, minute: 90
    )
    let leagueWideMatch = Match(
        id: 2, utcDate: date(day: 10, hour: 12), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
        homeTeam: otherTeam, awayTeam: otherTeam, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
    )
    let service = StubMatchService(matches: [selectedTeamsFinishedMatch, leagueWideMatch], standings: [])
    service.cachedTeamThemeColorSetOverride = TeamThemeColorSet(
        home: TeamThemeColors(mainColorHex: "006437", fontColorHex: "ffffff"),
        away: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "035336"),
        third: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "2c5434")
    )
    let themeStore = TeamThemeStore(setting: StubTeamThemeSetting(), service: service)
    await themeStore.select(.palmeirasHome)
    let viewModel = MatchdayViewModel(service: service, themeStore: themeStore)

    await viewModel.load()

    #expect(viewModel.nextMatch?.id == 2)
}

@Test("nextMatch uses the existing league-wide-earliest behavior when no team is selected")
func nextMatchUnchangedWhenNoTeamSelected() async {
    let otherTeam = Team(id: 999, name: "Other FC", shortName: "OFC", crestURL: nil)
    let match = Match(
        id: 1, utcDate: date(day: 10, hour: 12), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
        homeTeam: otherTeam, awayTeam: otherTeam, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
    )
    let service = StubMatchService(matches: [match], standings: [])
    let themeStore = TeamThemeStore(setting: StubTeamThemeSetting(), service: service)
    let viewModel = MatchdayViewModel(service: service, themeStore: themeStore)

    await viewModel.load()

    #expect(viewModel.nextMatch?.id == 1)
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:BR2026Tests/MatchdayViewModelTests -quiet
```

Expected: FAIL to compile — `MatchdayViewModel(service:)` doesn't accept a `themeStore:`
argument yet.

- [ ] **Step 3: Write the implementation**

In `BR2026/ViewModels/MatchdayViewModel.swift`, add the dependency and change `nextMatch`:

```swift
import Foundation
import Observation

@Observable
@MainActor
final class MatchdayViewModel {
    private(set) var matches: [Match] = []
    private(set) var isRefreshing = false
    private var hasLoadedOnce = false
    private nonisolated(unsafe) let service: MatchService
    private let themeStore: TeamThemeStore

    init(service: MatchService, themeStore: TeamThemeStore) {
        self.service = service
        self.themeStore = themeStore
    }

    // The featured match is the selected Team Theme's own next match, if one exists —
    // this is a personalized "your team" card, so a match live elsewhere never displaces
    // it, and how far out it is doesn't matter as long as the season has one left. With
    // no team selected (or that team has no live/scheduled match), this falls back to the
    // league-wide earliest one still to be decided — a match already live sorts before any
    // future kickoff there too, so it naturally wins over a later scheduled match without
    // special-casing status.
    var nextMatch: Match? {
        if let teamID = themeStore.selectedOption?.teamID {
            let teamMatch = matches
                .filter { ($0.homeTeam.id == teamID || $0.awayTeam.id == teamID) && ($0.status == .live || $0.status == .scheduled) }
                .min { $0.utcDate < $1.utcDate }
            if let teamMatch { return teamMatch }
        }
        return matches
            .filter { $0.status == .live || $0.status == .scheduled }
            .min { $0.utcDate < $1.utcDate }
    }

    var otherMatchesForNextMatchDay: [Match] {
        guard let nextMatch else { return [] }
        let calendar = Calendar.current
        return matches
            .filter { $0.id != nextMatch.id && calendar.isDate($0.utcDate, inSameDayAs: nextMatch.utcDate) }
            .sorted { $0.utcDate < $1.utcDate }
    }

    var finishedMatchesForNextMatchDay: [Match] {
        otherMatchesForNextMatchDay.filter { $0.status == .finished }
    }

    var upcomingMatchesForNextMatchDay: [Match] {
        otherMatchesForNextMatchDay.filter { $0.status != .finished }
    }

    func loadOnce() async {
        guard !hasLoadedOnce else { return }
        hasLoadedOnce = true
        await load()
    }

    func load() async {
        matches = service.cachedMatches()
        isRefreshing = true
        defer { isRefreshing = false }
        if let fresh = try? await service.fetchMatches() {
            matches = fresh
        }
    }
}
```

(Only `init` and `nextMatch` change; every other member is unchanged from today.)

In `BR2026/Views/Matchday/MatchdayView.swift`, add the property and thread it into the view
model construction:

```swift
struct MatchdayView: View {
    @State private var viewModel: MatchdayViewModel
    @State private var selectedMatch: Match?
    let service: MatchService
    let themeStore: TeamThemeStore
    @Environment(\.themeTokens) private var themeTokens

    init(service: MatchService, themeStore: TeamThemeStore) {
        _viewModel = State(initialValue: MatchdayViewModel(service: service, themeStore: themeStore))
        self.service = service
        self.themeStore = themeStore
    }
```

(Only the property list and `init` change — the rest of `MatchdayView.swift`, starting from
`var body: some View {`, is unchanged.)

In `BR2026/Views/Root/ContentView.swift`, update the `MatchdayView` construction line:

```swift
            MatchdayView(service: service, themeStore: themeStore)
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:BR2026Tests/MatchdayViewModelTests -quiet
```

Expected: PASS, all 12 tests green (8 existing + 4 new).

- [ ] **Step 5: Build and run the full test suite**

```bash
xcodebuild build -project BR2026.xcodeproj -scheme BR2026 -destination "generic/platform=iOS Simulator" -quiet
export PATH="$(rbenv root)/shims:$PATH"
bundle exec fastlane test
```

Expected: build exits 0, full suite passes (189/189 — 180 baseline + 5 from Task 1 +
4 new tests from this task's Step 1, on top of the 8 pre-existing `MatchdayViewModelTests`
whose count doesn't change, just their constructor call).

- [ ] **Step 6: Build the other three championship targets to confirm they're unaffected**

```bash
xcodebuild build -project BR2026.xcodeproj -scheme PremierLeague2026 -destination "generic/platform=iOS Simulator" -quiet
xcodebuild build -project BR2026.xcodeproj -scheme Ligue12026 -destination "generic/platform=iOS Simulator" -quiet
xcodebuild build -project BR2026.xcodeproj -scheme PrimeiraLiga2026 -destination "generic/platform=iOS Simulator" -quiet
```

Expected: all three exit 0 — `MatchdayView`/`MatchdayViewModel`/`TeamThemeStore` are shared,
unconditional code across every target, so this is a plain regression check, not a new gate
(Team Theme itself has no per-target visibility restriction the way Team Icon does — every
target already runs the same theming machinery, just with nothing to select from since
`TeamThemeOption` cases are what's gated in the picker, not the store/view model wiring).

- [ ] **Step 7: Commit**

```bash
git add BR2026/ViewModels/MatchdayViewModel.swift BR2026/Views/Matchday/MatchdayView.swift BR2026/Views/Root/ContentView.swift BR2026Tests/ViewModels/MatchdayViewModelTests.swift
git commit -m "Feature the selected team's match in Matchday's hero card"
```
