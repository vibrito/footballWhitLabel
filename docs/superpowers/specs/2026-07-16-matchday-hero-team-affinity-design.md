# Matchday Hero Card Team Affinity Design

**Goal:** When a user has a Team Theme selected, the Matchday hero card features that
team's next match (home or away, live or scheduled) instead of the earliest match
league-wide. This is the last unbuilt piece of roadmap item #1 ("purchasable per-team
customization: icon, colors, and the purchased team featured in the Matchday hero card") —
alternate app icon and accent colors already shipped.

**Architecture:** `TeamThemeStore` already resolves and persists a selected
`TeamThemeOption` internally, but never exposes which one — it only exposes the resulting
`ThemeTokens` (colors). It gains one new piece of public state, `selectedOption:
TeamThemeOption?`, kept in sync wherever the store already mutates its selection today.
`MatchdayViewModel` gains a `TeamThemeStore` dependency and its `nextMatch` computed
property gains a first-priority branch: the selected team's own earliest live-or-scheduled
match, home or away. If the selected team has no such match (no theme selected, or that
team's season has no matches left), `nextMatch` falls through to exactly the existing
league-wide-earliest logic, unchanged. Everything downstream of `nextMatch` — the
same-day "Finished"/"Also Today" sections — already derives from whatever match `nextMatch`
resolves to, so it needs no changes.

---

## Components

### `TeamThemeStore` changes (`BR2026/Services/TeamThemeStore.swift`)

Add a stored property, set at the same three points the store already resolves an option:

```swift
private(set) var selectedOption: TeamThemeOption?
```

- In `loadOnce()`: set right after resolving `option` from `setting.selectedThemeID`,
  before calling `apply(option)` — and left `nil` if no persisted selection exists (the
  existing early-return path).
- In `select(_:)`: set to `option` (or `nil` for the "Default" case) in lockstep with the
  existing `setting.setSelectedThemeID(...)` calls — including the early-return `nil`
  branch and the color-resolution-failure branch (which today leaves the selection
  unchanged and returns `false`; `selectedOption` must likewise stay unchanged on that
  failure path, matching the existing `tokens` behavior).

No other `TeamThemeStore` behavior changes — `tokens`, `apply(_:)`'s internals, and
`resolveColors(teamID:)` are untouched.

### `MatchdayViewModel` changes (`BR2026/ViewModels/MatchdayViewModel.swift`)

```swift
private let themeStore: TeamThemeStore

init(service: MatchService, themeStore: TeamThemeStore) {
    self.service = service
    self.themeStore = themeStore
}

var nextMatch: Match? {
    if let teamID = themeStore.selectedOption?.teamID,
       let teamMatch = matches
            .filter { ($0.homeTeam.id == teamID || $0.awayTeam.id == teamID) && ($0.status == .live || $0.status == .scheduled) }
            .min(by: { $0.utcDate < $1.utcDate }) {
        return teamMatch
    }
    return matches
        .filter { $0.status == .live || $0.status == .scheduled }
        .min { $0.utcDate < $1.utcDate }
}
```

The fallback branch is the exact pre-existing expression, unchanged — this is strictly
additive. No "always where possible" edge case needs extra handling beyond "does a
matching match exist": a live match elsewhere never displaces the selected team's own
(later) match, per the earlier confirmed decision — this is a personalized card, not a
"what's live right now" card.

### DI wiring (`ContentView.swift`)

`ContentView` already constructs `themeStore: TeamThemeStore` once, at the app-init level
(`ChampionshipApp`), and passes it down for `MoreView`/`TeamThemePickerViewModel`. It gains
one more pass-through:

```swift
MatchdayView(service: service, themeStore: themeStore)
```

`MatchdayView` gains a matching `themeStore: TeamThemeStore` stored property and
initializer parameter, threaded straight into `MatchdayViewModel(service:themeStore:)` at
its `_viewModel = State(initialValue:)` construction site. No other view code changes —
`HeroMatchCard` itself needs no changes, since it already just renders whatever `Match` it's
given.

---

## Data Flow

**No team selected (default app state):** `themeStore.selectedOption` is `nil` →
`nextMatch` falls straight to the existing league-wide-earliest logic — behavior is
byte-for-byte identical to today.

**Team selected, has an upcoming/live match:** `nextMatch` returns that match regardless of
whether some other match is live right now or scheduled sooner — the hero card, and
everything derived from it (same-day sections), now center on the selected team.

**Team selected, no matches left this match window/season:** the team-priority filter
returns `nil` (no live/scheduled match for that `teamID`), so `nextMatch` falls through to
the league-wide fallback — same behavior as no selection.

**Theme deselected (user picks "Default" in the picker):** `TeamThemeStore.select(nil)`
sets `selectedOption = nil` in the same call that resets `tokens`, so the very next time
`MatchdayViewModel.nextMatch` is read (SwiftUI's Observation tracks the cross-object
property read automatically, the same way it already tracks `matches`), the hero reverts
to the league-wide match.

---

## Testing

- `TeamThemeStoreTests.swift`: extend with assertions that `selectedOption` reflects the
  resolved option after `loadOnce()`, updates after `select(_:)` (including back to `nil`
  for the Default case), and stays unchanged when `select(_:)`'s color resolution fails.
- `MatchdayViewModelTests.swift`: every existing test's `MatchdayViewModel(service:)`
  construction gains a `themeStore:` argument (a `TeamThemeStore` with nothing selected,
  preserving today's behavior for tests that aren't specifically about team affinity — same
  precedent as prior constructor-signature changes in this codebase, e.g.
  `TeamThemePickerViewModel` gaining `purchaseStore:`). New cases:
  - Selected team's own scheduled match wins over an earlier league-wide match.
  - Selected team's own match wins even when a different match is live right now.
  - Falls back to the league-wide earliest match when the selected team has none
    live/scheduled.
  - Unchanged (league-wide) behavior when no team is selected — a direct regression guard
    for the default-app-state path.

---

## Out of Scope

- No visual "this is your team" badge/marker beyond simply featuring the match — the
  hero card's existing themed border (already driven by whichever `ThemeTokens` is
  active) is untouched and predates this feature.
- No change to which matches populate the "Finished"/"Also Today" same-day sections beyond
  the fact that they now key off a possibly-different `nextMatch`.
- No support for "team affinity" based on a purchased Team *Icon* rather than a selected
  Team *Theme* — confirmed the Team Theme selection is the single source of truth for this
  feature.
- No multi-team support (e.g. featuring more than one purchased team, or a way to pick a
  "favorite" independent of the active theme) — out of scope per the current roadmap
  wording, which refers to a single purchased/selected team.
