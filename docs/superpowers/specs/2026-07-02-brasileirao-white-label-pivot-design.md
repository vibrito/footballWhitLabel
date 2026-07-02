# Brasileirão White-Label Pivot — Design

Date: 2026-07-02
Status: Approved, ready for implementation plan

## Context

The project started as a World Cup 2026 companion app (see git history / prior CLAUDE.md
revisions). It is pivoting to a white-label iOS app for national football championships,
starting with the Brasileirão (Brazilian Série A). A live backend now exists and is deployed:

- Base URL: `https://football-api-production-16d9.up.railway.app`
- Auth: `X-Auth-Token` header (value lives in Railway's `API_KEY` variable — not yet pulled
  into this repo)
- Relevant endpoints (all under `/v4/competitions/{code}/`, code = `BSA` for Brasileirão):
  - `GET /matches` — list of matches, supports `?status=LIVE` and `?matchday=N` filters
  - `GET /standings` — league table
  - `GET /matches/:id/statistics`, `/events`, `/lineups` — match detail data (not consumed
    by this build; noted for a future phase)

This is a greenfield build: no Xcode project exists yet in this repo, only `CLAUDE.md`.
This spec covers the first sub-project — a single-championship (Brasileirão-only) app built
on an architecture that's ready to add more championships later without a rewrite. Support
for additional championships, theming, and a championship switcher UI are explicitly out of
scope here (see Scope section).

## Architecture

Single iOS app target, config-driven for white-labeling. MVVM stays as specified in
`CLAUDE.md` (Views own no business logic; `@Observable` ViewModels own state).

A new `ChampionshipConfig` struct represents "which championship this build is configured
for":

```swift
struct ChampionshipConfig {
    let id: String              // e.g. "brasileirao"
    let displayName: String     // e.g. "Brasileirão"
    let competitionCode: String // e.g. "BSA" — API path segment
    let accentColorHex: String  // default Sunset Red #ff4d5e
    let apiBaseURL: URL
}
```

For this build there is exactly one value, `ChampionshipConfig.brasileirao`, injected once
at app launch (e.g. via SwiftUI environment or a small `AppEnvironment` holder). Adding a
second championship later means adding a new config value and a way to select it — not new
types or a rewrite of the service/view layer.

## Data flow & networking

`MatchService` protocol is unchanged in shape from the existing `CLAUDE.md` (abstracts the
data source; ViewModels depend on the protocol, not on a concrete implementation).

- `LiveMatchService`: concrete implementation using `URLSession` + Swift Concurrency
  (`async/await`). Built against a `ChampionshipConfig` (so it knows which `apiBaseURL` and
  `competitionCode` to hit). Sends `X-Auth-Token` on every request, read from
  `Secrets.xcconfig` (see Secrets below). Wires up `/matches` and `/standings` only for this
  build. `/statistics`, `/events`, `/lineups` are known to exist but are **not** called yet —
  there is no match-detail screen in this phase.
- Internally, `LiveMatchService` upserts fetched matches into SwiftData by `id`, updating
  only fields that changed (score, minute, status) rather than replacing the whole store —
  this satisfies the existing "avoid full-reload refreshes; prefer targeted updates" rule.
  Standings are simpler: the whole table is replaced on each fetch (no partial-update need,
  see Models below), so no upsert logic is required there.
- `MockMatchService`: stays as the existing `CLAUDE.md` describes — static in-memory sample
  data, no network, no SwiftData container. Used exclusively in unit tests.

### Secrets handling

The API key must never be committed to git.

- `Secrets.xcconfig` — holds `API_KEY = <value>`, added to `.gitignore`.
- `Secrets.xcconfig.example` — committed template with a placeholder value, so any developer
  (or future you) knows the file needs to exist and what key it needs.
- The Xcode build settings reference `$(API_KEY)` from the xcconfig, exposed to the app via
  `Info.plist` (e.g. an `API_KEY` key resolving to `$(API_KEY)`), read by `LiveMatchService`
  at init. If the value is missing, `LiveMatchService` fails fast with a clear error rather
  than silently sending unauthenticated requests.
- The actual key value needs to be pulled from the Railway dashboard (Variables tab on the
  `football-api` service) and placed into the local, untracked `Secrets.xcconfig` — this is
  a manual step, not something committed by the assistant.

## Models

