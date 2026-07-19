# Match Detail: Statistics and Lineups — Design Spec

## Goal

Expand `MatchDetailView` beyond the events timeline to also show match statistics and team
lineups, using two backend endpoints that already exist and return real data but have never
been consumed by the app — closing roadmap item 6a.

## Background

CLAUDE.md already documents the two endpoints as deferred:

```
GET /v4/competitions/{code}/matches/:id/{statistics,lineups}  — not yet consumed
```

A sibling project (`/Users/mlbbr-mac-vinicius/projects/worldcup`, the Fixture2026 World Cup
app) already has a proven data layer for the equivalent feature against the same class of
backend — models, DTOs, a mapper, and `MatchService` protocol methods — though its own
`MatchDetailView` never wired them into any UI either. BR2026's real backend was queried
directly (match `1492291`, Botafogo vs Santos, BSA round 19) and confirmed to return an
**identical JSON shape** for statistics, and the same shape *plus one extra field* for
lineups:

```json
// statistics
{
  "home": { "fouls": 10, "shots": 17, "corners": 5, "possession": 48, "passAccuracy": 81, "shotsOnTarget": 7 },
  "away": { "fouls": 13, "shots": 22, "corners": 5, "possession": 52, "passAccuracy": 79, "shotsOnTarget": 9 }
}

// lineups
{
  "home": {
    "colors": { "mainColor": "f7f7f7", "fontColor": "ffffff", "secondaryColor": "f7f7f7" },
    "formation": "4-4-2",
    "startingXI": [ { "col": 1, "row": 1, "name": "Léo Linck", "number": 24, "position": "G" }, ... ],
    "substitutes": [ { "name": "...", "number": 1, "position": "G" }, ... ]
  },
  "away": { "...": "same shape" }
}
```

The `colors` field (BR2026-only, absent from worldcup's DTOs) gives each team's actual kit
colors for *this specific match* — not the team's generic brand color already used elsewhere
(`TeamThemeColorSet`), but the literal shirt worn that day (relevant for teams with multiple
kits, away-kit clashes, etc.).

## Design

### Scope

Both statistics and lineups ship together in one plan — the data-layer cost is low now that
the shape is proven identical to worldcup's, so splitting into two phases would mostly add
process overhead without reducing risk.

### Layout: segmented control replaces the single "Timeline" section

`MatchDetailView`'s header (score, teams, venue, half-time line) is unchanged. Below it, the
current unconditional `timelineSection` becomes one of three segments in a
`Picker(selection:) { }.pickerStyle(.segmented)`: **Timeline / Stats / Lineups**, matching the
Liquid Glass segmented-control styling already established elsewhere in the app (glass fill,
`white @ 0.07`, `0.5px` white-16%-opacity border). Timeline stays the default selected
segment — existing behavior for anyone who doesn't touch the picker is unchanged.

### Fetch timing: lazy per segment

`MatchDetailViewModel` gains `loadStatisticsIfNeeded()` and `loadLineupsIfNeeded()`, each a
no-op once already attempted (mirroring `selectRoundIfNeeded()`'s guard-on-nil pattern
elsewhere in the codebase), called from the segmented control's `onChange` the first time a
user selects that tab. `events` keeps loading eagerly in `load()` as it does today — Timeline
is the default view, so eager-loading it costs nothing extra. Statistics/lineups are only
fetched if the user actually taps that segment, avoiding two wasted calls for the common case
(checking a score) and avoiding empty-state flicker for scheduled matches where neither exists
yet.

### Data layer

New models (`BR2026/Models/MatchStatistics.swift`, `BR2026/Models/MatchLineup.swift`), plain
structs with no UI import, matching the Model-layer convention:

```swift
struct TeamStats {
    let fouls: Int
    let shots: Int
    let corners: Int
    let possession: Int
    let passAccuracy: Int
    let shotsOnTarget: Int
}

struct MatchStatistics {
    let home: TeamStats
    let away: TeamStats
}

struct LineupPlayer {
    let name: String
    let number: Int
    let position: String   // "G" / "D" / "M" / "F"
    let col: Int?           // nil for substitutes
    let row: Int?           // nil for substitutes
}

struct TeamLineup {
    let formation: String
    let startingXI: [LineupPlayer]
    let substitutes: [LineupPlayer]
    let kitColorHex: String        // colors.mainColor, as-is
    let kitFontColorHex: String    // colors.fontColor, WCAG-corrected — see below
}

struct MatchLineup {
    let home: TeamLineup
    let away: TeamLineup
}
```

DTOs (`BR2026/Services/DTOs/` — a new subdirectory, matching worldcup's structure; BR2026
currently keeps its DTOs inline in `LiveMatchService.swift`/`MockMatchService.swift`, but
these two responses are large enough to warrant their own files) decode the raw JSON 1:1,
including `colors` (which worldcup's version doesn't have). A `MatchMapper`-equivalent (either
a new file or static functions added to the existing DTO→model mapping site — whichever the
implementer finds already established) converts DTO to model, applying the WCAG correction
described below during mapping so the model always carries an already-safe font color.

`MatchService` protocol gains two methods, following `fetchEvents`'s existing precedent (no
SwiftData caching — same transient, per-sheet-visit lifecycle as events, distinct from
matches/standings/competition/team-theme-colors which persist):

