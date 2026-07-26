# Scottish Premiership Crest Symbols — Design

**Date:** 2026-07-26
**Status:** approved (all 12 clubs reviewed on the crest board)

## Goal

Give the Scottish Premiership target the same hand-curated *futebol de botão* crest discs the
Brasileirão target has, by adding 12 entries to `TeamCrestSymbols.byTeamID`.

Today every Scottish club falls through to the initials placeholder in `TeamCrestBadge`,
because `byTeamID` contains only the 20 Brazilian clubs.

## Scope

**In:** 12 band-data entries in `BR2026/Models/TeamCrestSymbol.swift`.

**Out:** any change to `TeamCrestSymbol`'s cases, to `TeamCrestBadge`'s rendering, or to the
crest cache. The existing engine draws all 12 patterns unchanged — this is data only.

Deliberately **not** a new screen. The crest board that drove this review is a throwaway web
artifact, not app UI.

## Why no target gating

`byTeamID` is keyed by team ID and consulted per team, so entries are inert unless that team
appears in the data. Adding Scottish clubs cannot affect the Brazilian build, and none of the
`#if TARGET_*` gating that `AppIconOption` and `MoreViewModel.preferencesRows` need applies
here. Clubs with no entry keep the initials placeholder, which is how every Scottish club
renders today.

## Team IDs

Taken from the live `SPL` standings rather than assumed, so they match what the app receives:

| ID | Club | ID | Club |
|---|---|---|---|
| 247 | Celtic | 250 | Kilmarnock |
| 249 | Hibernian | 251 | St Mirren |
| 252 | Aberdeen | 253 | Dundee |
| 254 | Heart of Midlothian | 256 | Motherwell |
| 257 | Rangers | 258 | St Johnstone |
| 1386 | Dundee Utd | 1389 | Falkirk |

## Patterns

Four shapes cover all twelve, all using existing cases:

- **Horizontal bands** — Celtic's hoops; Motherwell's claret band across amber.
- **Seven equal vertical bands** — Kilmarnock, St Mirren and Dundee Utd share one shape:
  three dark bars with the club colour at both edges.
- **Fine vertical pinstripes** — Rangers only, at a 6 : 0.35 band ratio. Much finer than
  anything in the Brazilian set, where the thinnest pinstripe is Bragantino's 0.6.
- **Sleeve bands / single stripe / paired bars / solid** — Hibernian and Falkirk (colour body
  between two thin white edges), St Johnstone, Dundee, and the three solids.

`diagonalSash` and `concentric` stay unused: no Premiership club wears a sash.

## Decisions made during review

- **Rangers is pinstriped, not solid.** Its blue is `#005ABA`, sampled from a kit photo
  (~4,700 shirt pixels, excluding sponsor text, crest and collar). The initial guess of
  `#1B458F` was too dark and too muted. `#005ABA` is nearly identical to
  `ChampionshipConfig.scottishPremiership`'s `#005EB8` accent, which is a coincidence worth
  knowing rather than a dependency — neither reads from the other.
- **Dundee is two centred white bars on navy**, mirroring São Paulo's paired-bar structure
  rotated vertical. Chosen over plain navy, which read as a near-twin of Falkirk.
- **Dundee Utd is tangerine and black striped**, not solid tangerine — the same seven-band
  shape as St Mirren.
- **St Johnstone keeps a thin white stripe.** It was originally added to separate it from a
  then-solid Rangers. That reason disappeared when Rangers gained pinstripes, but the stripe
  was kept on review.

## Known risk

The board renders discs at 104px; the app draws them at roughly 24pt on match cards. **Rangers'
0.35-weight pinstripes and Dundee's 0.7-weight centre gap are the two most likely to disappear
or shimmer against the disc's glossy highlight at that size.** Neither can be judged from the
board.

Check both in the simulator before considering this done. If the pinstripes vanish, widening
them to `0.5` keeps the character without going heavy — a data change, no code.

## Testing

Per CLAUDE.md, unit tests cover ViewModels and Services, not Views, and this is neither: it is
a static data table feeding a View. There is no behaviour to assert that would not simply
restate the table.

The meaningful verification is visual, at real size, in the simulator — see Known risk.
