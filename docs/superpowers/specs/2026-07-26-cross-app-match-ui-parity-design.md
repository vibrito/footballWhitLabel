# Cross-App Match UI Parity — Design

**Date:** 2026-07-26
**Status:** approved (design agreed in conversation; spec pending review)

## Goal

Make the two apps' match surfaces read the same: Matchday/Today, the round list, and match
detail. BR2026 (the white-label repo) is the reference for **look**; Fixture 2026 is the
reference for **two features it already has and BR2026 lacks**.

Five deliverables. They do not all copy in the same direction, which is the thing most likely
to be got wrong:

| # | Deliverable | Copies |
|---|---|---|
| 1 | Section headers on Fixture 2026's Today screen | BR2026 → Fixture 2026 |
| 2 | `MatchCard` type and chrome values | BR2026 → Fixture 2026 |
| 3 | Section titles on BR2026's Fixtures screen | Fixture 2026 → BR2026 |
| 4 | Stats + Lineups in match detail | BR2026 → Fixture 2026 |
| 5 | Goal assists in the timeline (bug fix) | Fixture 2026 → BR2026 |

## Non-goal: sharing the code

`CrestDisc` and `TeamCrestSymbol` are shared byte-for-byte between the repos via
`scripts/sync-crests.sh`. **None of the work in this spec can use that mechanism**, because
every file involved reads an app-specific model:

- Scores: BR2026 `match.homeScore` vs Fixture 2026 `match.score.fullTime.home`
- Status: BR2026 `.halftime` vs Fixture 2026 `.paused`; Fixture 2026's `.live(minute)` carries
  an associated value, BR2026's `.live` does not
- Events: BR2026 `MatchEventType` is a flat enum with `detail: String`; Fixture 2026's carries
  associated values (`goal(ownGoal:penalty:)`)

So this is a **values copy**, and the files will drift again unless someone re-checks them.
Unifying the two `Match` models is the agreed eventual direction and would make these screens
genuinely shareable, but it is explicitly out of scope here.

---

## Deliverable 1 — Section headers on Fixture 2026's Today screen

`LeagueTodayContent.matchContent` (`Fixture2026App/Views/Today/TodayView.swift:130-140`)
renders the hero and then a flat `ForEach` over `dayMatches`. BR2026's `MatchdayView` splits
the same list into two labelled sections.

Adopt BR2026's structure, using the `SectionHeader` component Fixture 2026 already has:

- `FINISHED` — matches with `.finished` status
- `ALSO TODAY` — the remainder, excluding the hero

Match BR2026's ordering: hero, then Finished, then Also Today. Both sections are omitted when
empty, as BR2026 does.

`TournamentTodayContent` is left alone — it shows the final plus the third-place play-off and
already has its own `SectionHeader`.

## Deliverable 2 — `MatchCard` copies `FixtureMatchCard`

Every value below is lifted from `BR2026/Components/FixtureMatchCard.swift`. Nothing here is
invented, and BR2026 does not change.