```swift
func fetchMatchStatistics(matchID: Int) async throws -> MatchStatistics?
func fetchMatchLineups(matchID: Int) async throws -> MatchLineup?
```

`nil` is a normal, expected return for a match that hasn't started yet or is too recent for
lineups to be published — distinct from a thrown error (network failure). `LiveMatchService`
implements both against
`v4/competitions/{code}/matches/{id}/{statistics,lineups}`, same `get<T: Decodable>(_:)`
helper already used by every other endpoint. `MockMatchService` decodes new
`MockDataProvider.matchStatisticsJSON`/`matchLineupsJSON` fixtures (real-shaped sample data,
following the existing fixture convention).

### Lineup formation grid

**Visual reference:** mockups iterated live in this session at
`.superpowers/brainstorm/64904-1784422228/content/lineups-own-half-v2.html` (gitignored
scratch — not committed, but the final approved layout is fully described below for the
implementer).

- A soccer-pitch-shaped background (dark green gradient, center circle, halfway line, two
  penalty boxes) sized via `aspect-ratio(3, contentMode: .fit)` (3:4 width:height) inside a
  `GlassCard`.
- Each starting player renders as a small jersey-shaped marker: a `Shape` built from this
  exact polygon (as fractions of the marker's own width/height, matching the approved
  mockup's CSS `clip-path: polygon(...)` 1:1):
  `(0.30, 0.0), (0.42, 0.0), (0.50, 0.16), (0.58, 0.0), (0.70, 0.0), (1.0, 0.22), (0.85, 0.40),
  (0.85, 1.0), (0.15, 1.0), (0.15, 0.40), (0.0, 0.22)` — sleeves plus a V-neck notch between
  the two shoulder points. Filled with `kitColorHex`, `1px` dark semi-transparent border (see
  "Kit color contrast safety net" below), jersey number centered inside in `kitFontColorHex`,
  team's player name in a small label below the marker.
- **Own-half placement:** each team is confined strictly to its own half — home team's rows
  run from the bottom byline up toward (but not crossing) the halfway line; away team's rows
  run from the top byline down toward (but not crossing) the halfway line. Row depth is
  normalized *per team's own formation* (`max` of that team's own `row` values), not a
  hardcoded constant — a 4-4-2 (4 row-lines) and a 4-2-3-1 (5 row-lines) each stretch evenly
  across their own half regardless of formation depth. Horizontal (`col`) position is
  similarly normalized per-row (a row with 4 defenders spaces them differently than a row
  with 1 lone striker). Exact placement formula (percentages of pitch height, `0%` = top
  edge), matching the approved mockup exactly — `BYLINE_MARGIN = 6`, `HALFWAY_MARGIN = 12`,
  `t = (row - 1) / (maxRow - 1)` (or `0` when `maxRow == 1`):
  - Home: `y% = (100 - 6) - t × ((100 - 6) - (50 + 12))`
  - Away: `y% = 6 + t × ((50 - 12) - 6)`
