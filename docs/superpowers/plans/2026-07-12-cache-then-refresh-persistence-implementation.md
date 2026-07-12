# Cache-Then-Refresh Persistence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Matchday, Fixtures, and Standings show their last-known persisted data immediately on
load, then refresh from the live API in the background, with a small indicator while that
refresh is in flight and pull-to-refresh as a manual trigger — per
`docs/superpowers/specs/2026-07-12-cache-then-refresh-persistence-design.md`.

**Architecture:** `Standing` becomes a SwiftData `@Model` (whole-table clear-and-reinsert, not
incremental — same principle as today, now durable across launches). `MatchService` gains two
synchronous "read what's cached right now" methods. Each ViewModel's `load()` paints from the
cache first, then only overwrites on a successful network fetch — a failed refresh no longer
blanks already-visible data. A shared `RefreshPulseDot` component and `.refreshable` wire this
into all three views identically.

**Tech Stack:** SwiftUI (iOS 26+), SwiftData, Swift Testing, `@Observable`.

## Global Constraints

- No force-unwraps (`!`) outside tests. (CLAUDE.md Coding Guidelines)
- `@Observable` over `ObservableObject`. (CLAUDE.md Coding Guidelines)
- Unit test ViewModels and Services, not Views — no new View-level tests in this plan; UI
  changes (Task 4) are verified by building and a manual run. (CLAUDE.md Testing)
- `Standing`'s existing public memberwise initializer signature
  (`Standing(position:team:playedGames:won:draw:lost:goalsFor:goalsAgainst:goalDifference:points:)`)
  must not change — no new required parameter — so `StandingsViewModelTests.swift`'s existing
  call site keeps compiling unchanged. (Design spec, Standing: SwiftData Model)
- `RefreshPulseDot` reuses the exact existing pulse animation values (opacity `1→0.35→1`, scale
  `1→0.8→1`, 1.4s ease-in-out, `repeatForever`) already defined for `LiveChip`, in muted
  `white @ 0.5` instead of accent color. (CLAUDE.md Animations / Design spec)

---

## Task 1: Standing becomes a SwiftData model

**Files:**
- Create: `BR2026/Models/StandingDTO.swift`
- Modify: `BR2026/Models/Standing.swift`
- Modify: `BR2026/Services/MockMatchService.swift`
- Modify: `BR2026/Services/LiveMatchService.swift`
- Modify: `BR2026/App/Championship.swift`

