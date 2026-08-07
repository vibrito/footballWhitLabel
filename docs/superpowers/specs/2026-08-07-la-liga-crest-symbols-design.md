# La Liga Crest Symbols — Design

**Date:** 2026-08-07
**Status:** approved (all 20 clubs reviewed on the crest board)

## Goal

Give La Liga the same hand-curated *futebol de botão* discs the Brasileirão, Scottish
Premiership and Liga Portugal have, by adding 20 entries to `TeamCrestSymbols.byTeamID`.

Today every Spanish club falls through to the initials placeholder, because `byTeamID`
covers only the 50 clubs of the other three boards.

## Why now

La Liga was switched on in both hub apps today. The whole-branch review of that change
found the gap: it is the **first board to launch with no curated marks at all**. The
curated set is exactly 50 entries on every platform — 20 Brasileirão, 12 Scottish
Premiership, 18 Liga Portugal — which is 100% coverage of every board shipped so far. So
on 15 August the Spanish board would show "RE", "BA", "AT", "SE" across match cards, the
round list and the table, while the App Store description promises "clean club marks for
the leagues".

Both `TeamBadge` implementations fall back to initials and **deliberately never** to the
provider's crest — the discs exist precisely so the app shows a club's colours without
reproducing its badge. So nothing renders wrong today; it renders thin.

## How this differs from the previous two crest sets

| | Scottish (2026-07-26) | Portuguese (2026-07-26) | La Liga (this one) |
|---|---|---|---|
| Entries | 12 | 18 | 20 |
| New enum case | no | yes (`checkerboard`) | **no** |
| Renderer change | no | yes (`CrestDisc`) | **no** |
| Copies to update | 1 | 2 | **3** |

This is the first crest set that is **pure data** *and* has to reach three copies, because
the Android app did not exist when the other two were written. Nothing in
`TeamCrestSymbol` or `CrestDisc` changes — every one of the 20 fits the existing
vocabulary.

### But six of them exercise a renderer branch that has never run

`concentric` has **zero entries in any of the three catalogues today.** The case is
declared, documented, and implemented on both platforms — and no club has ever used it. Six
of these twenty do: Real Madrid, Sevilla, Elche, Valencia, Villarreal, Osasuna.

So "no renderer change" is accurate but incomplete. No renderer code is *edited*, but a
quarter of this set is the first traffic through a path that has only ever been dead code.
Both implementations were read side by side and they agree — outer→inner, each band's
circle spanning the radius out to the sum of its own weight and every inner band's, over
the total (`CrestDisc.swift:92-104`, `CrestDisc.kt:73-85`; iOS sets a diameter, Android a
radius, which is the same thing). The crest board's renderer reproduces that algorithm and
the discs were approved against it.

That is a code read, not a run. The implementation plan must **look at one concentric disc
on each platform** before the set is called done. It is the one part of this change where
"the tests pass" would not tell us anything: a geometry error here renders wrong rather
than throwing.

## The problem specific to this league

The previous two sets could give almost every club its own palette. This division cannot.
As the clubs actually play, **eleven of the twenty sit in a look-alike pair or cluster**:

- Five wear blue-and-white vertical stripes: Deportivo, Málaga, Real Sociedad, Alavés, Espanyol
- Two wear red-and-white: Atlético, Athletic
- Two wear blue-and-garnet: Barcelona, Levante
- Two wear green-and-white: Betis, Racing Santander

A twelfth problem sits underneath those: **four clubs are predominantly white** — Real
Madrid, Sevilla, Elche, Valencia — and a white disc disappears against a light background
whether or not anything else looks like it.

The rule that came out of the board review: **shape before hue.** At 20 px — the size that
actually decides this — a hue shift between two royal blues is invisible, while a 5-band
disc against a 9-band one is not. Hue is the second lever, not the first.

## Decisions taken during the board review

Everything below was decided by looking at rendered discs at 20 px, not by reasoning about
hexes.

| Decision | Why |
|---|---|
| **Málaga's blue lightened to `33B5E5`** (from `0067B1`) | Deportivo and Málaga were the *same disc* — identical 5-band shape, separated only by `0055A5` against `0067B1`, which is not a difference at badge size. Málaga's blue genuinely is lighter than Depor's royal, so this separates them on something real. The lighter blue also pulled Málaga away from Real Sociedad and Alavés at the same time. |
| **Racing Santander is white with green side bands**, not green-and-white stripes | Ends the Betis collision outright: one is repeating green/white stripes, the other a white field with green edges. No reliance on band count. |
| **The four mostly-white clubs take a `concentric` rim** in their accent colour | A plain white disc vanishes on a light background. Gold (Real Madrid), red (Sevilla), green (Elche), orange (Valencia) solves visibility and mutual confusion in one move. |
| **Atlético keeps navy edge bands; Athletic does not** | Navy is Atlético's genuine third colour (shorts, collar). That is the honest separator between two red-and-white striped sides. |
| **Levante inverted so garnet sits outside** | Barcelona is blue-outside, 5 broad bands; Levante garnet-outside, 7 narrower. Reviewed and confirmed distinguishable. |
| **Racing/Elche adjacency accepted** | Both read as "white disc, green edge". They differ in *shape* — Racing's green touches only the left and right arcs, Elche's goes all the way round — and a shape difference is what survives at 20 px, unlike the hue difference that failed for Deportivo/Málaga. Reviewed and accepted as-is. |