- **Halfway-margin bug (found and fixed during mockup iteration):** an early version used
  `HALFWAY_MARGIN = 2`, placing each team's deepest attacking row only 2% of pitch-height from
  the halfway line — smaller than a marker's own footprint, causing lone strikers from both
  teams (each centered horizontally, since each was the only player in their row) to visually
  collide directly on the halfway line. The `HALFWAY_MARGIN = 12` value above already fixes
  this (the two teams' closest rows land ~24% apart) — do not regress it back toward a smaller
  value without re-checking the lone-striker collision case.
- Substitutes render as a simple text list below the pitch (number + name + position),
  matching the existing Timeline's plain-list convention — no grid placement, since the API
  gives them no `col`/`row`.

### Kit color contrast safety net

`colors.mainColor`/`colors.fontColor` are real, live, per-match values — sometimes both teams
happen to have very light or very dark kits (confirmed directly: Botafogo `f7f7f7` vs Santos
effectively white/black in the same match). Rather than a curated per-team override table
(`TeamThemeOption`'s existing approach, which only covers BSA's 20 curated teams and doesn't
exist at all for the other 5 leagues once lineups eventually roll out there too), this reuses
the app's existing `WCAGContrast` utility as a general runtime check:

- **Jersey fill vs. pitch:** left as the raw `mainColor` — no correction. A `1px` dark
  semi-transparent border is drawn around every jersey marker regardless of fill color, giving
  every jersey a visible edge against the pitch without ever misrepresenting the team's actual
  kit color.
- **Number vs. jersey fill:** `kitFontColorHex` is computed during mapping via a new small
  reusable check (either a new method on `WCAGContrast` — e.g.
  `accessibleColorHex(candidateHex:against:)`, a single-surface simplification of
  `ThemeTokens.accessibleFontColorHex`'s existing two-surface logic — or equivalent): if
  `WCAGContrast.contrastRatio(fontColor, mainColor) >= 4.5`, use the API's `fontColor`
  unchanged; otherwise fall back to whichever of pure black/white scores a higher contrast
  ratio against `mainColor`. This is the same "validate the real value, correct only on
  failure" pattern already validated for Team Theme colors — never a per-team override table.

### Statistics: comparison bars

Six rows, one per stat, in this order: Possession, Shots, Shots on Target, Corners, Fouls,
Pass Accuracy. Each row: home/away numeric values above a two-segment horizontal bar (teal
`#2dd4bf` for home's share, `white @ 0.35` for away's share, proportional to
`home / (home + away)`), stat name centered below as a small uppercase label — matching the
approved mockup exactly. New localized strings needed for all 6 stat labels, in every
supported locale (`pt-BR`, `pt-PT`, `fr`, `en-US`, `en-GB`, `es`).

### Empty / unavailable states

Both new segments need an empty state matching Timeline's existing "No events yet" pattern
(`emptyEventsFontSize`, `themeTokens.textColor.opacity(0.45)`) for whenever
`fetchMatchStatistics`/`fetchMatchLineups` return `nil` — e.g. "Statistics not yet available"
/ "Lineups not yet available". Loading state (first tap on a segment, before the fetch
resolves) shows a lightweight spinner or the existing empty-state text momentarily — no new
loading-chrome component needed, matching how Timeline already has no explicit loading spinner
of its own.

### Accessibility

- The segmented `Picker` is a native SwiftUI control — VoiceOver support (announcing each
  segment name and selected state) comes for free, no custom work needed.
- Each stat row gets a combined `accessibilityLabel` speaking both values and which side is
  ahead (e.g. "Possession: Home 48 percent, Away 52 percent"), not relying on bar width alone
  — same pattern as `Standing.accessibilityLabel` spelling out what a visual-only signal
  (the zone ball) means in words.
- The pitch's decorative elements (grass gradient, halfway line, penalty boxes, center circle)
  are `.accessibilityHidden(true)`. Each player jersey marker is its **own** accessibility
  element (not merged into one combined blob) with a full spoken label — e.g. "Léo Linck,
  number 24, goalkeeper, Botafogo" — using localized full position words (Goalkeeper /
  Defender / Midfielder / Forward) rather than the API's bare "G"/"D"/"M"/"F" letters, new
  localized strings in all 6 locales. Deliberately *not* collapsed into a single hidden
  element with a text-list alternative: knowing *where* a player lines up is real football
  information the visual pitch already conveys to sighted users, and VoiceOver users should
  get the same information, not a lesser substitute. Markers are built in a fixed loop order
  (each team's rows back-to-front, left-to-right within a row) so the VoiceOver swipe order
  follows a sensible reading path even though the layout itself uses absolute positioning.
  Each team's formation gets a heading-trait label before its players (e.g. "Botafogo,
  formation 4-4-2").
- `AccessibilityAuditUITests.testMatchDetailAudit` currently only audits whatever's on screen
  by default (Timeline). It needs extending to also select the Stats and Lineups segments and
  audit each — the existing per-task pattern this session has repeatedly found real bugs by
  extending audit coverage to newly-added UI, not assuming it's automatically covered.

### Out of Scope

- Per-player photos/badges — the API gives no photo URL, only name/number/position.
- Live-updating statistics/lineups during a live match via polling — `pollWhileLive()` keeps
  polling events only, matching today's behavior. Stats *do* change during a live match in
  principle, but a background segment isn't visible, so there's nothing to visibly update; if
  the user has the Stats/Lineups tab open during a live match, values may go stale until they
  reopen the sheet or manually reselect the tab — accepted trade-off, not fixed here.
- Formation grid for anything other than the two API-defined shapes (`col`/`row` for starting
  XI, flat list for substitutes) — no alternate visualizations (e.g. a bench depth chart).

## Testing

- **Models:** `MatchStatisticsTests`/`MatchLineupTests` (or added to existing model test
  files) — DTO decoding from real-shaped JSON, mapper output, and the WCAG font-color
  correction function's behavior on both a passing case (real distinct colors) and a failing
  case (near-white-on-white, matching the real Botafogo/Santos data found during design).
- **Services:** `LiveMatchService`/`MockMatchService` fetch methods — matches existing
  per-endpoint test coverage conventions.
- **ViewModel:** `MatchDetailViewModelTests` — `loadStatisticsIfNeeded()`/
  `loadLineupsIfNeeded()` are no-ops on a second call (mirroring `loadOnce()`'s existing
  guard-on-nil test pattern), and correctly surface `nil` as "not available" vs. a thrown
  error.
- **View:** per CLAUDE.md's "Unit test ViewModels and Services — not Views" — no new SwiftUI
  view tests; verified via the extended `testMatchDetailAudit` UI test (all 3 segments) plus a
  build/manual pass.