**Interfaces:**
- Produces: `Standing` (`@Model final class`, same public init signature as before; `id` is now
  a computed property reading a new stored `teamID`), `StandingDTO` (`Decodable`, mirrors
  `MatchDTO`'s shape) — consumed by Task 2 and Task 3.

- [ ] **Step 1: Create `BR2026/Models/StandingDTO.swift`**

```swift
import Foundation

struct StandingDTO: Decodable {
    let position: Int
    let team: TeamDTO
    let playedGames: Int
    let won: Int
    let draw: Int
    let lost: Int
    let goalsFor: Int
    let goalsAgainst: Int
    let goalDifference: Int
    let points: Int
}
```

- [ ] **Step 2: Replace `BR2026/Models/Standing.swift` in full**

```swift
import Foundation
import SwiftData

@Model
final class Standing: Identifiable {
    @Attribute(.unique) var teamID: Int
    var position: Int
    var team: Team
    var playedGames: Int
    var won: Int
    var draw: Int
    var lost: Int
    var goalsFor: Int
    var goalsAgainst: Int
    var goalDifference: Int
    var points: Int

    var id: Int { teamID }

    init(
        position: Int,
        team: Team,
        playedGames: Int,
        won: Int,
        draw: Int,
        lost: Int,
        goalsFor: Int,
        goalsAgainst: Int,
        goalDifference: Int,
        points: Int
    ) {
        self.teamID = team.id
        self.position = position
        self.team = team
        self.playedGames = playedGames
        self.won = won
        self.draw = draw
        self.lost = lost
        self.goalsFor = goalsFor
        self.goalsAgainst = goalsAgainst
        self.goalDifference = goalDifference
        self.points = points
    }

    convenience init(dto: StandingDTO) {
        self.init(
            position: dto.position,
            team: Team(dto: dto.team),
            playedGames: dto.playedGames,
            won: dto.won,
            draw: dto.draw,
            lost: dto.lost,
            goalsFor: dto.goalsFor,
            goalsAgainst: dto.goalsAgainst,
            goalDifference: dto.goalDifference,
            points: dto.points
        )
    }
}
```

- [ ] **Step 3: Update `StandingsResponse` and its mapping in `BR2026/Services/MockMatchService.swift`**

Change:
```swift
struct StandingsResponse: Decodable {
    let standings: [Standing]
}
```
to:
```swift
struct StandingsResponse: Decodable {
    let standings: [StandingDTO]
}
```

And change this line inside `MockMatchService.init()`:
```swift
        self.standings = standingsResponse?.standings ?? []
```
to:
```swift
        self.standings = (standingsResponse?.standings ?? []).map(Standing.init(dto:))
```

- [ ] **Step 4: Replace `fetchStandings()` in `BR2026/Services/LiveMatchService.swift`**

Current:
```swift
    func fetchStandings() async throws -> [Standing] {
        let url = config.apiBaseURL.appendingPathComponent("v4/competitions/\(config.competitionCode)/standings")
        let response: StandingsResponse = try await get(url)
        return response.standings
    }
```

Replace with:
```swift
    func fetchStandings() async throws -> [Standing] {
        let url = config.apiBaseURL.appendingPathComponent("v4/competitions/\(config.competitionCode)/standings")
        let response: StandingsResponse = try await get(url)
        try modelContext.delete(model: Standing.self)
        for dto in response.standings {
            modelContext.insert(Standing(dto: dto))
        }
        try modelContext.save()
        return try modelContext.fetch(FetchDescriptor<Standing>())
    }
```

- [ ] **Step 5: Register `Standing` in the `ModelContainer` in `BR2026/App/Championship.swift`**

Change:
```swift
            modelContainer = try ModelContainer(for: Match.self)
```
to:
```swift
            modelContainer = try ModelContainer(for: Match.self, Standing.self)
```

- [ ] **Step 6: Run the full test suite**

```bash
export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test
```

Expected: PASS, same test count as before this task (no new tests yet — this task keeps
`Standing`'s observable behavior unchanged for existing callers; `MockMatchServiceTests.swift`'s
`returnsStandings` test in particular must still pass unmodified, proving the DTO→model mapping
preserves the same decoded values).

- [ ] **Step 7: Commit**

```bash
git add BR2026/Models/StandingDTO.swift BR2026/Models/Standing.swift BR2026/Services/MockMatchService.swift BR2026/Services/LiveMatchService.swift BR2026/App/Championship.swift
git commit -m "Make Standing a SwiftData model, persisted as a whole-table replace"
```

---

## Task 2: Synchronous cache reads on MatchService

**Files:**
- Modify: `BR2026/Services/MatchService.swift`
- Modify: `BR2026/Services/LiveMatchService.swift`
- Modify: `BR2026/Services/MockMatchService.swift`
- Modify: `BR2026Tests/ViewModels/MatchdayViewModelTests.swift` (the `StubMatchService` test
  double defined at the bottom of this file)
- Modify: `BR2026Tests/Services/MockMatchServiceTests.swift`

**Interfaces:**
- Consumes: `Standing`, `Match` (Task 1 / existing).
- Produces: `MatchService.cachedMatches() -> [Match]` and
  `MatchService.cachedStandings() -> [Standing]` — consumed by Task 3's ViewModels.

- [ ] **Step 1: Add the two methods to the `MatchService` protocol in `BR2026/Services/MatchService.swift`**

Replace the whole file:
```swift
// Main-actor isolated: `Match` is a SwiftData reference type and is not Sendable, so it
// must never cross actor boundaries. Every conformance (and every caller — all three
// ViewModels are already @MainActor) stays on the main actor for the whole call.
@MainActor
protocol MatchService {
    func fetchMatches() async throws -> [Match]
    func fetchStandings() async throws -> [Standing]
    func fetchEvents(matchID: Int) async throws -> [MatchEvent]
    func cachedMatches() -> [Match]
    func cachedStandings() -> [Standing]
}
```

- [ ] **Step 2: Implement both methods on `LiveMatchService`**

Add these two methods to `BR2026/Services/LiveMatchService.swift`, next to the existing
`fetchEvents(matchID:)` method:

```swift
    func cachedMatches() -> [Match] {
        (try? modelContext.fetch(FetchDescriptor<Match>())) ?? []
    }

    func cachedStandings() -> [Standing] {
        (try? modelContext.fetch(FetchDescriptor<Standing>())) ?? []
    }
```

- [ ] **Step 3: Implement both methods on `MockMatchService`**

Add these two lines to `BR2026/Services/MockMatchService.swift`, next to the existing
`fetchEvents(matchID:)` method:

```swift
    func cachedMatches() -> [Match] { matches }
    func cachedStandings() -> [Standing] { standings }
```

- [ ] **Step 4: Implement both methods on the test double `StubMatchService`**

In `BR2026Tests/ViewModels/MatchdayViewModelTests.swift`, add these two lines to
`StubMatchService` (needed just to keep it conforming to `MatchService` — Task 3 extends this
further):

```swift
    func cachedMatches() -> [Match] { matches }
    func cachedStandings() -> [Standing] { standings }
```

- [ ] **Step 5: Add two tests to `BR2026Tests/Services/MockMatchServiceTests.swift`**

Add inside the `@Suite` struct:

```swift
    @Test("cachedMatches returns the same sample matches, with no fetch required")
    func cachedMatchesReturnsSampleData() {
        let service = MockMatchService()
        #expect(!service.cachedMatches().isEmpty)
    }

    @Test("cachedStandings returns the same full 20-team sample table")
    func cachedStandingsReturnsSampleData() {
        let service = MockMatchService()
        #expect(service.cachedStandings().count == 20)
    }
```

- [ ] **Step 6: Run the full test suite**

```bash
export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test
```

Expected: PASS, 2 more tests than Task 1's baseline.

- [ ] **Step 7: Commit**

```bash
git add BR2026/Services/MatchService.swift BR2026/Services/LiveMatchService.swift BR2026/Services/MockMatchService.swift BR2026Tests/ViewModels/MatchdayViewModelTests.swift BR2026Tests/Services/MockMatchServiceTests.swift
git commit -m "Add synchronous cachedMatches/cachedStandings to MatchService"
```

---

## Task 3: ViewModels show cached data first, keep it on refresh failure

**Files:**
- Modify: `BR2026Tests/ViewModels/MatchdayViewModelTests.swift` (extend `StubMatchService`; add
  2 tests)
- Modify: `BR2026Tests/ViewModels/FixturesViewModelTests.swift` (add 2 tests)
- Modify: `BR2026Tests/ViewModels/StandingsViewModelTests.swift` (add 2 tests)
- Modify: `BR2026/ViewModels/MatchdayViewModel.swift`
- Modify: `BR2026/ViewModels/FixturesViewModel.swift`
- Modify: `BR2026/ViewModels/StandingsViewModel.swift`

**Interfaces:**
- Consumes: `MatchService.cachedMatches()`/`cachedStandings()` (Task 2).
- Produces: `isRefreshing` (renamed from `isLoading`) on all three ViewModels — consumed by
  Task 4's `RefreshPulseDot` wiring.

- [ ] **Step 1: Extend `StubMatchService` in `BR2026Tests/ViewModels/MatchdayViewModelTests.swift`**

Replace the whole `StubMatchService` class (and add the error enum below it) with:

```swift
final class StubMatchService: MatchService {
    let matches: [Match]
    let standings: [Standing]
    let events: [MatchEvent]
    var cachedMatchesOverride: [Match]?
    var cachedStandingsOverride: [Standing]?
    var shouldThrowOnFetch = false

    init(matches: [Match], standings: [Standing], events: [MatchEvent] = []) {
        self.matches = matches
        self.standings = standings
        self.events = events
    }

    func fetchMatches() async throws -> [Match] {
        if shouldThrowOnFetch { throw StubServiceError.simulatedFailure }
        return matches
    }

    func fetchStandings() async throws -> [Standing] {
        if shouldThrowOnFetch { throw StubServiceError.simulatedFailure }
        return standings
    }

    func fetchEvents(matchID: Int) async throws -> [MatchEvent] { events }

    func cachedMatches() -> [Match] { cachedMatchesOverride ?? matches }
    func cachedStandings() -> [Standing] { cachedStandingsOverride ?? standings }
}

enum StubServiceError: Error {
    case simulatedFailure
}
```

- [ ] **Step 2: Add 2 tests to `MatchdayViewModelTests.swift`**

Add inside the `@Suite` struct (before the `StubMatchService`/`StubServiceError` definitions at
the bottom of the file):

```swift
    @Test("load() shows cached matches immediately and keeps them if the background refresh fails")
    func loadKeepsCachedDataWhenRefreshFails() async {
        let cachedMatch = Match(
            id: 99, utcDate: date(day: 1, hour: 12), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [], standings: [])
        service.cachedMatchesOverride = [cachedMatch]
        service.shouldThrowOnFetch = true
        let viewModel = MatchdayViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.matches.map(\.id) == [99])
        #expect(viewModel.isRefreshing == false)
    }

    @Test("load() replaces stale cached matches with freshly fetched ones on success")
    func loadReplacesCacheWithFreshDataOnSuccess() async {
        let staleMatch = Match(
            id: 1, utcDate: date(day: 1, hour: 12), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let freshMatch = Match(
            id: 2, utcDate: date(day: 2, hour: 12), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [freshMatch], standings: [])
        service.cachedMatchesOverride = [staleMatch]
        let viewModel = MatchdayViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.matches.map(\.id) == [2])
    }
```

(`team` and `date(day:hour:)` are the suite's existing private helpers.)

- [ ] **Step 3: Add 2 tests to `FixturesViewModelTests.swift`**

Add inside the `@Suite` struct:

```swift
    @Test("load() shows cached matches immediately and keeps them if the background refresh fails")
    func loadKeepsCachedDataWhenRefreshFails() async {
        let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)
        let cachedMatch = Match(
            id: 99, utcDate: Date(timeIntervalSince1970: 100), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [], standings: [])
        service.cachedMatchesOverride = [cachedMatch]
        service.shouldThrowOnFetch = true
        let viewModel = FixturesViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.matches.map(\.id) == [99])
    }

    @Test("load() replaces stale cached matches with freshly fetched ones on success")
    func loadReplacesCacheWithFreshDataOnSuccess() async {
        let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)
        let staleMatch = Match(
            id: 1, utcDate: Date(timeIntervalSince1970: 100), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let freshMatch = Match(
            id: 2, utcDate: Date(timeIntervalSince1970: 200), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [freshMatch], standings: [])
        service.cachedMatchesOverride = [staleMatch]
        let viewModel = FixturesViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.matches.map(\.id) == [2])
    }
```

- [ ] **Step 4: Add 2 tests to `StandingsViewModelTests.swift`**

Add inside the `@Suite` struct:

```swift
    @Test("load() shows cached standings immediately and keeps them if the background refresh fails")
    func loadKeepsCachedDataWhenRefreshFails() async {
        let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)
        let cachedStanding = Standing(
            position: 1, team: team, playedGames: 5, won: 3, draw: 1, lost: 1,
            goalsFor: 10, goalsAgainst: 5, goalDifference: 5, points: 10
        )
        let service = StubMatchService(matches: [], standings: [])
        service.cachedStandingsOverride = [cachedStanding]
        service.shouldThrowOnFetch = true
        let viewModel = StandingsViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.standings.map(\.id) == [cachedStanding.id])
    }

    @Test("load() replaces stale cached standings with freshly fetched ones on success")
    func loadReplacesCacheWithFreshDataOnSuccess() async {
        let staleTeam = Team(id: 1, name: "Stale FC", shortName: "STL", crestURL: nil)
        let freshTeam = Team(id: 2, name: "Fresh FC", shortName: "FRS", crestURL: nil)
        let staleStanding = Standing(
            position: 1, team: staleTeam, playedGames: 5, won: 3, draw: 1, lost: 1,
            goalsFor: 10, goalsAgainst: 5, goalDifference: 5, points: 10
        )
        let freshStanding = Standing(
            position: 1, team: freshTeam, playedGames: 6, won: 4, draw: 1, lost: 1,
            goalsFor: 12, goalsAgainst: 5, goalDifference: 7, points: 13
        )
        let service = StubMatchService(matches: [], standings: [freshStanding])
        service.cachedStandingsOverride = [staleStanding]
        let viewModel = StandingsViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.standings.map(\.id) == [freshStanding.id])
    }
```

- [ ] **Step 5: Run the 6 new tests and confirm they fail (RED)**

```bash
export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test
```

Expected: FAIL — the 6 new tests fail because `load()` on all three ViewModels still does
`matches = (try? await service.fetchMatches()) ?? []` (or the `standings` equivalent), which
resets to `[]` on a thrown fetch error instead of preserving the cached override, and never
calls `cachedMatches()`/`cachedStandings()` at all yet.

- [ ] **Step 6: Replace `BR2026/ViewModels/MatchdayViewModel.swift` in full**

```swift
import Foundation
import Observation

@Observable
@MainActor
final class MatchdayViewModel {
    private(set) var matches: [Match] = []
    private(set) var isRefreshing = false
    private nonisolated(unsafe) let service: MatchService

    init(service: MatchService) {
        self.service = service
    }

    // The featured match is the earliest one still to be decided — a match already
    // live sorts before any future kickoff, so it naturally wins over a later
    // scheduled match without special-casing status.
    var nextMatch: Match? {
        matches
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

- [ ] **Step 7: Replace `BR2026/ViewModels/FixturesViewModel.swift` in full**

```swift
import Foundation
import Observation

@Observable
@MainActor
final class FixturesViewModel {
    private(set) var matches: [Match] = []
    private(set) var isRefreshing = false
    var selectedRound: Int?
    private nonisolated(unsafe) let service: MatchService

    init(service: MatchService) {
        self.service = service
    }

    var matchesByRound: [(round: Int, matches: [Match])] {
        Dictionary(grouping: matches, by: \.matchday)
            .map { (round: $0.key, matches: $0.value.sorted { $0.utcDate < $1.utcDate }) }
            .sorted { $0.round < $1.round }
    }

    var rounds: [Int] {
        matchesByRound.map(\.round)
    }

    var selectedRoundMatches: [Match] {
        guard let selectedRound else { return [] }
        return matchesByRound.first { $0.round == selectedRound }?.matches ?? []
    }

    func load() async {
        matches = service.cachedMatches()
        selectRoundIfNeeded()
        isRefreshing = true
        defer { isRefreshing = false }
        if let fresh = try? await service.fetchMatches() {
            matches = fresh
            selectRoundIfNeeded()
        }
    }

    // The "current" round is not the earliest round with an unplayed match: real
    // fixture lists have makeup games, so an early round can carry a couple of
    // matches rescheduled months later, long after later rounds have been played.
    // Instead: if a match is live right now, that round is current. Otherwise the
    // current round is the one right after the furthest round that has a finished
    // match — i.e. where the season has actually progressed to — falling back to
    // the first round if nothing has been played yet, or the last round if
    // everything has.
    private func currentRound() -> Int? {
        let byRound = matchesByRound
        guard !byRound.isEmpty else { return nil }

        if let liveRound = byRound.first(where: { round in round.matches.contains { $0.status == .live } }) {
            return liveRound.round
        }

        guard let maxFinishedRound = byRound.filter({ round in
            round.matches.contains { $0.status == .finished }
        }).map(\.round).max() else {
            return byRound.first?.round
        }

        let nextRound = byRound.first { $0.round > maxFinishedRound }
        return nextRound?.round ?? byRound.last?.round
    }

    // Called once from cache and again after a successful fetch — a no-op the second
    // time whenever the cache was already non-empty, since selectedRound is only ever
    // auto-picked once. Without the cache-time call, a returning user's round picker
    // would stay empty (selectedRoundMatches == []) during the instant-paint phase,
    // even though matches are already on screen.
    private func selectRoundIfNeeded() {
        if selectedRound == nil {
            selectedRound = currentRound()
        }
    }
}
```

- [ ] **Step 8: Replace `BR2026/ViewModels/StandingsViewModel.swift` in full**

```swift
import Foundation
import Observation

@Observable
@MainActor
final class StandingsViewModel {
    private(set) var standings: [Standing] = []
    private(set) var isRefreshing = false
    private nonisolated(unsafe) let service: MatchService

    init(service: MatchService) {
        self.service = service
    }

    func load() async {
        standings = service.cachedStandings().sorted { $0.position < $1.position }
        isRefreshing = true
        defer { isRefreshing = false }
        if let fresh = try? await service.fetchStandings() {
            standings = fresh.sorted { $0.position < $1.position }
        }
    }
}
```

- [ ] **Step 9: Run the full test suite and confirm all tests pass (GREEN)**

```bash
export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test
```

Expected: PASS, 6 more tests than Task 2's count (the new cache/refresh tests), all existing
tests still green (in particular, every existing `FixturesViewModelTests` test that asserts
`viewModel.selectedRound` after `load()` must still pass — `StubMatchService`'s
`cachedMatchesOverride` defaults to `nil`, so `cachedMatches()` falls back to the same `matches`
array `fetchMatches()` returns, meaning existing tests see identical before/after data).

- [ ] **Step 10: Commit**

```bash
git add BR2026Tests/ViewModels/MatchdayViewModelTests.swift BR2026Tests/ViewModels/FixturesViewModelTests.swift BR2026Tests/ViewModels/StandingsViewModelTests.swift BR2026/ViewModels/MatchdayViewModel.swift BR2026/ViewModels/FixturesViewModel.swift BR2026/ViewModels/StandingsViewModel.swift
git commit -m "Show cached data immediately in ViewModels; keep it when a refresh fails"
```

---

## Task 4: Refresh indicator and pull-to-refresh

**Files:**
- Create: `BR2026/Components/RefreshPulseDot.swift`
- Modify: `BR2026/Views/Matchday/MatchdayView.swift`
- Modify: `BR2026/Views/Fixtures/FixturesView.swift`
- Modify: `BR2026/Views/Standings/StandingsView.swift`

**Interfaces:**
- Consumes: `viewModel.isRefreshing` (Task 3) on all three views; `viewModel.load()` as the
  `.refreshable` action.

- [ ] **Step 1: Create `BR2026/Components/RefreshPulseDot.swift`**

```swift
import SwiftUI

struct RefreshPulseDot: View {
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(.white.opacity(0.5))
            .frame(width: 6, height: 6)
            .opacity(pulse ? 0.35 : 1)
            .scaleEffect(pulse ? 0.8 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}
```

- [ ] **Step 2: Wire it into `BR2026/Views/Matchday/MatchdayView.swift`**

Change this modifier chain on the `ScrollView`:
```swift
            .scrollContentBackground(.hidden)
            .background(StadiumBackground())
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.load() }
```
to:
```swift
            .scrollContentBackground(.hidden)
            .background(StadiumBackground())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isRefreshing {
                        RefreshPulseDot()
                    }
                }
            }
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
```

- [ ] **Step 3: Wire it into `BR2026/Views/Fixtures/FixturesView.swift`**

Change:
```swift
                .scrollContentBackground(.hidden)
            }
            .background(StadiumBackground())
            .navigationTitle("Fixtures")
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.load() }
```
to:
```swift
                .scrollContentBackground(.hidden)
                .refreshable { await viewModel.load() }
            }
            .background(StadiumBackground())
            .navigationTitle("Fixtures")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isRefreshing {
                        RefreshPulseDot()
                    }
                }
            }
            .task { await viewModel.load() }