- `Team`: `id`, `name`, `shortName`, `crestURL: URL?` (API `crest` field, remote image).
- `Match`: SwiftData `@Model`. `id`, `utcDate`, `status` (enum: `SCHEDULED`, `LIVE`,
  `FINISHED`, `POSTPONED`, mapped from the API's status strings), `matchday: Int` (the
  API's round number — distinct from the "Matchday" tab name, see UI section), `stage`,
  `homeTeam`, `awayTeam`, `homeScore: Int?`, `awayScore: Int?`, `winner` (enum, optional),
  `venue: String?`, `minute: Int?`. Designed for partial updates: score/minute/status can
  change independently as a live match progresses.
- `Standing`: plain struct (not SwiftData) — `position`, `team`, `playedGames`, `won`,
  `draw`, `lost`, `goalsFor`, `goalsAgainst`, `goalDifference`, `points`. Not persisted
  incrementally because the whole table is meaningfully replaced together on every fetch.
- Dropped from the prior World Cup design: `Group.swift`, `BracketMatch.swift`. A
  round-robin national league has neither group stages nor a knockout bracket.

## UI / tabs

Four tabs, per the user's latest naming decision:

1. **Matchday** (renamed from "Today") — shows matches happening today (by calendar date),
   same behavior as the original "Today" tab. Renamed because a league doesn't have matches
   scheduled every single day, and "Today" implied there'd always be something to show; empty
   state is expected and normal. `TodayViewModel`/`Views/Today/` become
   `MatchdayViewModel`/`Views/Matchday/`. This is a UI-label rename only — it does **not**
   change meaning to the API's numeric `matchday` round field, which stays on the `Match`
   model as-is. Do not conflate the two when naming files/types (e.g. avoid a type literally
   called `Matchday` that could be confused with the round number).
2. **Fixtures** — unchanged from prior design; matches grouped by round (`matchday` field).
3. **Standings** — unchanged; league table.
4. **More** — placeholder screen for this build (app info / stub content). No real settings
   functionality yet; exists so the 4-tab layout is real. Icon: `ellipsis.circle`.

## Folder structure

```
Championship26/
├── App/
│   └── Championship.swift
├── Config/
│   └── ChampionshipConfig.swift
├── Models/
│   ├── Match.swift
│   ├── Team.swift
│   └── Standing.swift
├── MockData/
│   └── MockDataProvider.swift
├── Services/
│   ├── MatchService.swift        # protocol
│   ├── LiveMatchService.swift
│   └── MockMatchService.swift
├── ViewModels/
│   ├── MatchdayViewModel.swift
│   ├── FixturesViewModel.swift
│   └── StandingsViewModel.swift
├── Views/
│   ├── Root/
│   │   └── ContentView.swift     # TabView: Matchday, Fixtures, Standings, More
│   ├── Matchday/
│   ├── Fixtures/
│   ├── Standings/
│   └── More/
├── Components/
│   ├── GlassCard.swift
│   ├── TeamCrestBadge.swift      # renamed from FlagBadge — remote AsyncImage-based
│   ├── LiveChip.swift
│   ├── ScoreRow.swift
│   └── AccentPill.swift
├── Resources/
│   └── Localizable.xcstrings
├── Secrets.xcconfig.example      # committed template
└── ChampionshipTests/
```

`Secrets.xcconfig` (the real, filled-in file) lives at the project root alongside the Xcode
project, is gitignored, and is not shown in the tree above since it never gets committed.

## Assets

Teams are football clubs with remote crest images provided by the API
(`https://media.api-sports.io/football/teams/{id}.png`), not national flags. The prior
World Cup design's bundled `Resources/Flags/<iso2>.png` system (with local offline-fallback
images) is dropped entirely.

- `TeamCrestBadge` (replacing `FlagBadge`) loads crests via SwiftUI `AsyncImage` from
  `Team.crestURL`, with a placeholder view (e.g. team initials on a muted glass fill) shown
  while loading or if the URL is `nil`/the load fails. No bundled team images.
- Icons remain SF Symbols only: Matchday → `soccerball`, Fixtures → `calendar`,
  Standings → `chart.bar`, More → `ellipsis.circle`.

## Localization

- Keep the existing 5 supported locales (`pt-BR`, `pt-PT`, `fr`, `en-US`, `en-GB`) and the
  `en-US` fallback, but scope localization to **static UI strings only**: tab titles, section
  headers, status labels ("Live", "Postponed", "Full Time", etc.).
- Drop the prior rule requiring team/country/venue names to be localized. Team and venue
  names now come dynamically from the live API (in whatever language the backend returns
  them) and are displayed as-is — there is no local translation table to maintain for
  server-driven content.

## Testing

Unchanged from the existing `CLAUDE.md` testing rules: Swift Testing framework, unit test
ViewModels and Services (not Views), tests live in `ChampionshipTests/` mirroring source
structure, `MockMatchService` used in all tests (no network, no SwiftData container).

## CLAUDE.md corrections needed

The user's in-progress edit to `CLAUDE.md` left some inconsistencies that this spec resolves
and that the implementation should fix when it updates `CLAUDE.md`:

- Lines 7–8 are unfinished sentences ("Need be create with Desing System, because each
  championship will have your colors." / "Need be in ") — replace with a concise, complete
  description of the config-driven white-label approach from this spec.
- The Testing section still references `WorldCup26Tests/` — must read `ChampionshipTests/`
  to match the Project Structure section and this spec.
- The Assets section still describes bundled `Flags/<iso2>.png` — must be rewritten per the
  Assets section above (remote crests, no bundled images).
- The Localization section's "team names, country names, and venue names must also be
  localized" rule must be removed per the Localization section above.
- Tab list should read **Matchday, Fixtures, Standings, More** (not "Today" and not
  "Bracket").
- `Project Structure` should match the folder tree in this spec (drop `Group.swift`,
  `BracketMatch.swift`, `BracketViewModel.swift`, `Views/Bracket/`; add `Config/`,
  rename `FlagBadge.swift` → `TeamCrestBadge.swift`).

## Scope

**In scope for this build:**
- `ChampionshipConfig` scaffolding (Brasileirão value only, but shaped for future values)
- `Matchday`, `Fixtures`, `Standings` tabs wired to live Brasileirão data via
  `LiveMatchService`
- `More` tab as a placeholder screen
- Secrets-based API key handling (`Secrets.xcconfig` + `.example` template, gitignored)
- SwiftData-backed partial updates for matches; standings replaced wholesale per fetch
- Unit tests for ViewModels using `MockMatchService`
- `CLAUDE.md` corrections listed above

**Out of scope (future phases):**
- Match detail screen (statistics/events/lineups endpoints)
- Championship switcher / picker UI
- Additional championships beyond Brasileirão
- Theming beyond a single default accent color
- User accounts, notifications, watchOS/widgets (already out of scope per existing
  `CLAUDE.md`)