| Property | Fixture 2026 now | → target |
|---|---|---|
| team name | 15 semibold | **16 semibold** |
| score | 16 heavy | **19 heavy** |
| card fill | `white @ 0.07` | **`white @ 0.05`** |
| shadow radius | 11 | **22** |
| row divider | inset 14pt, `white @ 0.06` | **full width, `white @ 0.10`** |
| header divider | `white @ 0.08` hairline | **none** (BR2026 uses 12pt spacing instead) |
| header tracking | kerning 0.8 | **tracking 0.6** |
| finished status | `FT` | **`25 Jul · FT`** |
| scheduled status | `20:00` | **`25 Jul · 20:00`** |
| row padding | 14 horizontal | **16 (via the card's own padding)** |
| crest | 24 | 24 — already matches |

BR2026 wraps its content in `GlassCard(cornerRadius: 22, style: .transparent)`, which supplies
`white @ 0.05` fill, a `white @ 0.16` 0.5pt border, `black @ 0.22` shadow at radius 22 / y 8,
and 16pt padding. Fixture 2026 has no `GlassCard`; reproduce those values inline rather than
introducing one, to keep the change to a single file.

## Deliverable 3 — Section titles on BR2026's Fixtures screen

`FixturesView` (`BR2026/Views/Fixtures/FixturesView.swift:24-32`) renders a flat `LazyVStack`
over `viewModel.selectedRoundMatches`. Fixture 2026's `FixturesViewModel.sections` already
produces exactly the grouping wanted. Mirror that logic in `BR2026/ViewModels/FixturesViewModel`:

- **Live now** — `.live` or `.halftime` (BR2026's spelling of Fixture 2026's `.paused`)
- **Finished** — `.finished`
- **Later today** / **Upcoming** — everything else

Sections are omitted when empty and always appear in that order.

### The "Later today" vs "Upcoming" decision

Fixture 2026's league path **never** shows "Later today". Its code gates the label on
`!isLeague`, with the comment: *"Later today only means anything when the list is a single
day."* A league round can span Saturday to Monday, so the label would be wrong for most of it.

BR2026's Fixtures is round-navigated, so taking Fixture 2026's rule verbatim would give
"Upcoming" always — but "Later today" is what was explicitly asked for.

**Resolved:** compute it per round rather than per format. If every not-yet-played match in the
selected round falls on today, the title is **Later today**; otherwise **Upcoming**. This gives
the requested label whenever it is accurate and avoids it whenever it would lie — strictly
better than either app's current rule, and it is why BR2026 does not simply copy the
`!isLeague` gate.

### Header styling

BR2026's section-header styling is currently inline in `MatchdayView.matchSection` (13pt bold,
tracking 0.8, `textColor @ 0.5`, uppercase, `.isHeader` trait). Fixtures now needs the
identical treatment, so extract it into `BR2026/Components/SectionHeader.swift` and have both
screens use it. This mirrors the component Fixture 2026 already has under the same name.

New localized strings are required in BR2026's catalog: `Live now`, `Later today`, `Upcoming`.
`Finished` already exists (used by Matchday).

## Deliverable 4 — Stats and Lineups in Fixture 2026's match detail

BR2026's `MatchDetailView` has a three-way segmented picker (Timeline / Stats / Lineups).
Fixture 2026's is timeline-only, with no picker.

**Fixture 2026's data layer is already complete and unused.** No service or model work is
needed:

| Layer | State in Fixture 2026 |
|---|---|
| `MatchService.fetchMatchStatistics` / `fetchMatchLineups` | declared |
| `LiveMatchService` | implemented against the API |
| `LeagueMatchService` | implemented against the API |
| `MockMatchService` | returns `nil` for both |
| `MatchStatistics`, `MatchLineup` | defined |
| `APIStatisticsResponse`, `APILineupsResponse` | defined, with mappers |

What is missing is UI and ViewModel wiring:

1. **Segment enum + picker.** Port `MatchDetailSegment` and the `.pickerStyle(.segmented)`
   picker from BR2026.
2. **ViewModel.** Add `selectedSegment`, `statistics`, `lineups`, and lazy
   `loadStatisticsIfNeeded()` / `loadLineupsIfNeeded()` fired on segment change, as BR2026 does.
3. **`StatisticsView`** (~81 lines). `TeamStats` is field-for-field identical in both apps —
   same six fields (`fouls`, `shots`, `corners`, `possession`, `passAccuracy`,
   `shotsOnTarget`), same order. Near-verbatim port; substitute `.white` for BR2026's
   `themeTokens.textColor`, since Fixture 2026 has no theme tokens.
4. **`LineupsView`** (~268 lines). See the kit-colour note below.
5. **Header alignment.** BR2026's detail header uses a round eyebrow, 80pt crests and a 48pt
   score; Fixture 2026 uses 46pt and different crest sizing. Copy BR2026's.
6. **Empty states.** BR2026 shows "Statistics not yet available" / "Lineups not yet available"
   when the fetch returns nil. Port both — they are the normal case before kickoff, not errors.

### The kit-colour gap in `LineupsView`

BR2026 colours the shirts on the pitch from `TeamLineup.kitColorHex` / `kitFontColorHex`.
Fixture 2026's `TeamLineup` has neither.

This is a **decoding gap, not a data gap**. The same endpoint on the same backend returns a
`colors` object; BR2026's `TeamLineupDTO` decodes it (`MatchLineupDTO.swift:14`) and Fixture
2026's `APITeamLineup` simply stops at `formation` / `startingXI` / `substitutes`. The fix is
to add an optional `colors` field to `APITeamLineup`, carry it through `MatchMapper`, and add
the two properties to `TeamLineup`.

