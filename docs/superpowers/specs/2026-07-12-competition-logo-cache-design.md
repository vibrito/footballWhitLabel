# Competition Logo Caching Design

**Goal:** The More screen's competition header (name + crest) currently fetches over the
network on every launch, so the logo briefly (or entirely, if the app is used offline)
shows a placeholder before popping in. Persist the competition record — including the logo
image bytes — so it loads instantly from cache after the first successful fetch, with a
quiet weekly background refresh in case the crest or name ever changes.

**Architecture:** `Competition` becomes a SwiftData `@Model`, following the exact
`Match`/`MatchDTO` and `Standing`/`StandingDTO` split already used in this codebase: the
current `Competition` struct (the wire-format `Decodable`) is renamed to `CompetitionDTO`,
because a custom `CodingKeys` on an `@Model` crashes SwiftData's schema reflection (already
documented in `Team.swift`). The new `Competition` model adds `logoData: Data?` and
`cachedAt: Date` alongside the existing `code`, `name`, `season`, `logoURL` fields.

## Data Model

`BR2026/Models/CompetitionDTO.swift` (renamed from the current `Competition.swift`
content, unchanged):
```swift
struct CompetitionDTO: Decodable {
    let code: String
    let name: String
    let season: Int
    let logoURL: URL

    private enum CodingKeys: String, CodingKey {
        case code, name, season
        case logoURL = "logo"
    }
}
```

`BR2026/Models/Competition.swift` (new SwiftData model):
```swift
@Model
final class Competition {
    @Attribute(.unique) var code: String
    var name: String
    var season: Int
    var logoURL: URL
    var logoData: Data?
    var cachedAt: Date

    init(code: String, name: String, season: Int, logoURL: URL, logoData: Data? = nil, cachedAt: Date = Date()) { ... }
    convenience init(dto: CompetitionDTO, logoData: Data? = nil) { ... }
}
```
The 4-argument `init(code:name:season:logoURL:)` keeps its existing shape (via default
values for `logoData`/`cachedAt`) so existing test call sites that construct a `Competition`
directly don't need to change.

`Championship.swift`'s `ModelContainer(for: Match.self, Standing.self)` gains
`Competition.self`.

## Fetch + Cache Flow

`MatchService` gains one new method:
```swift
func cachedCompetition() -> Competition?
```

`LiveMatchService.fetchCompetition()`:
1. Decodes `CompetitionDTO` from the competition endpoint (as today).
2. Downloads the logo image bytes from `dto.logoURL` via a plain `urlSession.data(from:)`
   call (no `X-Auth-Token` header — that's for the sports API, not the third-party image
   host). This is non-fatal: `try?`, so a transient image-fetch failure still caches the
   name/code/logoURL with `logoData = nil` rather than failing the whole operation.
3. Clear-and-reinserts a single `Competition` row (same pattern as `fetchStandings()`) with
   `cachedAt = Date()`.
4. Returns the persisted row.

`LiveMatchService.cachedCompetition()` reads the single persisted row via
`FetchDescriptor<Competition>()`, mirroring `cachedMatches()`/`cachedStandings()`.

`MockMatchService` decodes `CompetitionDTO` from the bundled mock JSON (as it already does),
then wraps it via `Competition(dto:)`. Its `cachedCompetition()` returns that same in-memory
instance — since `MockMatchService` has no real persistence, "cached" and "fetched" are the
same object, matching how `cachedMatches()`/`cachedStandings()` already behave for mock data.

## ViewModel: Cache-Once, Refresh-Weekly

`MoreViewModel` gains the same `load()`/`loadOnce()` split already used by
`MatchdayViewModel`/`FixturesViewModel`/`StandingsViewModel` (the current unconditional
`.task { await viewModel.loadCompetition() }` in `MoreView` re-fires every time the More tab
reappears, same bug the other three screens had before that split was introduced).

```swift
private static let refreshInterval: TimeInterval = 7 * 24 * 60 * 60 // 7 days

func loadOnce() async {
    guard !hasLoadedOnce else { return }
    hasLoadedOnce = true
    await load()
}

func load() async {
    if let cached = service.cachedCompetition() {
        apply(cached)
        guard Date().timeIntervalSince(cached.cachedAt) > Self.refreshInterval else { return }
    }
    if let fresh = try? await service.fetchCompetition() {
        apply(fresh)
    }
}

private func apply(_ competition: Competition) {
    competitionName = competition.name
    competitionLogoURL = competition.logoURL
    competitionLogoData = competition.logoData
}
```

This is the key behavioral difference from Matchday/Fixtures/Standings: those three *always*
background-refresh on `load()` because scores/standings change constantly. Competition
branding essentially never changes, so `load()` here skips the network call entirely once a
cache exists and is under 7 days old — a genuinely new "fetch once, refresh occasionally"
shape not used elsewhere in the app yet.

`MoreView` doesn't show `RefreshPulseDot` today and this doesn't add it — a silent weekly
background refresh isn't the kind of in-flight state that indicator communicates.

## View: Render Cached Bytes Directly

`MoreView`'s `competitionHeader` currently binds `AsyncImage(url: viewModel.competitionLogoURL)`
unconditionally. New logic: if `viewModel.competitionLogoData` is present, decode it via
`UIImage(data:)` and render with `Image(uiImage:)` — no network round-trip. Falls back to
today's `AsyncImage(url:)` only when there's no cached image yet (the very first launch,
before any successful fetch has completed). `UIImage(data:)` is one of the legitimate
"SwiftUI has no equivalent" UIKit exceptions CLAUDE.md already carves out (same justification
as the existing `UIApplication.setAlternateIconName` code in `AppIconSetting.swift`) — SwiftUI
has no `Image(data:)` initializer.

## Testing

`StubMatchService` (the shared test double in `MatchdayViewModelTests.swift`) gains:
- `cachedCompetitionOverride: Competition?` (defaults to `nil` — unlike
  `cachedMatchesOverride`/`cachedStandingsOverride`, which fall back to always-present mock
  arrays, an absent cache is a meaningfully different, testable state here)
- `fetchCompetitionCallCount: Int` (to assert the network call was or wasn't made)
- `cachedCompetition() -> Competition? { cachedCompetitionOverride }`

New `MoreViewModelTests` cases:
- **Fresh cache** (`cachedAt` = now): `load()` populates state from the cache and
  `fetchCompetitionCallCount == 0`.
- **Stale cache** (`cachedAt` = 8+ days ago): `load()` populates state from the cache
  immediately *and* `fetchCompetitionCallCount == 1` (background refresh still happens).
- **No cache**: `load()` calls `fetchCompetition()` and populates state from the network
  result (this replaces the existing "loadCompetition() populates..." test, renamed to call
  `load()`).

No new tests for `LiveMatchService` — it isn't unit-tested today (it talks to the real live
API; `MockMatchService` is what every automated test uses), consistent with existing
coverage.

## CLAUDE.md

Add a short note to the **Data & Persistence** section: `Competition` is also a SwiftData
`@Model`, cached with its logo image bytes and fetched once, then refreshed at most weekly
(`cachedAt` older than 7 days) — unlike Matchday/Fixtures/Standings, which always
background-refresh, since competition branding doesn't change the way scores do.

## Out of Scope

- No manual refresh affordance (no pull-to-refresh on the More screen) — the weekly throttle
  is the only refresh trigger.
- No cache invalidation if `ChampionshipConfig` ever changes competition code mid-install —
  out of scope per CLAUDE.md's existing "a championship switcher UI... is out of scope."
- No change to the Terms of Service / App Icon rows or any other More screen content.
