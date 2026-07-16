# VoiceOver Accessibility — Design

## Context

First phase of the accessibility roadmap item (item #3): VoiceOver support, whole app. Dynamic
Type, contrast, and reduced motion are deliberately out of scope — each is its own future phase
(per the "one phase at a time" decision). Depends on the live-match-polling project
(`2026-07-16-live-match-polling-design.md`), now shipped, which gives this phase real refresh
points to hang live-announcement behavior off of.

A codebase survey confirmed the starting point: zero `accessibilityLabel`/`accessibilityHint`/
traits anywhere, no `accessibilityReduceMotion` handling, and only `minimumScaleFactor` (not true
Dynamic Type) in two places. Nothing in this app has been built with VoiceOver in mind.

## Scope

Whole app: all 4 tabs (Matchday, Fixtures, Standings, More), the Match Detail sheet, the App
Icon/Team Theme pickers, and Terms of Service. Since views/components are shared across all 6
championship targets (config-driven architecture), this work is done once and applies everywhere.

## 1. Model-level accessibility API

Computed properties colocated with each Model, matching the existing `Team.displayName`
pattern of UI-facing computed properties living on the Model rather than the View:

- **`Match.accessibilityLabel: String`** — combines opponent names, score (or "vs" if not
  started), status, and time/minute into one sentence, e.g. *"Flamengo 2, Palmeiras 1, live,
  67th minute"* or *"Flamengo versus Palmeiras, kicks off at 4:00 PM"* or *"Flamengo 2, Palmeiras
  1, final score"*.
- **`Standing.accessibilityLabel: String`** — one sentence per table row, e.g. *"3rd place,
  Flamengo, 10 played, 7 won, 2 drawn, 1 lost, goal difference plus 15, 15 points"*.
- **`MatchEvent.accessibilityLabel: String`** — e.g. *"67th minute, goal, Neymar"*, *"23rd
  minute, yellow card, Casemiro"*, *"80th minute, substitution, Player In for Player Out"*.

All strings go through `String(localized:)` with the same locale set as everything else in the
app. Each is a pure function of existing stored properties — no new state, fully unit-testable
with Swift Testing (these Models can be instantiated directly, no SwiftData container needed).

## 2. Live score-change announcements

`MatchdayViewModel`/`FixturesViewModel`/`MatchDetailViewModel` all call `load()` from real
refresh points now: initial load, pull-to-refresh, background→foreground return (via
`refreshIfNeeded()`), and the 30-second live poll (`pollWhileLive()`, from the polling project).
The diff/announcement logic lives in one place shared by all of them, rather than needing its
own separate trigger.

- **`Match.accessibilityAnnouncement(comparedTo previous: Match) -> String?`** — a pure,
  testable function returning an announcement string when something worth speaking changed (a
  goal: score delta; a status transition: kicks off → live, live → finished), or `nil`
  otherwise. No `UIAccessibility` call inside it — fully unit-testable, matching the project's
  pattern of keeping side effects out of testable logic.
- Each `load()` in `MatchdayViewModel`/`FixturesViewModel` computes these announcements by
  comparing the old `matches` array to the freshly fetched one *before* reassigning, then calls
  `UIAccessibility.post(notification: .announcement, argument:)` once per non-nil result — the
  one non-testable side-effecting line, kept as thin as possible.
- This fires from *any* refresh, not poll-exclusive — a VoiceOver user pulling to refresh and
  getting a new score also hears about it, matching how a manual refresh should behave.

## 3. Per-screen wiring

### Matchday & Fixtures (share `HeroMatchCard`, `FixtureMatchCard`, `TeamCrestBadge`, `LiveChip`)

- `HeroMatchCard`/`FixtureMatchCard`: `.accessibilityElement(children: .combine)` with
  `.accessibilityLabel(match.accessibilityLabel)` as one VoiceOver stop instead of
  crest/name/score/venue each being separate stops. `.accessibilityHint("Double tap to view
  match details")`; `.accessibilityAddTraits(.isButton)` confirmed during implementation (likely
  already implicit via the `Button` wrapper).
- `TeamCrestBadge`: `.accessibilityHidden(true)` — decorative; the adjacent team-name `Text`
  already conveys identity.
- `LiveChip`: `.accessibilityHidden(true)` — its content is already folded into the parent
  card's combined label; its pulse animation has no independent meaning.
- `RefreshPulseDot` (Fixtures' nav-bar refresh indicator): `.accessibilityHidden(true)`.
- Fixtures' round picker pills: `.accessibilityLabel("Round \(round)")` plus
  `.accessibilityAddTraits(isSelected ? .isSelected : [])`.
- Section headers ("Finished", "Also Today"): `.accessibilityAddTraits(.isHeader)`.

### Standings

`StandingsView` is a manual grid (not a native `List`/`Table`), so by default VoiceOver reads
each column cell separately as a bare number with no context.

- Each row: `.accessibilityElement(children: .combine)` with
  `.accessibilityLabel(standing.accessibilityLabel)` as one combined stop instead of 8 separate
  ones.
- `TeamCrestBadge`: `.accessibilityHidden(true)`, same reasoning as above.
- Header row (`P`/`W`/`D`/`L`/`GD`/`Pts`): `.accessibilityHidden(true)` on the whole `HStack` —
  redundant once every row's combined label spells out "played"/"won"/etc. in full words.

### Match Detail

- Round eyebrow: already a plain, correctly-localized `Text` — no change.
- Team/score/status block (the two `teamColumn`s + `centerScore` + `statusLine`): combine into
  one element using the same `match.accessibilityLabel`, so it reads consistently with match
  cards elsewhere. `TeamCrestBadge` instances hidden.
- Venue row (the `(i)` info icon + venue name): needs its own explicit
  `.accessibilityLabel("Venue: \(venueName)")` — a bare icon next to text has no inherent
  spoken meaning without one.
- Half-time text (when present): stays a separate stop after the main block.
- "Timeline" section header: `.accessibilityAddTraits(.isHeader)`.
- `MatchTimelineRow`: combine into one element per row using `event.accessibilityLabel` — a
  real gap today, since the icon (⚽/card/arrows) currently conveys event type with no text
  equivalent anywhere. The icon becomes `.accessibilityHidden(true)` once folded into the row's
  label.
- "No events yet": already fine as plain `Text`.

### More, pickers, Terms of Service

- `MoreView.rowLabel`: combine icon + title + chevron into one element with
  `.accessibilityLabel(row.titleKey text)`; icon and chevron hidden individually. Disabled rows
  (`row.isEnabled == false`, 30% opacity) need `.accessibilityAddTraits(.notEnabled)` — today
  VoiceOver would announce them as a plain tappable row with no indication they're inert.
- Competition header (logo + name): logo hidden (decorative), name `Text` already fine.
- `AppIconPickerView`/`TeamThemePickerView` rows (`freeRowView`/`teamRowView`/`rowView`): same
  pattern in both files. Combine into one element per row with a constructed label reflecting
  the state a sighted user sees from the lock/checkmark icons — e.g. `"\(option.displayName),
  locked, \(price)"` or `"\(option.displayName), selected"` — plus a matching hint ("Double tap
  to purchase" vs "Double tap to select"). Preview thumbnail and lock/checkmark icons hidden
  once folded into the label.
- "Restore Purchases" button (both pickers): already fine — its `Text` label matches its
  visible content.
- Error message `Text` (both pickers): fine as-is.
- `TermsOfServiceView`: no changes — a single `Text` block, already fully accessible by
  default.

## 4. Automated accessibility audit tests

`BR2026UITests` already runs as part of every `fastlane test app:br2026` invocation (confirmed
— `SmokeUITests`/`SnapshotUITests` both execute today alongside the Swift Testing suite, no
separate lane needed), so a new test file there is picked up for free.

- **New file:** `BR2026UITests/AccessibilityAuditUITests.swift` — one test per major screen
  (Matchday, Fixtures, Standings, More, Match Detail, App Icon picker, Team Theme picker),
  navigating via `tabBar.buttons.element(boundBy:)` (matching `SnapshotUITests`' existing
  convention) then calling
  `try app.performAccessibilityAudit(for: [.sufficientElementDescription, .trait, .action, .parentChild, .elementDetection])`.
- Deliberately excludes `.contrast` and `.dynamicType` from the audit scope — those belong to
  their own future roadmap phases; running them now would mix out-of-scope findings into this
  phase's regression gate.
- Tradeoff worth naming: this adds real time to every `fastlane test` run
  (`SnapshotUITests.testCaptureScreenshots` alone already takes ~36s and hits the live API) —
  but that's already the accepted shape of this test suite, not something new introduced here.

## Testing summary

- Model computed properties (`accessibilityLabel`, `accessibilityAnnouncement(comparedTo:)`):
  Swift Testing, no SwiftData container, matching existing Model test conventions.
- Per-screen View wiring: not unit tested (CLAUDE.md convention — Views aren't unit tested),
  verified via the new automated audit tests plus manual VoiceOver/Accessibility Inspector spot
  checks during implementation.
- `AccessibilityAuditUITests`: real XCUITest suite, becomes part of the standing regression gate
  via `fastlane test`.

## Out of scope

Dynamic Type, contrast, reduced-motion handling — each its own future phase. The `.contrast`/
`.dynamicType` audit types are excluded from this phase's automated tests for the same reason.
