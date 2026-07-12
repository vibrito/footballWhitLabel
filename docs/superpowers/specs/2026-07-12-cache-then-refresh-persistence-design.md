# Cache-Then-Refresh Persistence Design

**Goal:** On the second (and every later) app launch, Matchday, Fixtures, and Standings show
the last-known data instantly instead of a blank screen, while a background fetch refreshes it
from the live API. A small indicator signals when that background refresh is in flight, and
pull-to-refresh lets the user trigger it manually.

**Architecture:** `Match` already persists via SwiftData and is upserted incrementally; `Standing`
gains SwiftData persistence too, but stays a whole-table replace (clear-and-reinsert) rather than
incremental upsert, matching its existing "whole table, not incremental" design principle — the
new part is that the whole table now survives a relaunch. `MatchService` grows two synchronous
"read what's on disk right now" methods that each ViewModel's `load()` calls before awaiting the
network, so the UI paints immediately from local data and only replaces it once (and if) the
network fetch succeeds — a failed refresh no longer blanks out already-visible data, which is
today's actual behavior (`(try? await service.fetch...()) ?? []` resets to empty on any error).

## Standing: SwiftData Model

`BR2026/Models/Standing.swift` changes from a `Decodable` struct to a `@Model final class`,
mirroring `Match`'s existing DTO/model split:

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

The public memberwise initializer keeps today's exact parameter list (no new required
`teamID` parameter — it's derived from `team.id` internally), so the existing
`StandingsViewModelTests.swift` call site (`Standing(position: 2, team: team2, ...)`) needs no
changes. `id` stays a computed property, so `ForEach(viewModel.standings, id: \.id)` in
`StandingsView` is untouched.

A new `BR2026/Models/StandingDTO.swift`, sibling to the existing `MatchDTO.swift`, handles wire
decoding:

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

`StandingsResponse` (in `BR2026/Services/MockMatchService.swift`, shared by both services) changes
from `let standings: [Standing]` to `let standings: [StandingDTO]`, decoded and mapped via
`.map(Standing.init(dto:))` — exactly mirroring how `MatchesResponse`/`MatchDTO`/`Match.init(dto:)`
already works.

`ChampionshipApp`'s `ModelContainer(for: Match.self)` becomes
`ModelContainer(for: Match.self, Standing.self)`.

## Standings Persistence: Whole-Table Replace

`LiveMatchService.fetchStandings()` persists the freshly decoded table by clearing and
reinserting, not upserting — consistent with CLAUDE.md's existing "whole table is replaced on
each fetch, not persisted incrementally" principle, just now durable across launches:

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

Because `get<T>` (the decode step) throws before any of this runs, a failed or malformed
response never touches the persisted table — the last good table stays on disk untouched.

## MatchService: Synchronous Cache Reads

`BR2026/Services/MatchService.swift` gains two synchronous methods (no network, no `async throws`
— just "what's on disk right now"):

```swift
@MainActor
protocol MatchService {
    func fetchMatches() async throws -> [Match]
    func fetchStandings() async throws -> [Standing]
    func fetchEvents(matchID: Int) async throws -> [MatchEvent]
    func cachedMatches() -> [Match]
    func cachedStandings() -> [Standing]
}
```

`LiveMatchService` implements them as a direct local fetch, no network:

```swift
func cachedMatches() -> [Match] {
    (try? modelContext.fetch(FetchDescriptor<Match>())) ?? []
}

func cachedStandings() -> [Standing] {
    (try? modelContext.fetch(FetchDescriptor<Standing>())) ?? []
}
```

`MockMatchService` returns its existing in-memory arrays unchanged (`matches`/`standings`) — it
has no real cache/network distinction and doesn't need one.

## ViewModels: Cache-Then-Refresh `load()`

`MatchdayViewModel`, `FixturesViewModel`, and `StandingsViewModel` each change `load()` to the
same shape (shown for `MatchdayViewModel`; `FixturesViewModel` and `StandingsViewModel` follow
identically with their own service call and property):