Two things were considered and rejected: giving one of a colliding pair **horizontal
stripes**, and using a **`concentric`** treatment where the club wears stripes. Both would
have invented a pattern the club does not wear. Every separator in the final set is
something real about the club.

### The board reviewed for collisions within La Liga only

Every pair above was checked against the other nineteen La Liga discs, not against the 50
already in the catalogue. Two cross-league near-duplicates fell out when someone checked
afterwards:

- **Real Sociedad (548, `003C8F`) and Kilmarnock (250, `003C7D`)** — the same disc: seven
  equal vertical bands, white-edged. The hexes are 18 RGB units apart in the blue channel
  alone, the same magnitude the board rejected as invisible when it lightened Málaga's blue
  away from Deportivo's.
- **Real Betis (543, `00954C`) and Rio Ave (226, `007A3D`)** — same shape, seven equal bands,
  a 31-unit delta. Second closest.

Neither pair is being touched. These hexes were approved on the board and the constraint
above is explicit: no crest data changes as a result of this review.

They are also currently unreachable together: the matchday feed is scoped per championship
and `PD` carries no cup fixtures, so a Real Sociedad card and a Kilmarnock card cannot appear
on the same board today, and likewise for Betis and Rio Ave.

Adding UCL, UEL or UECL as `fixturesOnly` competitions and listing one in a matchday feed's
`cups` is the route by which clubs from different countries reach the same round list — but
it is **necessary, not sufficient**, and an earlier draft of this section wrongly treated it
as the whole trigger. Two clubs also have to be *in* that competition in the same season.
Kilmarnock are not in Europe, so the Real Sociedad pair would not appear together even if the
cups were wired tomorrow.

Which makes the useful form of this note the general one rather than the two pairs: **the
board only ever checks within one division, so the first time a `cups` entry puts two
divisions on one board, the cross-league comparison has to be run again for whichever clubs
actually qualified.** The two pairs above are what that check found in August 2026, and they
are worth knowing — but they are a sample, not the standing risk.

## Team IDs

Taken from the live `PD` standings, not assumed, so they match what the apps receive.

| ID | Club | ID | Club |
|---|---|---|---|
| 529 | Barcelona | 542 | Alavés |
| 530 | Atlético Madrid | 543 | Real Betis |
| 531 | Athletic Club | 544 | Deportivo La Coruña |
| 532 | Valencia | 546 | Getafe |
| 533 | Villarreal | 548 | Real Sociedad |
| 535 | Málaga | 727 | Osasuna |
| 536 | Sevilla | 728 | Rayo Vallecano |
| 538 | Celta Vigo | 797 | Elche |
| 539 | Levante | 4665 | Racing Santander |
| 540 | Espanyol | | |
| 541 | Real Madrid | | |

## The set

Swift, as it goes into `TeamCrestSymbols.byTeamID`. Every entry carries a comment in the
file explaining the disc, as the existing entries do — that is the part that is expensive
to reconstruct later.

```swift
// Blue and white vertical stripes — five clubs, separated by band count first.
544: .equalStripes(["0055A5", "FFFFFF", "0055A5", "FFFFFF", "0055A5"]),          // Deportivo
535: .equalStripes(["33B5E5", "FFFFFF", "33B5E5", "FFFFFF", "33B5E5"]),          // Málaga
548: .equalStripes(["FFFFFF", "003C8F", "FFFFFF", "003C8F", "FFFFFF", "003C8F", "FFFFFF"]),  // Real Sociedad
542: .verticalStripes([                                                           // Alavés
    .init("FFFFFF", 1), .init("0761AF", 3), .init("FFFFFF", 1), .init("0761AF", 3),
    .init("FFFFFF", 1), .init("0761AF", 3), .init("FFFFFF", 1)
]),
540: .equalStripes(["FFFFFF", "007FC8", "FFFFFF", "007FC8", "FFFFFF", "007FC8", "FFFFFF", "007FC8", "FFFFFF"]),  // Espanyol

// Red and white — Atlético's navy is the honest separator.
530: .verticalStripes([                                                           // Atlético Madrid
    .init("262E62", 1), .init("CB3524", 3), .init("FFFFFF", 3), .init("CB3524", 3),
    .init("FFFFFF", 3), .init("CB3524", 3), .init("262E62", 1)
]),
531: .equalStripes(["FFFFFF", "EE2523", "FFFFFF", "EE2523", "FFFFFF", "EE2523", "FFFFFF"]),  // Athletic Club

// Blue and garnet — Barcelona blue-outside, Levante garnet-outside.
529: .equalStripes(["004D98", "A50044", "004D98", "A50044", "004D98"]),          // Barcelona
539: .equalStripes(["A61B2B", "004B9B", "A61B2B", "004B9B", "A61B2B", "004B9B", "A61B2B"]),  // Levante

// Greens.
543: .equalStripes(["FFFFFF", "00954C", "FFFFFF", "00954C", "FFFFFF", "00954C", "FFFFFF"]),  // Real Betis
4665: .verticalStripes([.init("009540", 1), .init("FFFFFF", 3), .init("009540", 1)]),  // Racing Santander

// Mostly white, separated by their rim colour.
541: .concentric([.init("FEBE10", 0.8), .init("FFFFFF", 4)]),                     // Real Madrid
536: .concentric([.init("D8020E", 1), .init("FFFFFF", 4)]),                       // Sevilla
797: .concentric([.init("00714A", 1), .init("FFFFFF", 4)]),                       // Elche
532: .concentric([.init("F18E00", 1), .init("FFFFFF", 4)]),                       // Valencia

// Solids and one-offs.
728: .diagonalSash(background: "FFFFFF", stripe: "E53027", widthFraction: 0.30),  // Rayo Vallecano
533: .concentric([.init("003D7C", 0.7), .init("FFE667", 4)]),                     // Villarreal
538: .equalStripes(["8AC3EE"]),                                                   // Celta Vigo
546: .equalStripes(["005999"]),                                                   // Getafe
727: .concentric([.init("0A1D5B", 0.8), .init("D91A21", 4)]),                     // Osasuna
```