```

- [ ] **Step 4: Wire it into `BR2026/Views/Standings/StandingsView.swift`**

Change:
```swift
            .scrollContentBackground(.hidden)
            .background(StadiumBackground())
            .navigationTitle("Standings")
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.load() }
```
to:
```swift
            .scrollContentBackground(.hidden)
            .refreshable { await viewModel.load() }
            .background(StadiumBackground())
            .navigationTitle("Standings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isRefreshing {
                        RefreshPulseDot()
                    }
                }
            }
            .task { await viewModel.load() }
```

- [ ] **Step 5: Run the full test suite**

```bash
export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test
```

Expected: PASS, same count as Task 3 (View-only changes, no new tests per CLAUDE.md's "unit
test ViewModels/Services, not Views").

- [ ] **Step 6: Manually verify in the Simulator**

Use the `run` skill (or `bundle exec fastlane test` already builds the app — launch it directly
in Simulator via Xcode or `xcodebuild ... build` + `xcrun simctl launch`) to confirm: the pulse
dot appears briefly in the top-right of each of the 3 tabs while data loads, and a pull-down
gesture on each screen triggers the native refresh spinner and re-fetches.

- [ ] **Step 7: Commit**

```bash
git add BR2026/Components/RefreshPulseDot.swift BR2026/Views/Matchday/MatchdayView.swift BR2026/Views/Fixtures/FixturesView.swift BR2026/Views/Standings/StandingsView.swift
git commit -m "Add refresh pulse indicator and pull-to-refresh to Matchday, Fixtures, Standings"
```

---

## Task 5: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Replace the Standing bullet in the Data & Persistence section (`CLAUDE.md:161-162`)**

Current:
```markdown
- `Standing` is a plain `Decodable` struct — the whole table is replaced on each fetch, not
  persisted incrementally.
```

Replace with:
```markdown
- `Standing` is also a SwiftData `@Model` — the whole table is replaced on each fetch via a
  clear-and-reinsert (not persisted incrementally, same principle as before), so it now
  survives a relaunch too.
- Matchday, Fixtures, and Standings show their last-known persisted data immediately on load,
  then refresh from the API in the background via `MatchService.cachedMatches()`/
  `cachedStandings()` — a failed background refresh keeps the last-known data on screen rather
  than clearing it.
```

- [ ] **Step 2: Add a line to the Animations section (`CLAUDE.md:229`, right after the Live pulse bullet)**

Current:
```markdown
  - Live pulse: opacity `1→0.35→1`, scale `1→0.8→1`, 1.4s ease-in-out, repeat forever.
```

Add immediately after it:
```markdown
  - Refresh pulse: same values as the live pulse, in muted `white @ 0.5` instead of accent
    color — shown in the nav bar while a background data refresh (`isRefreshing`) is in flight.
```

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "Document Standing's persistence and the cache-then-refresh pattern"
```