```swift
private(set) var matches: [Match] = []
private(set) var isRefreshing = false

func load() async {
    matches = service.cachedMatches()
    isRefreshing = true
    defer { isRefreshing = false }
    if let fresh = try? await service.fetchMatches() {
        matches = fresh
    }
}
```

`isLoading` is renamed `isRefreshing` on all three ViewModels — same property, but now actually
consumed by the UI (today it's set but never read by any View). The key behavioral change: the
old shape (`matches = (try? await service.fetchMatches()) ?? []`) reset to `[]` on *any* fetch
failure, even with data already on screen. The new shape only overwrites `matches` on success, so
a failed background refresh keeps showing the last-known data instead of blanking the screen —
this is the mechanism that makes "keep showing what we had" actually hold. First-ever launch
(nothing cached yet) is unaffected: `cachedMatches()`/`cachedStandings()` return `[]`, so today's
existing empty-state UI shows until the first fetch completes — no new onboarding state needed.

## Refresh Indicator

A new shared `RefreshPulseDot` (`BR2026/Components/RefreshPulseDot.swift`) reuses `LiveChip`'s
existing pulse animation values (opacity 1→0.35→1, scale 1→0.8→1, 1.4s ease-in-out,
`repeatForever`) in muted `white @ 0.5` instead of accent color, so it doesn't compete visually
with the red LIVE chip:

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

Wired identically into all three views:

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        if viewModel.isRefreshing {
            RefreshPulseDot()
        }
    }
}
```

This placement works the same way regardless of each screen's own title layout — Fixtures and
Standings use `.navigationTitle`, Matchday renders its title inline in scrolled content — since a
toolbar item is independent of the title itself.

## Pull-to-Refresh

Each screen's `ScrollView` gets `.refreshable { await viewModel.load() }`, reusing the same
cache-then-fetch `load()` — pulling just re-triggers the same flow already wired for
`isRefreshing`. The native pull spinner and the toolbar `RefreshPulseDot` can both be visible
momentarily during a manual pull; that's not a conflict — the native spinner acknowledges the
pull gesture, the dot signals "a refresh is in flight" uniformly for both the automatic
on-appear case and this manual one.

## Testing

`StubMatchService` (defined in `BR2026Tests/ViewModels/MatchdayViewModelTests.swift`, shared by
`FixturesViewModelTests`, `StandingsViewModelTests`, and `MatchDetailViewModelTests`) gains:

```swift
var cachedMatchesOverride: [Match]?
var cachedStandingsOverride: [Standing]?
var shouldThrowOnFetch = false

func cachedMatches() -> [Match] { cachedMatchesOverride ?? matches }
func cachedStandings() -> [Standing] { cachedStandingsOverride ?? standings }
```

`fetchMatches()`/`fetchStandings()` throw a simple stub error when `shouldThrowOnFetch` is true.
Two new tests per ViewModel (Matchday, Fixtures, Standings — 6 total): cached data survives a
failed refresh (`shouldThrowOnFetch = true` with a distinct `cachedMatchesOverride`), and fresh
data replaces stale cached data on a successful refresh (distinct `cachedMatchesOverride` vs. the
constructor's `matches`). Per CLAUDE.md, unit tests cover ViewModels/Services, not Views — the
visual mid-flight indicator state (`RefreshPulseDot` actually appearing) is a manual verification
concern, not a unit test.

## Documentation

CLAUDE.md's Data & Persistence section is updated to state Standing is now a SwiftData `@Model`
(whole-table replace, not incremental — same principle, now durable across launches), and the
Animations section gets a line for `RefreshPulseDot` alongside the existing "Live pulse" bullet,
noting it reuses the same timing/values in muted white instead of accent color.

## Out of Scope

- `MatchDetailViewModel`/`MatchEvent` — the events sheet is opened on-demand and short-lived; it
  keeps fetching fresh each time, no caching added.
- Any retry/backoff policy for failed background refreshes — a failure just means "try again on
  the next `load()` call" (next screen visit or manual pull), no automatic retry loop.
- Persisting the events table, or any other model beyond Match and Standing.