## Files, and the ripple

Three copies of the same data, kept in step by two different mechanisms — one enforced,
one not.

| # | File | How it is kept in step |
|---|---|---|
| 1 | `footballWhiteLabel/BR2026/Models/TeamCrestSymbol.swift` | **Source of truth.** Edit here. |
| 2 | `worldcup/Fixture2026App/Models/TeamCrestSymbol.swift` | `scripts/sync-crests.sh` copies it and stamps both with a hash of their own content. **Enforced** — each repo's `CrestSyncTests` recomputes the hash and fails if it does not match the stamp. |
| 3 | `WorldCupAndroid/…/data/crests/CuratedCrestSymbols.kt` | **Nothing enforces this one.** See below. |

Sequence: edit (1) → run `scripts/sync-crests.sh` → both Swift copies re-stamp → port to
(3) → commit all three repos. Skipping the sync fails `CrestSyncTests` in whichever repo
was edited, which is the point of the stamp.

### The Android copy is unenforced, and its comment overstates the tooling

`CuratedCrestSymbols.kt`'s header says the catalogue was "ported from iOS's
`TeamCrestSymbols.byTeamID` **by script** rather than by hand — every hex and every weight
is copied, not retyped, because a mistyped digit here is a wrong club colour that no test
would catch."

**No such script exists in either repository.** `scripts/sync-crests.sh` is Swift→Swift
only; it does not know Android exists. Whatever produced the Kotlin file was not committed.

That matters here more than it has before, because this change adds 20 entries at once —
the largest single crest addition — and the file's own comment names the exact failure
mode: a mistyped digit is a wrong club colour that no test catches. There is no hash stamp
between iOS and Android, so nothing will tell us if the two drift.

The implementation plan should therefore **write the Android entries from the Swift source
mechanically rather than by retyping**, and say how. Building a committed port script is
out of scope for this change but is the obvious follow-up, and this spec is the record that
it does not exist.

## Testing

**Android has a count ratchet that must be updated.**
`CuratedCrestSymbolsTest.kt:33-38` asserts `assertEquals(50, all.size)` under a comment
reading "iOS's `TeamCrestSymbols.byTeamID` had 50 entries at the time of the port: 20
Brasileirão, 12 Scottish Premiership, 18 Liga Portugal." Both the number and the comment's
breakdown need to become 70 and include La Liga — a test whose comment names the wrong
leagues is worse than one with no comment.

**iOS has no equivalent count ratchet**, on either side of the sync. Adding one is not
required by this change; `CrestSyncTests` already guarantees the two Swift copies are
byte-identical, which is the stronger property.

**Both `CrestSyncTests` will fail until `sync-crests.sh` is run.** That is the mechanism
working, not a problem to debug.

Beyond that: the existing Android test already validates hex format and band shape across
the whole catalogue, so the 20 new entries are covered by it the moment they land.

## Out of scope

- **No new enum case and no renderer edit.** Every disc fits the existing vocabulary —
  though six are the first ever to use `concentric`, so that path wants a look. See above.
- **No change to when a disc is shown** — `TeamCrestBadge`'s policy, `TeamBadge`, and the
  crest cache are all untouched.
- **Not the marketing site.** `website/` has no band engine.
- **Not a committed Android port script.** Named above as the follow-up.
- **Deliberately not a new screen.** The crest board that drove this review is a throwaway
  artifact, not app UI.

## Why no target gating

`byTeamID` is keyed by team ID and consulted per team, so entries are inert unless that
team appears in the data. Adding Spanish clubs cannot affect the Brazilian, Scottish,
Portuguese or World Cup builds. Clubs with no entry keep the initials placeholder, which is
how every Spanish club renders today.

This is also why the 20 entries are harmless in copies that never see a La Liga team ID:
they are dead weight measured in bytes.