Keep BR2026's fallbacks: `808080` main and `FFFFFF` font when `colors` is null. A scheduled
match's lineups response returns `"colors": null`, so the fallback is the normal pre-kickoff
path, not an error case.

## Deliverable 5 — Goal assists in BR2026's timeline (bug fix)

### Root cause

The API returns assists. Verified live against BSA match `1492309`:

```json
{ "team": "away", "type": "GOAL", "player": "Igor Formiga",
  "assist": "Reinaldo", "detail": "Normal Goal", "minute": 30 }
```

BR2026 decodes it correctly into `MatchEvent.assist: String?`
(`BR2026/Models/MatchEvent.swift:26`). The data reaches the model intact and then **nothing in
BR2026 ever reads that property.** It is a dead field. Two surfaces drop it:

1. **`MatchTimelineRow.swift:105`** — the goal subtitle returns `nil` for `"Normal Goal"`.
2. **`MatchEvent.accessibilityLabel`** (`MatchEvent.swift:37-75`) — never mentions the assist,
   so VoiceOver announces "30 minute, goal, Igor Formiga".

Fixture 2026 reads it at `MatchDetailView.swift:338`.

The difference is structural rather than accidental: Fixture 2026 encodes penalty and own-goal
in the enum (`goal(ownGoal:penalty:)`), leaving the subtitle slot free for the assist. BR2026
carries them in `detail: String` and spends the subtitle slot on them, so the assist had
nowhere to go and was never wired up.

### Fix

Both apps already use the same precedence — own goal → penalty → assist — so only the final
fallback is missing. In `MatchTimelineRow.subtitleText`, replace the `nil`:

```swift
case "Normal Goal": return event.assist.map { Text("Assist: \($0)") }
```

`"Penalty"` and `"Own Goal"` keep their current text. A normal goal with no assist still
returns `nil`, so unassisted goals are unchanged.

Add the assist to `accessibilityLabel` for goals when present, so the two surfaces agree.

Requires one new localized string in BR2026's catalog: `Assist: %@`.

---

## What stays different, and why

These are differences that carry meaning rather than styling drift. Making them "the same"
would remove information.

**Kept in Fixture 2026, absent from BR2026:**

- **Loser dimming** — the losing team's name fades to 40% on finished *knockout* matches
  (`MatchCard.nameColor`). BR2026 has no knockouts.
- **Group prefix** — the card header reads `GROUP A · VENUE`. BR2026 has no groups.
- **Penalty display** — `FT · PEN` and the shoot-out winner line in match detail.

**Kept in BR2026, absent from Fixture 2026:**

- **Theme tokens.** Every BR2026 colour goes through `themeTokens`; Fixture 2026 uses literal
  `.white`. Ported code substitutes `.white` rather than introducing theming there.

## Testing

Per CLAUDE.md, unit tests cover ViewModels and Services, not Views. That splits this work:

**Gets tests:**

- **Deliverable 3** — the sectioning logic lives on `FixturesViewModel`. Assert the three
  groups, that empty groups are omitted, the order, and specifically the "Later today" vs
  "Upcoming" choice: a round whose upcoming matches are all today, versus one that spans days.
- **Deliverable 5** — `MatchEvent.accessibilityLabel` is on the model, not a View. A goal with
  an assist must name the assisting player; a goal without one must be unchanged. This is a
  genuine failing-test-first cycle.

**Gets no tests:** Deliverables 1, 2 and 4 are Views. Verification is visual, in the simulator,
at real size.

## Risks

- **Deliverable 4 is the large one** — roughly 350 lines of ported view code plus ViewModel and
  DTO changes. It is the only deliverable that touches Fixture 2026's service DTOs, and the one
  most likely to need its own review pass. It could be split into its own plan if the others
  are wanted sooner.
- **`MockMatchService` returns nil** for statistics and lineups in Fixture 2026, so the ported
  Stats and Lineups tabs will show their empty states under mocks. Verifying them needs the
  live service and a match at or after kickoff.
- **The values copy will drift.** Nothing enforces Deliverable 2's parity the way
  `CrestSyncTests` enforces the crest files'. This is accepted here and is an argument for the
  model unification noted at the top.
- **`CLAUDE.md` is stale** on this area: its Scope section says "Match detail covers the events
  timeline; statistics and lineups are deferred to a future phase." BR2026 shipped both. Fix
  that line as part of this work.
