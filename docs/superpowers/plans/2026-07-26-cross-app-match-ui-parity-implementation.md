# Cross-App Match UI Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the two apps' Matchday, round list and match-detail screens read the same, and fix a bug where BR2026 silently drops goal assists.

**Architecture:** Six tasks across two separate git repos. Tasks 1–2 change the white-label repo (`BR2026`); tasks 3–6 change the Fixture 2026 repo (`../worldcup`). Nothing here uses the shared-file sync mechanism — every file involved reads an app-specific model, so this is a hand-copy of values. Tasks 1 and 2 are unit-testable (they touch a model and a ViewModel); tasks 3–6 are Views and are verified visually.

**Tech Stack:** SwiftUI (iOS 26), Swift Testing (`@Test`/`@Suite`), `xcodebuild`.

## Global Constraints

- **Two separate repos, each with its own commits. Never push** — pushing is not part of this plan.
  - White-label: `/Users/mlbbr-mac-vinicius/projects/footballWhiteLabel` (targets `BR2026`)
  - Fixture 2026: `/Users/mlbbr-mac-vinicius/projects/worldcup` (targets `Fixture2026`)
- **Work directly on `main` in both repos.** No branches, no worktrees.
- **Do NOT run `scripts/sync-crests.sh`** and do not touch `TeamCrestSymbol.swift` or `CrestDisc.swift`. Those are the byte-shared crest files and are unrelated to this work. If a `crest-sync` stamp changes, something has gone wrong.
- **No hardcoded user-facing strings.** Every user-visible string goes through `String(localized:)` or a `Text(...)` literal that the string catalog picks up, per CLAUDE.md. New strings needed: `Live now`, `Later today`, `Upcoming`, `Assist: %@` (all in BR2026's catalog; `Finished` already exists).
- **No force-unwraps (`!`) outside tests.**
- **Unit tests cover ViewModels and Services, not Views** (CLAUDE.md). Tasks 3–6 therefore add no tests; that is correct, not an omission.
- **BR2026 does not change appearance.** It is the reference for look. The only BR2026 changes in this plan are the assist bug fix (Task 1) and the Fixtures sectioning (Task 2).
- **Shell is zsh, not bash.** When piping `xcodebuild` through `tail`, use `set -o pipefail` and echo `${pipestatus[1]}` (lowercase, 1-indexed). Bash's `${PIPESTATUS[0]}` expands to empty here and reads as a pass while checking nothing.
- **Test commands** (destinations verified available on this machine):
  - White-label: `xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:BR2026Tests`
  - Fixture 2026: `xcodebuild test -project Fixture2026.xcodeproj -scheme Fixture2026 -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:Fixture2026Tests`
- **Ask the user before running any `xcodebuild` command** unless they have pre-approved builds for this run.

**Spec:** `docs/superpowers/specs/2026-07-26-cross-app-match-ui-parity-design.md`

---

## File Structure

### White-label repo (`footballWhiteLabel`)

| File | Change |
|---|---|
| `BR2026/Components/MatchTimelineRow.swift` | Goal subtitle falls back to the assist |
| `BR2026/Models/MatchEvent.swift` | `accessibilityLabel` names the assisting player |
| `BR2026/Components/SectionHeader.swift` | **new** — extracted from `MatchdayView` |
| `BR2026/Views/Matchday/MatchdayView.swift` | Use the extracted `SectionHeader` |
| `BR2026/ViewModels/FixturesViewModel.swift` | Add `sections` |
| `BR2026/Views/Fixtures/FixturesView.swift` | Render sections instead of a flat list |
| `BR2026Tests/Models/MatchEventTests.swift` | Append assist tests |
| `BR2026Tests/ViewModels/FixturesViewModelTests.swift` | Append sectioning tests |
| `CLAUDE.md` | Correct the stale scope line |

### Fixture 2026 repo (`worldcup`)

| File | Change |
|---|---|
| `Fixture2026App/Components/MatchCard.swift` | Copy BR2026's card values |
| `Fixture2026App/Views/Today/TodayView.swift` | Add Finished / Also Today sections |
| `Fixture2026App/Services/DTOs/APILineupsResponse.swift` | Decode the `colors` object |
| `Fixture2026App/Models/MatchLineup.swift` | `TeamLineup` gains kit colours |
| `Fixture2026App/Services/MatchMapper.swift` | Carry colours through |
| `Fixture2026App/ViewModels/MatchDetailViewModel.swift` | Segment + lazy stat/lineup loads |
| `Fixture2026App/Views/MatchDetail/MatchDetailView.swift` | Segmented picker + segment content |
| `Fixture2026App/Components/StatisticsView.swift` | **new** — port |
| `Fixture2026App/Components/LineupsView.swift` | **new** — port |

---

### Task 1: Show goal assists in BR2026's timeline

The bug: the API returns `assist` (verified live — BSA match `1492309` has `"assist": "Reinaldo"` on a `"detail": "Normal Goal"` event), `MatchEvent` decodes it, and then nothing in BR2026 reads the property. Two surfaces drop it: the timeline subtitle and the VoiceOver label.

`accessibilityLabel` lives on the model, so it gets a real failing test. The timeline row is a View and does not.

**Files:**
- Modify: `BR2026/Models/MatchEvent.swift:37-75` (`accessibilityLabel`)
- Modify: `BR2026/Components/MatchTimelineRow.swift:103-109` (`subtitleText`)
- Modify: `CLAUDE.md` (stale scope line)
- Test: `BR2026Tests/Models/MatchEventTests.swift` (append)

**Interfaces:**
- Consumes: `MatchEvent.assist: String?` — already exists, already decoded.
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Write the failing tests**

Append to `BR2026Tests/Models/MatchEventTests.swift`, inside the existing `MatchEventTests` struct:

```swift
    @Test("accessibilityLabel names the assisting player on an assisted goal")
    func accessibilityLabelGoalWithAssist() {
        let event = MatchEvent(
            team: .away, type: .goal, assist: "Reinaldo", detail: "Normal Goal", minute: 30,
            player: "Igor Formiga", playerOut: nil, extraMinute: nil
        )
        let label = event.accessibilityLabel
        #expect(label.contains("Igor Formiga"))
        #expect(label.contains("Reinaldo"))
    }

    @Test("accessibilityLabel is unchanged for a goal with no assist")
    func accessibilityLabelGoalWithoutAssist() {
        let assisted = MatchEvent(
            team: .away, type: .goal, assist: "Reinaldo", detail: "Normal Goal", minute: 30,
            player: "Igor Formiga", playerOut: nil, extraMinute: nil
        )
        let unassisted = MatchEvent(
            team: .away, type: .goal, assist: nil, detail: "Normal Goal", minute: 30,
            player: "Igor Formiga", playerOut: nil, extraMinute: nil
        )
        // The unassisted label must not grow an empty or dangling assist clause.
        #expect(unassisted.accessibilityLabel != assisted.accessibilityLabel)
        #expect(!unassisted.accessibilityLabel.contains("Reinaldo"))
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the white-label test command from Global Constraints.
Expected: `accessibilityLabelGoalWithAssist` FAILS — the label does not contain "Reinaldo", because `accessibilityLabel` never reads `assist`. `accessibilityLabelGoalWithoutAssist` may already pass; that is fine, it is the regression guard.

- [ ] **Step 3: Add the assist to `accessibilityLabel`**

In `BR2026/Models/MatchEvent.swift`, the method currently ends:

```swift
        return String(
            localized: "\(minuteText) minute, \(eventWord), \(detailText)",
            comment: "VoiceOver label for one match timeline event. Arguments: the minute, the event type word (goal/yellow card/etc.), and the player detail."
        )
```

Replace that `return` with:

```swift
        let base = String(
            localized: "\(minuteText) minute, \(eventWord), \(detailText)",
            comment: "VoiceOver label for one match timeline event. Arguments: the minute, the event type word (goal/yellow card/etc.), and the player detail."
        )
        // Only goals carry an assist, and only when the API supplied one.
        guard type == .goal, let assist else { return base }
        return String(
            localized: "\(base), assist \(assist)",
            comment: "VoiceOver label for an assisted goal. Arguments: the base event label, and the assisting player's name."
        )
```

- [ ] **Step 4: Run the tests to verify they pass**

Run the white-label test command.
Expected: both new tests PASS, and the four pre-existing `accessibilityLabel` tests still pass.

- [ ] **Step 5: Show the assist in the timeline row**

In `BR2026/Components/MatchTimelineRow.swift`, `subtitleText` currently reads:

```swift
        case .goal:
            switch event.detail {
            case "Normal Goal": return nil
            case "Penalty": return Text("Penalty")
            case "Own Goal": return Text("Own Goal")
            default: return Text(event.detail)
            }
```

Change only the `"Normal Goal"` line:

```swift
        case .goal:
            switch event.detail {
            // The assist is the subtitle for an ordinary goal. Penalty and own goal keep
            // their own text — the same precedence Fixture 2026 uses, where own goal and
            // penalty win over the assist.
            case "Normal Goal": return event.assist.map { Text("Assist: \($0)") }
            case "Penalty": return Text("Penalty")
            case "Own Goal": return Text("Own Goal")
            default: return Text(event.detail)
            }
```

An unassisted normal goal still returns `nil`, so those rows are unchanged.

- [ ] **Step 6: Correct the stale line in CLAUDE.md**

In `CLAUDE.md`'s Scope section, find:

```
  beyond one accent color are out of scope. Match detail covers the events timeline;
  statistics and lineups are deferred to a future phase.
```

Replace the second sentence so it matches what BR2026 actually ships:

```
  beyond one accent color are out of scope. Match detail covers the events timeline,
  statistics and lineups.
```

- [ ] **Step 7: Run the full suite**

Run the white-label test command.
Expected: `** TEST SUCCEEDED **` and `${pipestatus[1]}` of 0.

- [ ] **Step 8: Commit**

```bash
cd /Users/mlbbr-mac-vinicius/projects/footballWhiteLabel
git add BR2026/Models/MatchEvent.swift BR2026/Components/MatchTimelineRow.swift \
        BR2026Tests/Models/MatchEventTests.swift CLAUDE.md
git commit -m "$(cat <<'EOF'
Show the assisting player on goals

The API has always returned an assist and MatchEvent has always decoded
it, but nothing read the property: the timeline subtitle returned nil for
a normal goal, and the VoiceOver label never mentioned it. The field has
been dead since it was added.

Penalties and own goals keep their existing subtitle, so the assist only
fills the slot an ordinary goal left empty.

Also corrects CLAUDE.md, which still claimed statistics and lineups were
deferred; both shipped.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Section titles on BR2026's Fixtures screen

`FixturesView` renders a flat list of the selected round's matches. Group it into Live now / Finished / Later today-or-Upcoming, mirroring Fixture 2026's `FixturesViewModel.sections`.

**The label rule is deliberately not a straight copy.** Fixture 2026 gates "Later today" on `!isLeague`, because a league round can span several days and the label would lie. BR2026 is round-navigated, so a verbatim copy would always say "Upcoming". Instead decide per round: if every unplayed match in the selected round falls on today, say **Later today**; otherwise **Upcoming**.

**Files:**
- Create: `BR2026/Components/SectionHeader.swift`
- Modify: `BR2026/Views/Matchday/MatchdayView.swift:108-124` (use the extracted component)
- Modify: `BR2026/ViewModels/FixturesViewModel.swift` (add `sections`)
- Modify: `BR2026/Views/Fixtures/FixturesView.swift:24-32` (render sections)
- Test: `BR2026Tests/ViewModels/FixturesViewModelTests.swift` (append)

**Interfaces:**
- Consumes: `FixturesViewModel.selectedRoundMatches: [Match]`, `MatchStatus` (`.scheduled`, `.live`, `.halftime`, `.finished`, `.postponed`).
- Produces:
  - `struct FixturesSection: Identifiable { let id: String; let title: String; let matches: [Match] }`
  - `FixturesViewModel.sections: [FixturesSection]`
  - `SectionHeader(title: String)` — a `View` in `BR2026/Components/`.

- [ ] **Step 1: Write the failing tests**

Append to `BR2026Tests/ViewModels/FixturesViewModelTests.swift`, inside the existing struct. `StubMatchService` and the `Team`/`Match` constructors are the ones already used by that file.

```swift
    @Test("Sections split the selected round into live, finished and upcoming, in that order")
    func sectionsSplitByStatus() async {
        let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)
        func match(_ id: Int, _ status: MatchStatus, _ offset: TimeInterval) -> Match {
            Match(
                id: id, utcDate: Date().addingTimeInterval(offset), status: status, matchday: 1,
                stage: "REGULAR_SEASON", homeTeam: team, awayTeam: team,
                homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
            )
        }
        // All on the same day as now, so the upcoming label resolves to "later today".
        let service = StubMatchService(
            matches: [match(1, .finished, -7200), match(2, .live, -600), match(3, .scheduled, 3600)],
            standings: []
        )
        let viewModel = FixturesViewModel(service: service)
        await viewModel.load()
        viewModel.selectedRound = 1

        #expect(viewModel.sections.map(\.id) == ["live", "finished", "upcoming"])
        #expect(viewModel.sections[0].matches.map(\.id) == [2])
        #expect(viewModel.sections[1].matches.map(\.id) == [1])
        #expect(viewModel.sections[2].matches.map(\.id) == [3])
    }

    @Test("Empty groups are omitted rather than shown with no rows")
    func sectionsOmitEmptyGroups() async {
        let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)
        let finished = Match(
            id: 1, utcDate: Date().addingTimeInterval(-7200), status: .finished, matchday: 1,
            stage: "REGULAR_SEASON", homeTeam: team, awayTeam: team,
            homeScore: 1, awayScore: 0, winner: "HOME_TEAM", venue: nil, minute: 90
        )
        let service = StubMatchService(matches: [finished], standings: [])
        let viewModel = FixturesViewModel(service: service)
        await viewModel.load()
        viewModel.selectedRound = 1

        #expect(viewModel.sections.map(\.id) == ["finished"])
    }

    @Test("Halftime counts as live, not upcoming")
    func sectionsTreatHalftimeAsLive() async {
        let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)
        let ht = Match(
            id: 1, utcDate: Date().addingTimeInterval(-2700), status: .halftime, matchday: 1,
            stage: "REGULAR_SEASON", homeTeam: team, awayTeam: team,
            homeScore: 1, awayScore: 1, winner: nil, venue: nil, minute: 45
        )
        let service = StubMatchService(matches: [ht], standings: [])
        let viewModel = FixturesViewModel(service: service)
        await viewModel.load()
        viewModel.selectedRound = 1

        #expect(viewModel.sections.map(\.id) == ["live"])
    }

    @Test("The upcoming title is 'later today' only when every unplayed match is today")
    func sectionsUpcomingTitleDependsOnDay() async {
        let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)
        func scheduled(_ id: Int, _ offset: TimeInterval) -> Match {
            Match(
                id: id, utcDate: Date().addingTimeInterval(offset), status: .scheduled, matchday: 1,
                stage: "REGULAR_SEASON", homeTeam: team, awayTeam: team,
                homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
            )
        }
        let sameDay = FixturesViewModel(
            service: StubMatchService(matches: [scheduled(1, 3600)], standings: [])
        )
        await sameDay.load()
        sameDay.selectedRound = 1
        let sameDayTitle = sameDay.sections[0].title

        // Three days out cannot be "today" regardless of when the suite runs.
        let spanning = FixturesViewModel(
            service: StubMatchService(matches: [scheduled(1, 3600), scheduled(2, 259_200)], standings: [])
        )
        await spanning.load()
        spanning.selectedRound = 1

        #expect(sameDayTitle != spanning.sections[0].title)
    }
```

Note the last test compares the two titles rather than asserting literal English, so it keeps passing under any locale.

- [ ] **Step 2: Run the tests to verify they fail**

Run the white-label test command.
Expected: all four FAIL to compile with "value of type 'FixturesViewModel' has no member 'sections'". A compile failure is the correct red state here.

- [ ] **Step 3: Add `sections` to the ViewModel**

In `BR2026/ViewModels/FixturesViewModel.swift`, add above the class:

```swift
struct FixturesSection: Identifiable {
    let id: String
    let title: String
    let matches: [Match]
}
```

and inside the class, after `selectedRoundMatches`:

```swift
    /// The selected round split into live / finished / upcoming, mirroring Fixture 2026's
    /// Fixtures screen. Empty groups are dropped so no header appears without rows.
    var sections: [FixturesSection] {
        let matches = selectedRoundMatches
        var result: [FixturesSection] = []

        let live = matches.filter(\.status.isLiveOrHalftime)
        if !live.isEmpty {
            result.append(FixturesSection(
                id: "live",
                title: String(localized: "Live now", comment: "Fixtures section header above matches currently being played."),
                matches: live
            ))
        }

        let finished = matches.filter { $0.status == .finished }
        if !finished.isEmpty {
            result.append(FixturesSection(
                id: "finished",
                title: String(localized: "Finished", comment: "Fixtures section header above matches that have ended."),
                matches: finished
            ))
        }

        let upcoming = matches.filter { !$0.status.isLiveOrHalftime && $0.status != .finished }
        if !upcoming.isEmpty {
            // Fixture 2026 never says "later today" for a league, because a round can span
            // several days and the label would lie. Decide per round instead: only claim
            // "today" when every unplayed match in this round actually is today.
            let calendar = Calendar.current
            let allToday = upcoming.allSatisfy { calendar.isDateInToday($0.utcDate) }
            let title = allToday
                ? String(localized: "Later today", comment: "Fixtures section header above matches still to be played today.")
                : String(localized: "Upcoming", comment: "Fixtures section header above matches still to be played, on this or a later day.")
            result.append(FixturesSection(id: "upcoming", title: title, matches: upcoming))
        }

        return result
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run the white-label test command.
Expected: all four new tests PASS; the pre-existing `FixturesViewModel` tests still pass.

- [ ] **Step 5: Extract `SectionHeader`**

Create `BR2026/Components/SectionHeader.swift`. The values are lifted verbatim from `MatchdayView.matchSection`, so Matchday's appearance does not change:

```swift
import SwiftUI

/// The uppercase section label used above a group of match cards, on both Matchday and
/// Fixtures. Mirrors the component of the same name in the Fixture 2026 app.
struct SectionHeader: View {
    let title: Text
    @Environment(\.themeTokens) private var themeTokens
    @ScaledMetric private var fontSize: CGFloat = 13

    init(_ title: Text) {
        self.title = title
    }

    init(_ title: String) {
        self.title = Text(title)
    }

    var body: some View {
        title
            .font(.system(size: fontSize, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(themeTokens.textColor.opacity(0.5))
            .textCase(.uppercase)
            .accessibilityAddTraits(.isHeader)
    }
}
```

- [ ] **Step 6: Use it from Matchday**

In `BR2026/Views/Matchday/MatchdayView.swift`, `matchSection` currently opens:

```swift
    private func matchSection(title: Text, matches: [Match]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            title
                .font(.system(size: sectionHeaderFontSize, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(themeTokens.textColor.opacity(0.5))
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
```

Replace those six styling lines with the component:

```swift
    private func matchSection(title: Text, matches: [Match]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title)
```

Then delete the now-unused `@ScaledMetric private var sectionHeaderFontSize: CGFloat = 13` declaration near the top of the file. Leave every other property alone.

- [ ] **Step 7: Render sections in Fixtures**

In `BR2026/Views/Fixtures/FixturesView.swift`, replace the `LazyVStack` body:

```swift
                        LazyVStack(spacing: 12) {
                            Color.clear.frame(height: 0).id(Self.topAnchor)
                            ForEach(viewModel.selectedRoundMatches, id: \.id) { match in
                                Button { selectedMatch = match } label: {
                                    FixtureMatchCard(match: match)
                                }
                                .buttonStyle(.plain)
                            }
                        }
```

with:

```swift
                        LazyVStack(alignment: .leading, spacing: 12) {
                            Color.clear.frame(height: 0).id(Self.topAnchor)
                            ForEach(viewModel.sections) { section in
                                SectionHeader(section.title)
                                    .padding(.top, section.id == viewModel.sections.first?.id ? 0 : 8)
                                ForEach(section.matches, id: \.id) { match in
                                    Button { selectedMatch = match } label: {
                                        FixtureMatchCard(match: match)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
```

The conditional top padding keeps the first header tight against the round picker while separating later groups.

- [ ] **Step 8: Run the full suite**

Run the white-label test command.
Expected: `** TEST SUCCEEDED **`, `${pipestatus[1]}` of 0.

- [ ] **Step 9: Commit**

```bash
cd /Users/mlbbr-mac-vinicius/projects/footballWhiteLabel
git add BR2026/Components/SectionHeader.swift BR2026/Views/Matchday/MatchdayView.swift \
        BR2026/ViewModels/FixturesViewModel.swift BR2026/Views/Fixtures/FixturesView.swift \
        BR2026Tests/ViewModels/FixturesViewModelTests.swift
git commit -m "$(cat <<'EOF'
Group the Fixtures round into live, finished and upcoming

The round list was flat, so a finished match and one kicking off tonight
sat in the same undifferentiated column. Fixture 2026's Fixtures screen
already groups the same three ways; this mirrors it.

The upcoming label is decided per round rather than per format. Fixture
2026 refuses to say "later today" for a league at all, because a round can
span several days — but it can also fall entirely on one day, and then the
label is right. So it says "later today" only when every unplayed match in
the round really is today.

Extracts the section header out of MatchdayView, unchanged, so both
screens share it.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Fixture 2026's `MatchCard` copies BR2026's values

Pure values copy. Every target below is lifted from `BR2026/Components/FixtureMatchCard.swift`; nothing is invented.

**Files:**
- Modify: `../worldcup/Fixture2026App/Components/MatchCard.swift`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Change the type sizes**

In `MatchCard.swift`, the `@ScaledMetric` block currently reads:

```swift
    @ScaledMetric private var dt10: CGFloat = 10
    @ScaledMetric private var dt11: CGFloat = 11
    @ScaledMetric private var dt15: CGFloat = 15
    @ScaledMetric private var dt16: CGFloat = 16
```

Add BR2026's two sizes alongside (leave `dt10`/`dt11` — the status badge still uses them):

```swift
    @ScaledMetric private var dt10: CGFloat = 10
    @ScaledMetric private var dt11: CGFloat = 11
    @ScaledMetric private var dt15: CGFloat = 15
    @ScaledMetric private var dt16: CGFloat = 16
    // BR2026's FixtureMatchCard values — team name 16, score 19.
    @ScaledMetric private var dt19: CGFloat = 19
```

In `teamRow`, change the name from `dt15` to `dt16` and the score from `dt16` to `dt19`:

```swift
            Text(team.displayName)
                .font(.system(size: dt16, weight: .semibold))
                .foregroundStyle(nameColor(for: side))
                .lineLimit(1)
            Spacer()
            Text(score)
                .font(.system(size: dt19, weight: .heavy).monospacedDigit())
                .foregroundStyle(scoreColor)
```

- [ ] **Step 2: Change the chrome**

In `body`, the card currently reads:

```swift
        .background(.white.opacity(0.07))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(.white.opacity(0.16), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.22), radius: 11, x: 0, y: 8)
```

Change the fill and shadow radius to BR2026's `GlassCard(style: .transparent)` values:

```swift
        .background(.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(.white.opacity(0.16), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.22), radius: 22, x: 0, y: 8)
```

- [ ] **Step 3: Change the dividers**

BR2026 has no divider under the header (it uses 12pt spacing) and a full-width row divider at `white @ 0.10`. In `body`, delete the first `Rectangle` — the one between `headerRow` and the home `teamRow`:

```swift
            headerRow
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 0.5)
            teamRow(match.homeTeam, ...)
```

becomes:

```swift
            headerRow
            teamRow(match.homeTeam, ...)
```

and change the remaining divider between the two team rows from inset `0.06` to full-width `0.10`:

```swift
            Rectangle()
                .fill(.white.opacity(0.10))
                .frame(height: 0.5)
```

(delete its `.padding(.horizontal, 14)` line).

- [ ] **Step 4: Change the header tracking and padding**

In `headerRow`, change `.kerning(0.8)` to `.kerning(0.6)` to match BR2026's `.tracking(0.6)`.

In both `headerRow` and `teamRow`, change `.padding(.horizontal, 14)` to `.padding(.horizontal, 16)`.

- [ ] **Step 5: Add the date to the status badge**

BR2026 shows `25 Jul · FT` and `25 Jul · 20:00`, not bare `FT` / `20:00`. In `statusBadge`, change the `.finished` and `.scheduled` cases:

```swift
        case .finished:
            let hasPen = match.score.penaltyWinner != nil
            let ft = hasPen
                ? "\(String(localized: "status.ft")) · \(String(localized: "status.pen"))"
                : String(localized: "status.ft")
            HStack(spacing: 4) {
                Text(match.date, format: .dateTime.day().month(.abbreviated))
                Text("·")
                Text(ft)
            }
            .font(.system(size: dt10, weight: .bold))
            .foregroundStyle(.white.opacity(0.5))
```

```swift
        case .scheduled:
            HStack(spacing: 4) {
                Text(match.date, format: .dateTime.day().month(.abbreviated))
                Text("·")
                Text(match.date, style: .time)
            }
            .font(.system(size: dt11, weight: .semibold).monospacedDigit())
            .foregroundStyle(.white.opacity(0.6))
```

Leave `.live`, `.paused` and `.postponed` untouched — the penalty suffix and `FT · PEN` behaviour are World-Cup-specific and stay.

- [ ] **Step 6: Build**

Run the Fixture 2026 test command from Global Constraints (it builds the app target as well as the tests).
Expected: `** TEST SUCCEEDED **`, `${pipestatus[1]}` of 0. No test asserts on these values — the build is the check.

- [ ] **Step 7: Commit**

```bash
cd /Users/mlbbr-mac-vinicius/projects/worldcup
git add Fixture2026App/Components/MatchCard.swift
git commit -m "$(cat <<'EOF'
Match BR2026's match-card proportions

The same fixture read differently in the two apps: smaller type, a heavier
card fill, a tighter shadow and a status badge that omitted the date. Take
BR2026's values, which are the reference for how a match card should look.

Loser dimming, the group prefix and the penalty suffix stay — those carry
World Cup meaning rather than styling drift.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Section headers on Fixture 2026's Today screen

`LeagueTodayContent.matchContent` lists the day's matches flat under the hero. BR2026's Matchday splits them into Finished and Also Today.

**Files:**
- Modify: `../worldcup/Fixture2026App/Views/Today/TodayView.swift:129-140`

**Interfaces:**
- Consumes: `SectionHeader(title: String)` — already exists in Fixture 2026 at `Fixture2026App/Components/SectionHeader.swift`. Note it takes a labelled `title:` argument, unlike the BR2026 component added in Task 2.
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Split the list into sections**

Replace `LeagueTodayContent.matchContent` entirely:

```swift
    @ViewBuilder
    private var matchContent: some View {
        if let hero = viewModel.featured {
            Button { open(hero) } label: { HeroMatchCard(match: hero) }
                .buttonStyle(.plain)
        }

        // Mirrors BR2026's Matchday: the hero, then the day's finished matches, then the
        // rest. Both groups are dropped when empty rather than shown with no rows.
        let others = viewModel.dayMatches.filter { $0.id != viewModel.featured?.id }
        let finished = others.filter { $0.status == .finished }
        let remaining = others.filter { $0.status != .finished }

        if !finished.isEmpty {
            SectionHeader(title: String(localized: "section.finished"))
            ForEach(finished) { match in
                Button { open(match) } label: { MatchCard(match: match) }
                    .buttonStyle(.plain)
            }
        }

        if !remaining.isEmpty {
            SectionHeader(title: String(localized: "section.also.today"))
            ForEach(remaining) { match in
                Button { open(match) } label: { MatchCard(match: match) }
                    .buttonStyle(.plain)
            }
        }
    }
```

Both `section.finished` and `section.also.today` already exist in Fixture 2026's string catalog — no new strings are needed.

`TournamentTodayContent` is not touched.

- [ ] **Step 2: Build**

Run the Fixture 2026 test command.
Expected: `** TEST SUCCEEDED **`, `${pipestatus[1]}` of 0.

- [ ] **Step 3: Commit**

```bash
cd /Users/mlbbr-mac-vinicius/projects/worldcup
git add Fixture2026App/Views/Today/TodayView.swift
git commit -m "$(cat <<'EOF'
Group Today's remaining matches under section headers

The league Today screen listed the day's other matches as one flat run
below the hero, so a match that finished hours ago sat directly beside one
yet to kick off. BR2026's Matchday already separates them; this mirrors it
using the SectionHeader and strings that already exist here.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Match-detail plumbing in Fixture 2026

Fixture 2026's match detail is timeline-only. Its whole data layer for statistics and lineups already exists and is never called. This task adds the segment state, the picker, and the kit-colour decoding the ported `LineupsView` will need in Task 6. It deliberately lands before the two views so the wiring can be reviewed on its own.

**Files:**
- Modify: `../worldcup/Fixture2026App/Services/DTOs/APILineupsResponse.swift`
- Modify: `../worldcup/Fixture2026App/Models/MatchLineup.swift`
- Modify: `../worldcup/Fixture2026App/Services/MatchMapper.swift:321` (`mapTeamLineup`)
- Modify: `../worldcup/Fixture2026App/ViewModels/MatchDetailViewModel.swift`
- Modify: `../worldcup/Fixture2026App/Views/MatchDetail/MatchDetailView.swift`

**Interfaces:**
- Consumes: `MatchService.fetchMatchStatistics(id:) async throws -> MatchStatistics?` and `fetchMatchLineups(id:) async throws -> MatchLineup?` — both already declared and implemented by `LiveMatchService` and `LeagueMatchService`.
- Produces, for Task 6:
  - `enum MatchDetailSegment: CaseIterable { case timeline, stats, lineups }`
  - `MatchDetailViewModel.selectedSegment: MatchDetailSegment`
  - `MatchDetailViewModel.statistics: MatchStatistics?`
  - `MatchDetailViewModel.lineups: MatchLineup?`
  - `TeamLineup.kitColorHex: String` and `TeamLineup.kitFontColorHex: String`

- [ ] **Step 1: Decode the colours the API already returns**

In `APILineupsResponse.swift`, add the colours type and give `APITeamLineup` an optional field. The endpoint returns `"colors": null` for a scheduled match, so it must be optional:

```swift
struct APILineupColors: Codable {
    let fontColor: String
    let mainColor: String
    let secondaryColor: String
}
```

and inside `APITeamLineup`, alongside `formation` / `startingXI` / `substitutes`:

```swift
    let colors: APILineupColors?
```

- [ ] **Step 2: Carry them onto the model**

In `Fixture2026App/Models/MatchLineup.swift`, add two properties to `TeamLineup`:

```swift
struct TeamLineup {
    let formation: String
    let startingXI: [LineupPlayer]
    let substitutes: [LineupPlayer]
    let kitColorHex: String
    let kitFontColorHex: String
}
```

- [ ] **Step 3: Map them, with BR2026's fallbacks**

In `MatchMapper.swift`, `mapTeamLineup` currently constructs a `TeamLineup` from `formation`, `startingXI` and `substitutes`. Add the two colour arguments, using the same defaults BR2026 uses when the API sends null:

```swift
            kitColorHex: api.colors?.mainColor ?? "808080",
            kitFontColorHex: api.colors?.fontColor ?? "FFFFFF"
```

- [ ] **Step 4: Add segment state to the ViewModel**

In `MatchDetailViewModel.swift`, add above the class:

```swift
enum MatchDetailSegment: CaseIterable {
    case timeline
    case stats
    case lineups
}
```

Add these stored properties beside the existing `events` / `loadState`:

```swift
    private(set) var statistics: MatchStatistics?
    private(set) var lineups: MatchLineup?
    var selectedSegment: MatchDetailSegment = .timeline
    private var hasLoadedStatistics = false
    private var hasLoadedLineups = false
```

and these methods:

```swift
    // Guarded because the segmented control's onChange fires on every tap, including
    // taps back to a tab already loaded — the fetch should happen once per sheet visit.
    func loadStatisticsIfNeeded(service: any MatchService) async {
        guard !hasLoadedStatistics else { return }
        hasLoadedStatistics = true
        statistics = try? await service.fetchMatchStatistics(id: match.id)
    }

    func loadLineupsIfNeeded(service: any MatchService) async {
        guard !hasLoadedLineups else { return }
        hasLoadedLineups = true
        lineups = try? await service.fetchMatchLineups(id: match.id)
    }
```

Note these take `service` as a parameter, because Fixture 2026's `MatchDetailViewModel` is constructed with only a `Match` and receives its service per call — unlike BR2026's, which stores one.

- [ ] **Step 5: Add the picker and segment content to the view**

In `MatchDetailView.swift`, add a picker below the existing match header and route the body through it. Keep the existing timeline as the `.timeline` case — do not rewrite it.

```swift
    private var segmentPicker: some View {
        Picker("", selection: $viewModel.selectedSegment) {
            Text("segment.timeline").tag(MatchDetailSegment.timeline)
            Text("segment.stats").tag(MatchDetailSegment.stats)
            Text("segment.lineups").tag(MatchDetailSegment.lineups)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
```

Place `segmentPicker` directly after the match header, then replace the direct use of `timelineSection` with:

```swift
    @ViewBuilder
    private var segmentContent: some View {
        switch viewModel.selectedSegment {
        case .timeline:
            timelineSection
        case .stats:
            // Statistics land in Task 6; until then this is the empty state, which is
            // also the correct display before kickoff.
            Text("stats.unavailable")
                .foregroundStyle(.white.opacity(0.45))
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
        case .lineups:
            Text("lineups.unavailable")
                .foregroundStyle(.white.opacity(0.45))
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
        }
    }
```

Add the lazy loads, using the service the view already reads from the environment for its existing `viewModel.load(service:)` call:

```swift
        .onChange(of: viewModel.selectedSegment) { _, newValue in
            Task {
                switch newValue {
                case .stats: await viewModel.loadStatisticsIfNeeded(service: services.service(for: competition))
                case .lineups: await viewModel.loadLineupsIfNeeded(service: services.service(for: competition))
                case .timeline: break
                }
            }
        }
```

If `MatchDetailView` does not already hold `@Environment(ServiceContainer.self) private var services` and `@Environment(\.competition) private var competition`, add them — `TodayView` shows the pattern.

- [ ] **Step 6: Add the five new strings**

Add to Fixture 2026's `Localizable.xcstrings`, with translations for all supported locales matching how neighbouring keys are localized: `segment.timeline` ("Timeline"), `segment.stats` ("Stats"), `segment.lineups` ("Lineups"), `stats.unavailable` ("Statistics not yet available"), `lineups.unavailable` ("Lineups not yet available").

- [ ] **Step 7: Build and run the suite**

Run the Fixture 2026 test command.
Expected: `** TEST SUCCEEDED **`, `${pipestatus[1]}` of 0. Existing lineup-mapping tests must still pass — if any construct a `TeamLineup` directly they will need the two new arguments.

- [ ] **Step 8: Commit**

```bash
cd /Users/mlbbr-mac-vinicius/projects/worldcup
git add Fixture2026App/Services/DTOs/APILineupsResponse.swift Fixture2026App/Models/MatchLineup.swift \
        Fixture2026App/Services/MatchMapper.swift Fixture2026App/ViewModels/MatchDetailViewModel.swift \
        Fixture2026App/Views/MatchDetail/MatchDetailView.swift Fixture2026App/Resources/Localizable.xcstrings
git commit -m "$(cat <<'EOF'
Add the match-detail segment picker and its plumbing

Match detail was timeline-only here, even though the service layer has
implemented fetchMatchStatistics and fetchMatchLineups all along and
nothing ever called them. This adds the segmented control, the lazy
per-segment loads, and the kit colours the lineups view will need — the
API already returned a colors object that APITeamLineup simply did not
decode.

Stats and Lineups show their empty states for now; the two views land
next.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Port `StatisticsView` and `LineupsView` to Fixture 2026

**Files:**
- Create: `../worldcup/Fixture2026App/Components/StatisticsView.swift`
- Create: `../worldcup/Fixture2026App/Components/LineupsView.swift`
- Modify: `../worldcup/Fixture2026App/Views/MatchDetail/MatchDetailView.swift` (use them)

**Interfaces:**
- Consumes: `MatchDetailViewModel.statistics`, `.lineups`, `TeamLineup.kitColorHex`, `.kitFontColorHex` — all from Task 5.
- Produces: `StatisticsView(statistics:)` and `LineupsView(lineup:homeTeamName:awayTeamName:)`.

- [ ] **Step 1: Port `StatisticsView`**

Copy `/Users/mlbbr-mac-vinicius/projects/footballWhiteLabel/BR2026/Components/StatisticsView.swift` to `Fixture2026App/Components/StatisticsView.swift` and apply exactly these substitutions:

1. Replace every `themeTokens.textColor` with `.white`, and every `themeTokens.textColor.opacity(x)` with `.white.opacity(x)`.
2. Delete the `@Environment(\.themeTokens) private var themeTokens` line — Fixture 2026 has no theme tokens.
3. Replace the six user-facing labels with Fixture 2026 catalog keys and add each to `Localizable.xcstrings` for all supported locales. The file contains exactly these six, and no others (the two remaining `Text(...)` calls interpolate numbers and need no key):

| BR2026 literal | suggested key |
|---|---|
| `Possession` | `stat.possession` |
| `Shots` | `stat.shots` |
| `Shots on Target` | `stat.shots.on.target` |
| `Pass Accuracy` | `stat.pass.accuracy` |
| `Fouls` | `stat.fouls` |
| `Corners` | `stat.corners` |

`TeamStats` is field-for-field identical in both apps — `fouls`, `shots`, `corners`, `possession`, `passAccuracy`, `shotsOnTarget`, in that order — so no field renaming is needed.

- [ ] **Step 2: Port `LineupsView`**

Copy `/Users/mlbbr-mac-vinicius/projects/footballWhiteLabel/BR2026/Components/LineupsView.swift` to `Fixture2026App/Components/LineupsView.swift` and apply the same three substitutions as Step 1, plus:

4. **`positionAccessibilityLabel` is required, not optional.** The ported file uses it at two places (BR2026's `LineupsView.swift:221` and `:264`, both inside VoiceOver labels). Fixture 2026's `LineupPlayer` does not have it. Copy the computed property verbatim from `BR2026/Models/MatchLineup.swift:17` into Fixture 2026's `LineupPlayer` in `Fixture2026App/Models/MatchLineup.swift`. Do **not** delete the accessibility labels to avoid the dependency — this app has an accessibility audit suite.
5. The file has one plain user-facing literal, `Substitutes` — give it a catalog key (`lineups.substitutes`) and add it for all locales. Every other `Text(...)` interpolates a team name, formation, shirt number or player name and needs no key.

`LineupsView` does **not** reference `TeamCrestBadge`, so no badge substitution is needed.

Do not otherwise restructure the file. It is a port, and a reviewer will diff it against the source.

- [ ] **Step 3: Wire both into the segment content**

In `MatchDetailView.swift`, replace the two placeholder empty states added in Task 5:

```swift
        case .stats:
            if let statistics = viewModel.statistics {
                StatisticsView(statistics: statistics)
            } else {
                Text("stats.unavailable")
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
            }
        case .lineups:
            if let lineups = viewModel.lineups {
                LineupsView(
                    lineup: lineups,
                    homeTeamName: viewModel.match.homeTeam.displayName,
                    awayTeamName: viewModel.match.awayTeam.displayName
                )
            } else {
                Text("lineups.unavailable")
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
            }
```

- [ ] **Step 4: Build and run the suite**

Run the Fixture 2026 test command.
Expected: `** TEST SUCCEEDED **`, `${pipestatus[1]}` of 0.

- [ ] **Step 5: Commit**

```bash
cd /Users/mlbbr-mac-vinicius/projects/worldcup
git add Fixture2026App/Components/StatisticsView.swift Fixture2026App/Components/LineupsView.swift \
        Fixture2026App/Views/MatchDetail/MatchDetailView.swift Fixture2026App/Models/MatchLineup.swift \
        Fixture2026App/Resources/Localizable.xcstrings
git commit -m "$(cat <<'EOF'
Port the statistics and lineups views from BR2026

Both are ports rather than rewrites, so they can be diffed against the
originals. The only substitutions are theme tokens for literal white,
TeamBadge for TeamCrestBadge, and this app's string-catalog keys.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Verify both apps in the simulator

Tasks 3–6 are Views with no unit tests. This is where they get checked.

**Files:** none, unless something reads wrong.

- [ ] **Step 1: Check BR2026**

Build and run the `BR2026` scheme on iPhone 17. Confirm:
- Fixtures shows section headers, and a round with mixed statuses splits correctly.
- The upcoming header reads `LATER TODAY` for a single-day round and `UPCOMING` for one spanning days.
- Matchday is visually unchanged from before Task 2.
- A finished match with an assisted goal shows `Assist: <name>` under the scorer in match detail.

- [ ] **Step 2: Check Fixture 2026**

Build and run the `Fixture2026` scheme on iPhone 17 Pro, on a **league** competition (not the World Cup — `LeagueTodayContent` is the changed path). Confirm:
- Today shows `FINISHED` / `ALSO TODAY` headers.
- Match cards match BR2026's proportions — hold the two simulators side by side.
- Match detail has three segments, and Stats/Lineups either populate or show their empty states.

- [ ] **Step 3: Report**

State which screens were checked and on which competition. Do not claim a screen was verified that was not reachable — say so instead.

---

## Notes for the implementer

**Why this is a hand-copy and not a shared file.** The repo has a byte-identical sharing mechanism (`scripts/sync-crests.sh`) for two crest files. It cannot be used here: BR2026 reads `match.homeScore` where Fixture 2026 reads `match.score.fullTime.home`, their status enums differ (`.halftime` vs `.paused`, and Fixture 2026's `.live(minute)` carries an associated value), and their event types differ (flat enum plus `detail: String` vs associated values). Unifying the two `Match` models is the agreed future direction and is out of scope here.

**Direction of copy is not uniform.** Tasks 3–6 copy BR2026 → Fixture 2026. Task 2 copies Fixture 2026 → BR2026. Task 1 fixes a BR2026 bug using Fixture 2026's behaviour as the reference. Do not "fix" BR2026's appearance to match Fixture 2026 anywhere.

**Differences that are deliberate and must survive.** In Fixture 2026: loser dimming on finished knockout matches, the `GROUP A · VENUE` header prefix, and the `FT · PEN` penalty suffix. In BR2026: every colour going through `themeTokens`.
