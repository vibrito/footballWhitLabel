# Standings Zone Markers — Design Spec

## Goal

Visually mark relegation and continental-qualification (Champions League/Europa
League/Conference League/Copa Libertadores/Copa Sudamericana, per competition) position
ranges in the Standings table, the way most football apps do — closing roadmap item 6b.

## Background

The `/v4/competitions/{code}/standings` endpoint was verified live (all 6 competitions —
`BSA`, `PL`, `FL1`, `PPL`, `SPL`, `PD`) to now include a per-team `description: String` field
that was previously undocumented/unused in this codebase. Real, current values observed:

```
BSA: "Promotion - Copa Libertadores (Group Stage)"
BSA: "Promotion - Copa Libertadores (Qualification)"
BSA: "Promotion - Copa Sudamericana (Group Stage)"
BSA: "Relegation - Serie B"
BSA: "None"                                              (mid-table, no marker)
PL:  "Champions League league stage"
PL:  "Relegation"
FL1: "Champions League"
FL1: "Relegation Playoffs"
FL1: "Relegation"
PPL: "Promotion - Champions League (League phase)"
PPL: "Promotion - Champions League (Qualification)"
PPL: "Liga Portugal (Relegation)"
PPL: "Relegation - Liga Portugal 2"
SPL: "Promotion - Premiership (Championship Group)"
SPL: "Premiership (Relegation Group)"
PD:  "Champions League league stage"
PD:  "Relegation"
```

This is free-text from the upstream data provider — not a clean enum, not consistent wording
across competitions, and always in English regardless of app locale. There is no existing
field for this on `Standing`/`StandingDTO` (both currently decode only
`position`/`team`/`playedGames`/`won`/`draw`/`lost`/`goalsFor`/`goalsAgainst`/`goalDifference`
/`points`).

## Design

### Classification: two keyword-based buckets

Rather than an exact-string lookup table (which would break the moment wording shifts
slightly, or need separate entries for all 6 competitions' different vocabularies), classify
by substring match into two buckets:

- **`qualification`**: `description` contains `"Promotion"`, OR contains any of `"Champions
  League"`, `"Europa League"`, `"Conference League"`, `"Libertadores"`, `"Sudamericana"`.
  (The `"Promotion"` prefix alone would miss `PL`/`FL1`/`PD`'s bare `"Champions League
  league stage"`/`"Champions League"` values, which have no `"Promotion -"` prefix — hence
  the OR with explicit competition names.)
- **`relegation`**: `description` contains `"Relegation"`. (Reliably present, as a substring,
  in every observed relegation-adjacent value across all 6 competitions — including SPL's
  `"Premiership (Relegation Group)"`, a mid-season split-round grouping rather than literal
  end-of-season relegation, which still gets tagged `relegation` under this simple rule per
  the confirmed design choice: no per-competition tuning.)
- **Everything else** (`"None"`, `nil`, or any unrecognized text) — no marker.

This is a pure function of the stored `description` string, computed on demand — not stored
as its own persisted field.

### Data layer

- Add `description: String?` to `StandingDTO` (matches the API field name/nullability
  directly — the API returns the literal string `"None"` rather than JSON `null` for
  no-marker rows, per the observed data above, so this stays a plain optional `String` and
  the classification function below treats both `nil` and `"None"` the same way).
- Add `var zoneDescription: String?` to `Standing` (the persisted SwiftData model), mapped
  1:1 from the DTO in `Standing.init(dto:)` and `Standing.update(from:)`-equivalent logic
  (whatever the existing DTO→model mapping path is for Standings — the delete-and-reinsert
  refresh documented in `CLAUDE.md`).
- Add a computed property on `Standing`: `var zone: StandingZone` (a new small enum,
  `.qualification`, `.relegation`, `.none`), implementing the keyword classification above.

### Visual treatment

A thin colored bar on the leading edge of each `Standing` row — the common convention in
football standings tables (ESPN, BBC Sport, etc. all use a left-edge color accent per row,
not a full-row tint, to avoid competing with the row's own `themeTokens.textColor` /
team-theme-driven styling already in place).

- `qualification` → teal, reusing CLAUDE.md's existing `advance: #2dd4bf` status color (no
  new color needed — this is exactly the semantic role that color already documents:
  "advance").
- `relegation` → a new status color, added to CLAUDE.md's Status section alongside
  `advance`/`playoff`: `relegation: #ef4444` (a clear, saturated red distinct from the app's
  default Sunset Red theme accent `#ff4d5e`, so it reads clearly as a status color rather
  than blending with an active team theme's accent when one is selected).
- `.none` → no bar, row renders exactly as it does today.

### Labels — ours, not the API's

Per the confirmed design decision, the raw `description` text is never displayed directly —
it only drives classification. Two new localized strings (translated into all 6 supported
locales, matching every other user-facing string in this app):

- `"Continental qualification"` (or equivalent per-locale phrasing) for `qualification` rows.
- `"Relegation zone"` (or equivalent) for `relegation` rows.

These labels appear in two places:
1. A small legend below the Standings table (e.g. two color-swatch + label pairs), so users
   unfamiliar with the color convention understand what the bars mean.
2. Folded into `Standing.accessibilityLabel` (already exists, covered by VoiceOver work
   shipped earlier this session) — e.g. appending `", <label>"` when `zone != .none`, so
   VoiceOver users get the same information sighted users get from the color bar.

### Out of Scope

- The API's exact `description` wording is not surfaced anywhere in the UI, by design.
- Any further breakdown beyond the two buckets (e.g., a visually distinct color for
  Libertadores vs. Sudamericana, or for "Qualification" vs. "Group Stage" playoff rounds) —
  deliberately deferred per the confirmed "simple 2-tier" scope decision.
- Standings table redesign/polish (roadmap item 6c) — a separate, distinct item.
- Any change to how standings are fetched/refreshed/persisted beyond adding the one new
  field — the existing delete-and-reinsert refresh strategy is unaffected.

## Testing

`StandingZone` classification is pure-function, plain-Swift logic (no SwiftUI dependency,
matching this codebase's Model-layer convention) — unit-testable in
`BR2026Tests/Models/StandingTests.swift` against the real observed API strings from all 6
competitions listed above, plus `nil`/`"None"`/an unrecognized string.

View-layer wiring (the leading color bar, the legend) follows this project's established
convention (CLAUDE.md: "Unit test ViewModels and Services — not Views") — verified by a clean
build and, if useful, a manual pass; no new UI test is strictly required, though extending
`StandingsAudit`'s existing coverage costs nothing extra once the row is wired.
