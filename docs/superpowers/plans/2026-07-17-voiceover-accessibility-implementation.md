# VoiceOver Accessibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every screen (all 4 tabs, Match Detail, the App Icon/Team Theme pickers, Terms of
Service) is fully navigable and understandable via VoiceOver, with live score-change
announcements and durable regression protection via unit tests + automated
`performAccessibilityAudit()` UI tests.

**Architecture:** Accessibility label/announcement text lives as computed properties on the
Models (`Match`, `Standing`, `MatchEvent`) — pure, testable, localized functions of existing
stored data. Views combine each card/row into one VoiceOver stop using these labels and hide
decorative sub-elements. A live-announcement mechanism compares old vs. new match data on
every refresh (poll, pull-to-refresh, foreground return) and posts a
`UIAccessibility` announcement for score/status changes.

**Tech Stack:** SwiftUI accessibility modifiers, `String(localized:)`, `NumberFormatter`
(`.ordinal`), `UIAccessibility.post`, XCTest `performAccessibilityAudit()`.

## Global Constraints

- Scope: whole app (Matchday, Fixtures, Standings, More, Match Detail, App Icon picker, Team
  Theme picker, Terms of Service). Dynamic Type, contrast, and reduced motion are explicitly
  out of scope for this phase.
- Every new user-facing string goes through `String(localized:)`, with translations for all 6
  supported locales (`en`, `en-GB`, `fr`, `pt-BR`, `pt-PT`, `es`) added directly to
  `BR2026/Resources/Localizable.xcstrings` — this project's Xcode auto-extraction is not
  reliable (confirmed this session), so every task that adds a string adds its catalog entry
  by hand, in the same step.
- **Format-specifier safety (hard rule, learned from a real bug fixed this session — see
  `docs/superpowers/plans/2026-07-16-...` history and the project's
  `project-localization-key-mismatch-gotcha` memory):** `LocalizedStringKey`/
  `String.LocalizationValue` interpolation generates a *type-dependent* format specifier —
  `Int` produces `%lld`, `String` produces `%@`. A hand-authored catalog entry with the wrong
  specifier silently never matches and falls back to unlocalized English forever, with no
  compiler error. Every task in this plan therefore **pre-converts every interpolated value to
  a `String` in a local `let` before calling `String(localized:)`**, so every catalog entry in
  this plan uses only `%@`-family specifiers — never `%lld`. Follow this pattern exactly; do
  not interpolate a raw `Int` directly.
- New Swift files must be registered in `BR2026.xcodeproj/project.pbxproj` in the same step
  that creates them (via the `xcodeproj` Ruby gem, matching the pattern in this repo's own
  history — see Task 1's Step 3 for the exact script). A prior task in this project's history
  skipped this and went undetected for 5 tasks because stale DerivedData silently kept
  working; every build-verification step in this plan uses a **fully clean build** (`rm -rf`
  DerivedData first, or `xcodebuild clean build`) to prevent a repeat.
- Unit test Models/ViewModels/Services, not Views (project convention). View-wiring tasks are
  verified via build + the automated audit tests (Task 11), not Swift Testing.
- No `UIKit` unless SwiftUI has no equivalent — `UIAccessibility.post` is the one necessary
  exception (SwiftUI has no equivalent API for posting ad hoc announcements).

---

## Localization catalog editing convention (used by every task below)

Every task that adds strings runs a Python script following this exact shape (matching the
pattern already used successfully in this repo's history to hand-edit
`Localizable.xcstrings`). Each task gives the literal `ENTRIES` dict to paste in — copy it
exactly, do not paraphrase the translations.

```python
import json

with open("BR2026/Resources/Localizable.xcstrings") as f:
    data = json.load(f)

ENTRIES = {
    # filled in per-task
}

for key, translations in ENTRIES.items():
    data["strings"][key] = {
        "extractionState": "manual",
        "localizations": {
            locale: {"stringUnit": {"state": "translated", "value": value}}
            for locale, value in translations.items()
        }
    }

with open("BR2026/Resources/Localizable.xcstrings", "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False, sort_keys=False)
    f.write("\n")
```

**Note on JSON formatting:** the project's `.xcstrings` files use 2-space indent with a space
before each colon (Xcode's own serializer style, e.g. `"key" : "value"`), while Python's
`json.dump` produces `"key": "value"` (no space before colon). This is a cosmetic difference
only — valid JSON either way, and Xcode re-normalizes the file the next time it's opened and
saved in the IDE. Do not hand-edit the file to "fix" the spacing; it is not a defect.

---

### Task 1: `Match.accessibilityLabel`

**Files:**
- Modify: `BR2026/Models/Match.swift`
- Modify: `BR2026Tests/Models/MatchTests.swift`
- Modify: `BR2026/Resources/Localizable.xcstrings`

**Interfaces:**
- Produces: `Match.accessibilityLabel: String` — Task 6/8 (View wiring) and Task 5 (live
  announcements, indirectly) consume this.

- [ ] **Step 1: Write the failing tests**

Add to `BR2026Tests/Models/MatchTests.swift`, inside the existing `@Suite("Match model") struct
MatchTests` (after the existing tests, before the closing `}`):

```swift
    @Test("accessibilityLabel for a scheduled match")
    func accessibilityLabelScheduled() throws {
        let team1 = Team(id: 1, name: "Flamengo", shortName: "Flamengo", crestURL: nil)
        let team2 = Team(id: 2, name: "Palmeiras", shortName: "Palmeiras", crestURL: nil)
        let match = Match(
            id: 1, utcDate: Date(timeIntervalSince1970: 1_700_000_000), status: .scheduled,
            matchday: 1, stage: "REGULAR_SEASON", homeTeam: team1, awayTeam: team2,
            homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        #expect(match.accessibilityLabel.contains("Flamengo"))
        #expect(match.accessibilityLabel.contains("Palmeiras"))
    }

    @Test("accessibilityLabel for a live match includes the score and minute")
    func accessibilityLabelLive() throws {
        let team1 = Team(id: 1, name: "Flamengo", shortName: "Flamengo", crestURL: nil)
        let team2 = Team(id: 2, name: "Palmeiras", shortName: "Palmeiras", crestURL: nil)
        let match = Match(
            id: 1, utcDate: Date(), status: .live, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team1, awayTeam: team2, homeScore: 2, awayScore: 1, winner: nil,
            venue: nil, minute: 67
        )
        let label = match.accessibilityLabel
        #expect(label.contains("2"))
        #expect(label.contains("1"))
        #expect(label.contains("67"))
    }

    @Test("accessibilityLabel for a finished match")
    func accessibilityLabelFinished() throws {
        let team1 = Team(id: 1, name: "Flamengo", shortName: "Flamengo", crestURL: nil)
        let team2 = Team(id: 2, name: "Palmeiras", shortName: "Palmeiras", crestURL: nil)
        let match = Match(
            id: 1, utcDate: Date(), status: .finished, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team1, awayTeam: team2, homeScore: 3, awayScore: 0, winner: "HOME_TEAM",
            venue: nil, minute: 90
        )
        let label = match.accessibilityLabel
        #expect(label.contains("3"))
        #expect(label.contains("0"))
    }

    @Test("accessibilityLabel for a postponed match")
    func accessibilityLabelPostponed() throws {
        let team1 = Team(id: 1, name: "Flamengo", shortName: "Flamengo", crestURL: nil)
        let team2 = Team(id: 2, name: "Palmeiras", shortName: "Palmeiras", crestURL: nil)
        let match = Match(
            id: 1, utcDate: Date(), status: .postponed, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team1, awayTeam: team2, homeScore: nil, awayScore: nil, winner: nil,
            venue: nil, minute: nil
        )
        #expect(match.accessibilityLabel.contains("Flamengo"))
        #expect(match.accessibilityLabel.contains("Palmeiras"))
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: FAIL to build — `Value of type 'Match' has no member 'accessibilityLabel'`.

- [ ] **Step 3: Write the implementation**

Add to `BR2026/Models/Match.swift`, inside the `Match` class (after `func update(from:)`, before
the closing `}`):

```swift
    var accessibilityLabel: String {
        let home = homeTeam.displayName
        let away = awayTeam.displayName
        switch status {
        case .scheduled:
            let time = utcDate.formatted(date: .omitted, time: .shortened)
            return String(
                localized: "\(home) versus \(away), kicks off at \(time)",
                comment: "VoiceOver label for a scheduled match card. Arguments: home team name, away team name, formatted kickoff time."
            )
        case .postponed:
            return String(
                localized: "\(home) versus \(away), postponed",
                comment: "VoiceOver label for a postponed match card. Arguments: home team name, away team name."
            )
        case .live:
            guard let home_score = homeScore, let away_score = awayScore else {
                return String(
                    localized: "\(home) versus \(away), live",
                    comment: "VoiceOver label for a live match card with no score yet available. Arguments: home team name, away team name."
                )
            }
            let minuteText = minute.map { String($0) } ?? ""
            return String(
                localized: "\(home) \(home_score), \(away) \(away_score), live, \(minuteText) minute",
                comment: "VoiceOver label for a live match card. Arguments: home team name, home score, away team name, away score, current minute."
            )
        case .finished:
            guard let home_score = homeScore, let away_score = awayScore else {
                return String(
                    localized: "\(home) versus \(away), final score",
                    comment: "VoiceOver label for a finished match card with no score available. Arguments: home team name, away team name."
                )
            }
            return String(
                localized: "\(home) \(home_score), \(away) \(away_score), final score",
                comment: "VoiceOver label for a finished match card. Arguments: home team name, home score, away team name, away score."
            )
        }
    }
```

- [ ] **Step 4: Add the catalog entries**

Run this Python script from the repo root (`eval "$(rbenv init -)" && python3 -c "$(cat <<'PYEOF'
...
PYEOF
)"` or save to a temp file and run it — either way, use exactly this `ENTRIES` dict):

```python
import json

with open("BR2026/Resources/Localizable.xcstrings") as f:
    data = json.load(f)

ENTRIES = {
    "⁠%1$@⁠ versus ⁠%2$@⁠, kicks off at ⁠%3$@⁠": {
        "en": "%1$@ versus %2$@, kicks off at %3$@",
        "en-GB": "%1$@ versus %2$@, kicks off at %3$@",
        "fr": "%1$@ contre %2$@, coup d’envoi à %3$@",
        "pt-BR": "%1$@ contra %2$@, começa às %3$@",
        "pt-PT": "%1$@ contra %2$@, começa às %3$@",
        "es": "%1$@ contra %2$@, comienza a las %3$@"
    },
    "%1$@ versus %2$@, postponed": {
        "en": "%1$@ versus %2$@, postponed",
        "en-GB": "%1$@ versus %2$@, postponed",
        "fr": "%1$@ contre %2$@, reporté",
        "pt-BR": "%1$@ contra %2$@, adiado",
        "pt-PT": "%1$@ contra %2$@, adiado",
        "es": "%1$@ contra %2$@, aplazado"
    },
    "%1$@ versus %2$@, live": {
        "en": "%1$@ versus %2$@, live",
        "en-GB": "%1$@ versus %2$@, live",
        "fr": "%1$@ contre %2$@, en direct",
        "pt-BR": "%1$@ contra %2$@, ao vivo",
        "pt-PT": "%1$@ contra %2$@, em direto",
        "es": "%1$@ contra %2$@, en vivo"
    },
    "%1$@ %2$@, %3$@ %4$@, live, %5$@ minute": {
        "en": "%1$@ %2$@, %3$@ %4$@, live, %5$@ minute",
        "en-GB": "%1$@ %2$@, %3$@ %4$@, live, %5$@ minute",
        "fr": "%1$@ %2$@, %3$@ %4$@, en direct, %5$@e minute",
        "pt-BR": "%1$@ %2$@, %3$@ %4$@, ao vivo, %5$@ minutos",
        "pt-PT": "%1$@ %2$@, %3$@ %4$@, em direto, %5$@ minutos",
        "es": "%1$@ %2$@, %3$@ %4$@, en vivo, minuto %5$@"
    },
    "%1$@ versus %2$@, final score": {
        "en": "%1$@ versus %2$@, final score",
        "en-GB": "%1$@ versus %2$@, final score",
        "fr": "%1$@ contre %2$@, score final",
        "pt-BR": "%1$@ contra %2$@, resultado final",
        "pt-PT": "%1$@ contra %2$@, resultado final",
        "es": "%1$@ contra %2$@, resultado final"
    },
    "%1$@ %2$@, %3$@ %4$@, final score": {
        "en": "%1$@ %2$@, %3$@ %4$@, final score",
        "en-GB": "%1$@ %2$@, %3$@ %4$@, final score",
        "fr": "%1$@ %2$@, %3$@ %4$@, score final",
        "pt-BR": "%1$@ %2$@, %3$@ %4$@, resultado final",
        "pt-PT": "%1$@ %2$@, %3$@ %4$@, resultado final",
        "es": "%1$@ %2$@, %3$@ %4$@, resultado final"
    }
}

for key, translations in ENTRIES.items():
    data["strings"][key] = {
        "extractionState": "manual",
        "localizations": {
            locale: {"stringUnit": {"state": "translated", "value": value}}
            for locale, value in translations.items()
        }
    }

with open("BR2026/Resources/Localizable.xcstrings", "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False, sort_keys=False)
    f.write("\n")
```

**Important:** the first key above contains word-joiner characters (`⁠`) around each
placeholder — **this is a mistake in this draft, remove them**: the actual key must be exactly
`"%1$@ versus %2$@, kicks off at %3$@"` (this is what `String(localized:)` will actually
generate for that interpolation — verify by reflection if unsure, the same way the project's
earlier `MatchStatus`/`Round`/`Half-time` bugs were diagnosed and fixed). Do not paste the
`⁠` version.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `rm -rf ~/Library/Developer/Xcode/DerivedData/BR2026-* && eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: all tests pass, including the 4 new ones.

- [ ] **Step 6: Commit**

```bash
git add BR2026/Models/Match.swift BR2026Tests/Models/MatchTests.swift BR2026/Resources/Localizable.xcstrings
git commit -m "Add Match.accessibilityLabel for VoiceOver"
```

---

### Task 2: `Match.accessibilityAnnouncement(comparedTo:)`

**Files:**
- Modify: `BR2026/Models/Match.swift`
- Modify: `BR2026Tests/Models/MatchTests.swift`
- Modify: `BR2026/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: nothing new (pure function of two `Match` instances' stored properties).
- Produces: `Match.accessibilityAnnouncement(comparedTo previous: Match) -> String?` — Task 5
  (live announcements in ViewModels) consumes this.

- [ ] **Step 1: Write the failing tests**

Add to `BR2026Tests/Models/MatchTests.swift`, inside `MatchStatusTests`... no — inside
`@Suite("Match model") struct MatchTests`, after the tests added in Task 1:

```swift
    @Test("accessibilityAnnouncement returns nil when nothing meaningful changed")
    func accessibilityAnnouncementNilWhenUnchanged() throws {
        let team1 = Team(id: 1, name: "Flamengo", shortName: "Flamengo", crestURL: nil)
        let team2 = Team(id: 2, name: "Palmeiras", shortName: "Palmeiras", crestURL: nil)
        let previous = Match(
            id: 1, utcDate: Date(), status: .live, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team1, awayTeam: team2, homeScore: 1, awayScore: 0, winner: nil,
            venue: nil, minute: 40
        )
        let current = Match(
            id: 1, utcDate: Date(), status: .live, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team1, awayTeam: team2, homeScore: 1, awayScore: 0, winner: nil,
            venue: nil, minute: 41
        )
        #expect(current.accessibilityAnnouncement(comparedTo: previous) == nil)
    }

    @Test("accessibilityAnnouncement announces a home goal")
    func accessibilityAnnouncementHomeGoal() throws {
        let team1 = Team(id: 1, name: "Flamengo", shortName: "Flamengo", crestURL: nil)
        let team2 = Team(id: 2, name: "Palmeiras", shortName: "Palmeiras", crestURL: nil)
        let previous = Match(
            id: 1, utcDate: Date(), status: .live, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team1, awayTeam: team2, homeScore: 0, awayScore: 0, winner: nil,
            venue: nil, minute: 40
        )
        let current = Match(
            id: 1, utcDate: Date(), status: .live, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team1, awayTeam: team2, homeScore: 1, awayScore: 0, winner: nil,
            venue: nil, minute: 41
        )
        let announcement = try #require(current.accessibilityAnnouncement(comparedTo: previous))
        #expect(announcement.contains("Flamengo"))
    }

    @Test("accessibilityAnnouncement announces a status transition to live")
    func accessibilityAnnouncementKickoff() throws {
        let team1 = Team(id: 1, name: "Flamengo", shortName: "Flamengo", crestURL: nil)
        let team2 = Team(id: 2, name: "Palmeiras", shortName: "Palmeiras", crestURL: nil)
        let previous = Match(
            id: 1, utcDate: Date(), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team1, awayTeam: team2, homeScore: nil, awayScore: nil, winner: nil,
            venue: nil, minute: nil
        )
        let current = Match(
            id: 1, utcDate: Date(), status: .live, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team1, awayTeam: team2, homeScore: 0, awayScore: 0, winner: nil,
            venue: nil, minute: 1
        )
        let announcement = try #require(current.accessibilityAnnouncement(comparedTo: previous))
        #expect(announcement.contains("Flamengo"))
    }

    @Test("accessibilityAnnouncement announces the final whistle")
    func accessibilityAnnouncementFullTime() throws {
        let team1 = Team(id: 1, name: "Flamengo", shortName: "Flamengo", crestURL: nil)
        let team2 = Team(id: 2, name: "Palmeiras", shortName: "Palmeiras", crestURL: nil)
        let previous = Match(
            id: 1, utcDate: Date(), status: .live, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team1, awayTeam: team2, homeScore: 2, awayScore: 1, winner: nil,
            venue: nil, minute: 90
        )
        let current = Match(
            id: 1, utcDate: Date(), status: .finished, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team1, awayTeam: team2, homeScore: 2, awayScore: 1, winner: "HOME_TEAM",
            venue: nil, minute: 90
        )
        let announcement = try #require(current.accessibilityAnnouncement(comparedTo: previous))
        #expect(announcement.contains("Flamengo"))
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: FAIL to build — `Value of type 'Match' has no member 'accessibilityAnnouncement'`.

- [ ] **Step 3: Write the implementation**

Add to `BR2026/Models/Match.swift`, directly after the `accessibilityLabel` property added in
Task 1:

```swift
    func accessibilityAnnouncement(comparedTo previous: Match) -> String? {
        if status != previous.status {
            switch status {
            case .live:
                return String(
                    localized: "\(homeTeam.displayName) versus \(awayTeam.displayName) has kicked off",
                    comment: "VoiceOver announcement when a match transitions from scheduled to live. Arguments: home team name, away team name."
                )
            case .finished:
                return String(
                    localized: "Full time: \(accessibilityLabel)",
                    comment: "VoiceOver announcement when a match finishes. Argument: the match's own full accessibility label (score included)."
                )
            case .scheduled, .postponed:
                return nil
            }
        }
        if status == .live, homeScore != previous.homeScore || awayScore != previous.awayScore {
            let scorer = (homeScore ?? 0) > (previous.homeScore ?? 0) ? homeTeam.displayName : awayTeam.displayName
            return String(
                localized: "Goal! \(scorer). \(accessibilityLabel)",
                comment: "VoiceOver announcement when a live match's score changes. Arguments: the scoring team's name, the match's own full accessibility label."
            )
        }
        return nil
    }
```

- [ ] **Step 4: Add the catalog entries**

```python
import json

with open("BR2026/Resources/Localizable.xcstrings") as f:
    data = json.load(f)

ENTRIES = {
    "%1$@ versus %2$@ has kicked off": {
        "en": "%1$@ versus %2$@ has kicked off",
        "en-GB": "%1$@ versus %2$@ has kicked off",
        "fr": "Le match %1$@ contre %2$@ a commencé",
        "pt-BR": "%1$@ contra %2$@ começou",
        "pt-PT": "%1$@ contra %2$@ começou",
        "es": "%1$@ contra %2$@ ha comenzado"
    },
    "Full time: %1$@": {
        "en": "Full time: %1$@",
        "en-GB": "Full time: %1$@",
        "fr": "Fin du match : %1$@",
        "pt-BR": "Fim de jogo: %1$@",
        "pt-PT": "Fim de jogo: %1$@",
        "es": "Final del partido: %1$@"
    },
    "Goal! %1$@. %2$@": {
        "en": "Goal! %1$@. %2$@",
        "en-GB": "Goal! %1$@. %2$@",
        "fr": "But ! %1$@. %2$@",
        "pt-BR": "Gol! %1$@. %2$@",
        "pt-PT": "Golo! %1$@. %2$@",
        "es": "¡Gol! %1$@. %2$@"
    }
}

for key, translations in ENTRIES.items():
    data["strings"][key] = {
        "extractionState": "manual",
        "localizations": {
            locale: {"stringUnit": {"state": "translated", "value": value}}
            for locale, value in translations.items()
        }
    }

with open("BR2026/Resources/Localizable.xcstrings", "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False, sort_keys=False)
    f.write("\n")
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `rm -rf ~/Library/Developer/Xcode/DerivedData/BR2026-* && eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: all tests pass, including the 4 new ones.

- [ ] **Step 6: Commit**

```bash
git add BR2026/Models/Match.swift BR2026Tests/Models/MatchTests.swift BR2026/Resources/Localizable.xcstrings
git commit -m "Add Match.accessibilityAnnouncement(comparedTo:) for live score changes"
```

---

### Task 3: `Standing.accessibilityLabel`

**Files:**
- Modify: `BR2026/Models/Standing.swift`
- Modify: `BR2026Tests/Models/StandingTests.swift`
- Modify: `BR2026/Resources/Localizable.xcstrings`

**Interfaces:**
- Produces: `Standing.accessibilityLabel: String` — Task 7 (Standings View wiring) consumes
  this.

- [ ] **Step 1: Write the failing tests**

Add to `BR2026Tests/Models/StandingTests.swift`, inside `@Suite("Standing decoding") struct
StandingTests`, after the existing test:

```swift
    @Test("accessibilityLabel spells out every column")
    func accessibilityLabel() throws {
        let team = Team(id: 121, name: "Palmeiras", shortName: "Palmeiras", crestURL: nil)
        let standing = Standing(
            position: 3, team: team, playedGames: 10, won: 7, draw: 2, lost: 1,
            goalsFor: 20, goalsAgainst: 5, goalDifference: 15, points: 23
        )
        let label = standing.accessibilityLabel
        #expect(label.contains("Palmeiras"))
        #expect(label.contains("10"))
        #expect(label.contains("7"))
        #expect(label.contains("23"))
    }

    @Test("accessibilityLabel spells out a negative goal difference")
    func accessibilityLabelNegativeGoalDifference() throws {
        let team = Team(id: 121, name: "Palmeiras", shortName: "Palmeiras", crestURL: nil)
        let standing = Standing(
            position: 18, team: team, playedGames: 10, won: 1, draw: 2, lost: 7,
            goalsFor: 5, goalsAgainst: 20, goalDifference: -15, points: 5
        )
        #expect(standing.accessibilityLabel.contains("15"))
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: FAIL to build — `Value of type 'Standing' has no member 'accessibilityLabel'`.

- [ ] **Step 3: Write the implementation**

Add to `BR2026/Models/Standing.swift`, inside the `Standing` class (after the `convenience
init(dto:)`, before the closing `}`):

```swift
    private static let ordinalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter
    }()

    var accessibilityLabel: String {
        let positionText = Self.ordinalFormatter.string(from: NSNumber(value: position)) ?? String(position)
        let goalDifferenceText: String
        if goalDifference > 0 {
            let plusWord = String(localized: "plus", comment: "VoiceOver: prefix spoken before a positive goal difference, e.g. \"plus 15\".")
            goalDifferenceText = "\(plusWord) \(goalDifference)"
        } else if goalDifference < 0 {
            let minusWord = String(localized: "minus", comment: "VoiceOver: prefix spoken before a negative goal difference, e.g. \"minus 4\".")
            goalDifferenceText = "\(minusWord) \(abs(goalDifference))"
        } else {
            goalDifferenceText = String(goalDifference)
        }
        return String(
            localized: "\(positionText) place, \(team.displayName), \(playedGames) played, \(won) won, \(draw) drawn, \(lost) lost, goal difference \(goalDifferenceText), \(points) points",
            comment: "VoiceOver label for one standings table row. Arguments: ordinal position, team name, games played, wins, draws, losses, goal difference (already spelled out with plus/minus), points."
        )
    }
```

- [ ] **Step 4: Add the catalog entries**

```python
import json

with open("BR2026/Resources/Localizable.xcstrings") as f:
    data = json.load(f)

ENTRIES = {
    "plus": {
        "en": "plus",
        "en-GB": "plus",
        "fr": "plus",
        "pt-BR": "mais",
        "pt-PT": "mais",
        "es": "más"
    },
    "minus": {
        "en": "minus",
        "en-GB": "minus",
        "fr": "moins",
        "pt-BR": "menos",
        "pt-PT": "menos",
        "es": "menos"
    },
    "%1$@ place, %2$@, %3$@ played, %4$@ won, %5$@ drawn, %6$@ lost, goal difference %7$@, %8$@ points": {
        "en": "%1$@ place, %2$@, %3$@ played, %4$@ won, %5$@ drawn, %6$@ lost, goal difference %7$@, %8$@ points",
        "en-GB": "%1$@ place, %2$@, %3$@ played, %4$@ won, %5$@ drawn, %6$@ lost, goal difference %7$@, %8$@ points",
        "fr": "%1$@ place, %2$@, %3$@ joués, %4$@ gagnés, %5$@ nuls, %6$@ perdus, différence de buts %7$@, %8$@ points",
        "pt-BR": "%1$@ lugar, %2$@, %3$@ jogos, %4$@ vitórias, %5$@ empates, %6$@ derrotas, saldo de gols %7$@, %8$@ pontos",
        "pt-PT": "%1$@ lugar, %2$@, %3$@ jogos, %4$@ vitórias, %5$@ empates, %6$@ derrotas, saldo de golos %7$@, %8$@ pontos",
        "es": "%1$@ lugar, %2$@, %3$@ jugados, %4$@ ganados, %5$@ empatados, %6$@ perdidos, diferencia de goles %7$@, %8$@ puntos"
    }
}

for key, translations in ENTRIES.items():
    data["strings"][key] = {
        "extractionState": "manual",
        "localizations": {
            locale: {"stringUnit": {"state": "translated", "value": value}}
            for locale, value in translations.items()
        }
    }

with open("BR2026/Resources/Localizable.xcstrings", "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False, sort_keys=False)
    f.write("\n")
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `rm -rf ~/Library/Developer/Xcode/DerivedData/BR2026-* && eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: all tests pass, including the 2 new ones.

- [ ] **Step 6: Commit**

```bash
git add BR2026/Models/Standing.swift BR2026Tests/Models/StandingTests.swift BR2026/Resources/Localizable.xcstrings
git commit -m "Add Standing.accessibilityLabel for VoiceOver"
```

---

### Task 4: `MatchEvent.accessibilityLabel`

**Files:**
- Modify: `BR2026/Models/MatchEvent.swift`
- Create: `BR2026Tests/Models/MatchEventTests.swift`
- Modify: `BR2026/Resources/Localizable.xcstrings`

**Interfaces:**
- Produces: `MatchEvent.accessibilityLabel: String` — Task 8 (Match Detail View wiring)
  consumes this.

- [ ] **Step 1: Write the failing tests**

```swift
// BR2026Tests/Models/MatchEventTests.swift
import Testing
import Foundation
@testable import BR2026

@Suite("MatchEvent")
struct MatchEventTests {
    @Test("accessibilityLabel for a normal goal")
    func accessibilityLabelGoal() {
        let event = MatchEvent(
            team: .home, type: .goal, assist: nil, detail: "Normal Goal", minute: 67,
            player: "Neymar", playerOut: nil, extraMinute: nil
        )
        let label = event.accessibilityLabel
        #expect(label.contains("67"))
        #expect(label.contains("Neymar"))
    }

    @Test("accessibilityLabel for a penalty goal")
    func accessibilityLabelPenalty() {
        let event = MatchEvent(
            team: .home, type: .goal, assist: nil, detail: "Penalty", minute: 45,
            player: "Neymar", playerOut: nil, extraMinute: 2
        )
        let label = event.accessibilityLabel
        #expect(label.contains("45"))
        #expect(label.contains("2"))
        #expect(label.contains("Neymar"))
    }

    @Test("accessibilityLabel for an own goal")
    func accessibilityLabelOwnGoal() {
        let event = MatchEvent(
            team: .away, type: .goal, assist: nil, detail: "Own Goal", minute: 30,
            player: "Defender Name", playerOut: nil, extraMinute: nil
        )
        #expect(event.accessibilityLabel.contains("Defender Name"))
    }

    @Test("accessibilityLabel for a yellow card")
    func accessibilityLabelYellowCard() {
        let event = MatchEvent(
            team: .home, type: .yellowCard, assist: nil, detail: "", minute: 23,
            player: "Casemiro", playerOut: nil, extraMinute: nil
        )
        let label = event.accessibilityLabel
        #expect(label.contains("23"))
        #expect(label.contains("Casemiro"))
    }

    @Test("accessibilityLabel for a red card")
    func accessibilityLabelRedCard() {
        let event = MatchEvent(
            team: .home, type: .redCard, assist: nil, detail: "", minute: 80,
            player: "Casemiro", playerOut: nil, extraMinute: nil
        )
        #expect(event.accessibilityLabel.contains("Casemiro"))
    }

    @Test("accessibilityLabel for a substitution")
    func accessibilityLabelSubstitution() {
        let event = MatchEvent(
            team: .home, type: .substitution, assist: nil, detail: "", minute: 75,
            player: "Player In", playerOut: "Player Out", extraMinute: nil
        )
        let label = event.accessibilityLabel
        #expect(label.contains("Player In"))
        #expect(label.contains("Player Out"))
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: FAIL to build — `Value of type 'MatchEvent' has no member 'accessibilityLabel'`.

- [ ] **Step 3: Write the implementation**

Add to `BR2026/Models/MatchEvent.swift`, inside the `MatchEvent` struct (after the `var id:
String` computed property, before the closing `}`):

```swift
    var accessibilityLabel: String {
        let minuteText = extraMinute.map { "\(minute)+\($0)" } ?? String(minute)
        let eventWord: String
        switch type {
        case .goal:
            switch detail {
            case "Penalty":
                eventWord = String(localized: "penalty goal", comment: "VoiceOver: match-event type word for a penalty goal.")
            case "Own Goal":
                eventWord = String(localized: "own goal", comment: "VoiceOver: match-event type word for an own goal.")
            default:
                eventWord = String(localized: "goal", comment: "VoiceOver: match-event type word for a standard goal.")
            }
        case .yellowCard:
            eventWord = String(localized: "yellow card", comment: "VoiceOver: match-event type word for a yellow card.")
        case .redCard:
            eventWord = String(localized: "red card", comment: "VoiceOver: match-event type word for a red card.")
        case .substitution:
            eventWord = String(localized: "substitution", comment: "VoiceOver: match-event type word for a substitution.")
        case .unknown:
            return String(
                localized: "\(minuteText) minute",
                comment: "VoiceOver label for a match event of an unrecognized type — only the minute is known. Argument: the minute (with stoppage time if any, e.g. \"45+2\")."
            )
        }
        let detailText: String
        if type == .substitution, let playerOut {
            detailText = String(
                localized: "\(player) for \(playerOut)",
                comment: "VoiceOver: describes a substitution as the incoming player for the outgoing player. Arguments: player coming on, player going off."
            )
        } else {
            detailText = player
        }
        return String(
            localized: "\(minuteText) minute, \(eventWord), \(detailText)",
            comment: "VoiceOver label for one match timeline event. Arguments: the minute, the event type word (goal/yellow card/etc.), and the player detail."
        )
    }
```

- [ ] **Step 4: Add the catalog entries**

```python
import json

with open("BR2026/Resources/Localizable.xcstrings") as f:
    data = json.load(f)

ENTRIES = {
    "penalty goal": {
        "en": "penalty goal", "en-GB": "penalty goal", "fr": "but sur penalty",
        "pt-BR": "gol de pênalti", "pt-PT": "golo de grande penalidade",
        "es": "gol de penalti"
    },
    "own goal": {
        "en": "own goal", "en-GB": "own goal", "fr": "but contre son camp",
        "pt-BR": "gol contra", "pt-PT": "autogolo", "es": "autogol"
    },
    "goal": {
        "en": "goal", "en-GB": "goal", "fr": "but", "pt-BR": "gol", "pt-PT": "golo",
        "es": "gol"
    },
    "yellow card": {
        "en": "yellow card", "en-GB": "yellow card", "fr": "carton jaune",
        "pt-BR": "cartão amarelo", "pt-PT": "cartão amarelo",
        "es": "tarjeta amarilla"
    },
    "red card": {
        "en": "red card", "en-GB": "red card", "fr": "carton rouge",
        "pt-BR": "cartão vermelho", "pt-PT": "cartão vermelho",
        "es": "tarjeta roja"
    },
    "substitution": {
        "en": "substitution", "en-GB": "substitution", "fr": "remplacement",
        "pt-BR": "substituição", "pt-PT": "substituição",
        "es": "sustitución"
    },
    "%1$@ for %2$@": {
        "en": "%1$@ for %2$@", "en-GB": "%1$@ for %2$@", "fr": "%1$@ à la place de %2$@",
        "pt-BR": "%1$@ no lugar de %2$@", "pt-PT": "%1$@ no lugar de %2$@",
        "es": "%1$@ por %2$@"
    },
    "%1$@ minute": {
        "en": "%1$@ minute", "en-GB": "%1$@ minute", "fr": "%1$@e minute",
        "pt-BR": "%1$@ minutos", "pt-PT": "%1$@ minutos", "es": "minuto %1$@"
    },
    "%1$@ minute, %2$@, %3$@": {
        "en": "%1$@ minute, %2$@, %3$@", "en-GB": "%1$@ minute, %2$@, %3$@",
        "fr": "%1$@e minute, %2$@, %3$@", "pt-BR": "%1$@ minutos, %2$@, %3$@",
        "pt-PT": "%1$@ minutos, %2$@, %3$@", "es": "minuto %1$@, %2$@, %3$@"
    }
}

for key, translations in ENTRIES.items():
    data["strings"][key] = {
        "extractionState": "manual",
        "localizations": {
            locale: {"stringUnit": {"state": "translated", "value": value}}
            for locale, value in translations.items()
        }
    }

with open("BR2026/Resources/Localizable.xcstrings", "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False, sort_keys=False)
    f.write("\n")
```

- [ ] **Step 5: Register the new test file in the Xcode project**

`MatchEventTests.swift` is a brand-new file — it must be added to `project.pbxproj`'s
`BR2026Tests/Models` group and the `BR2026Tests` target's Sources build phase, in this same
step (see Global Constraints — this is exactly the mistake that went undetected for 5 tasks
in this project's history):

```bash
eval "$(rbenv init -)"
bundle exec ruby -e '
require "xcodeproj"
project = Xcodeproj::Project.open("BR2026.xcodeproj")
group = project.main_group.find_subpath("BR2026Tests/Models", false)
raise "group not found" unless group
file_ref = group.new_reference("MatchEventTests.swift")
target = project.targets.find { |t| t.name == "BR2026Tests" } or raise "no BR2026Tests target"
target.source_build_phase.add_file_reference(file_ref)
project.save
puts "Registered MatchEventTests.swift"
'
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `rm -rf ~/Library/Developer/Xcode/DerivedData/BR2026-* && eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: all tests pass, including the 6 new ones. Confirm with a **fully clean build**
first (not incremental) — this is the exact scenario that silently broke before.

- [ ] **Step 7: Commit**

```bash
git add BR2026/Models/MatchEvent.swift BR2026Tests/Models/MatchEventTests.swift BR2026/Resources/Localizable.xcstrings BR2026.xcodeproj/project.pbxproj
git commit -m "Add MatchEvent.accessibilityLabel for VoiceOver"
```

---

### Task 5: Wire live announcements into `MatchdayViewModel`/`FixturesViewModel`

**Files:**
- Modify: `BR2026/ViewModels/MatchdayViewModel.swift`
- Modify: `BR2026/ViewModels/FixturesViewModel.swift`

**Interfaces:**
- Consumes: `Match.accessibilityAnnouncement(comparedTo:)` from Task 2.
- Produces: no new public members — `load()`'s existing signature and behavior are unchanged
  from the caller's perspective; this task only adds an internal side effect.

This is a View-model-layer change with a real side effect (`UIAccessibility.post`) that isn't
itself unit-testable — the diffing logic it calls (`accessibilityAnnouncement`) is already
fully tested in Task 2. Per this project's convention, this task is verified by a clean build
plus a manual check, not a new automated test.

- [ ] **Step 1: Modify `MatchdayViewModel.load()`**

In `BR2026/ViewModels/MatchdayViewModel.swift`, find:

```swift
    func load() async {
        matches = service.cachedMatches()
        isRefreshing = true
        defer { isRefreshing = false }
        if let fresh = try? await service.fetchMatches() {
            matches = fresh
        }
    }
```

Replace with:

```swift
    func load() async {
        matches = service.cachedMatches()
        isRefreshing = true
        defer { isRefreshing = false }
        if let fresh = try? await service.fetchMatches() {
            announceChanges(from: matches, to: fresh)
            matches = fresh
        }
    }

    private func announceChanges(from old: [Match], to new: [Match]) {
        let oldByID = Dictionary(uniqueKeysWithValues: old.map { ($0.id, $0) })
        for match in new {
            guard let previous = oldByID[match.id],
                  let announcement = match.accessibilityAnnouncement(comparedTo: previous) else { continue }
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }
    }
```

Add `import UIKit` to the top of the file (needed for `UIAccessibility`) — the file currently
starts with `import Foundation` and `import Observation`; add `import UIKit` as a third
import.

- [ ] **Step 2: Modify `FixturesViewModel.load()`**

In `BR2026/ViewModels/FixturesViewModel.swift`, find:

```swift
    func load() async {
        matches = service.cachedMatches()
        selectRoundIfNeeded()
        isRefreshing = true
        defer { isRefreshing = false }
        if let fresh = try? await service.fetchMatches() {
            matches = fresh
            selectRoundIfNeeded()
        }
    }
```

Replace with:

```swift
    func load() async {
        matches = service.cachedMatches()
        selectRoundIfNeeded()
        isRefreshing = true
        defer { isRefreshing = false }
        if let fresh = try? await service.fetchMatches() {
            announceChanges(from: matches, to: fresh)
            matches = fresh
            selectRoundIfNeeded()
        }
    }

    private func announceChanges(from old: [Match], to new: [Match]) {
        let oldByID = Dictionary(uniqueKeysWithValues: old.map { ($0.id, $0) })
        for match in new {
            guard let previous = oldByID[match.id],
                  let announcement = match.accessibilityAnnouncement(comparedTo: previous) else { continue }
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }
    }
```

Add `import UIKit` to the top of the file, alongside the existing imports.

- [ ] **Step 3: Build to verify it compiles**

Run: `rm -rf ~/Library/Developer/Xcode/DerivedData/BR2026-* && xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation clean build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Run the full test suite**

Run: `eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: all existing tests still pass (no new tests in this task — the diffing logic is
already covered by Task 2's tests; this task only wires it to a side effect).

- [ ] **Step 5: Commit**

```bash
git add BR2026/ViewModels/MatchdayViewModel.swift BR2026/ViewModels/FixturesViewModel.swift
git commit -m "Wire live score-change VoiceOver announcements into Matchday/Fixtures load()"
```

---

### Task 6: Matchday & Fixtures View wiring

**Files:**
- Modify: `BR2026/Components/HeroMatchCard.swift`
- Modify: `BR2026/Components/FixtureMatchCard.swift`
- Modify: `BR2026/Components/TeamCrestBadge.swift`
- Modify: `BR2026/Components/LiveChip.swift`
- Modify: `BR2026/Components/RefreshPulseDot.swift`
- Modify: `BR2026/Views/Fixtures/FixturesView.swift`
- Modify: `BR2026/Views/Matchday/MatchdayView.swift`

**Interfaces:**
- Consumes: `Match.accessibilityLabel` from Task 1.

View-layer task — verified via build + Task 11's automated audit, not Swift Testing.

- [ ] **Step 1: `HeroMatchCard`**

In `BR2026/Components/HeroMatchCard.swift`, find the `body`:

```swift
    var body: some View {
        GlassCard(cornerRadius: 28, style: .transparent) {
            VStack(spacing: 20) {
                topInfo
                HStack(alignment: .center, spacing: 12) {
                    teamColumn(match.homeTeam)
                    centerContent
                        .frame(minWidth: 70)
                    teamColumn(match.awayTeam)
                }
                Text(venueLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(themeTokens.textColor.opacity(0.5))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(themeTokens.overrideTabSelectionColor ?? themeTokens.overrideAccentColor ?? .clear, lineWidth: 1.5)
        )
    }
```

Replace with:

```swift
    var body: some View {
        GlassCard(cornerRadius: 28, style: .transparent) {
            VStack(spacing: 20) {
                topInfo
                HStack(alignment: .center, spacing: 12) {
                    teamColumn(match.homeTeam)
                    centerContent
                        .frame(minWidth: 70)
                    teamColumn(match.awayTeam)
                }
                Text(venueLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(themeTokens.textColor.opacity(0.5))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(themeTokens.overrideTabSelectionColor ?? themeTokens.overrideAccentColor ?? .clear, lineWidth: 1.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(match.accessibilityLabel)
        .accessibilityHint(Text("Double tap to view match details", comment: "VoiceOver hint on a match card button."))
    }
```

- [ ] **Step 2: `FixtureMatchCard`**

In `BR2026/Components/FixtureMatchCard.swift`, find the `body`:

```swift
    var body: some View {
        GlassCard(cornerRadius: 22, style: .transparent) {
            VStack(spacing: 12) {
                header
                VStack(spacing: 0) {
                    teamRow(match.homeTeam, score: match.homeScore)
                    divider
                    teamRow(match.awayTeam, score: match.awayScore)
                }
            }
        }
    }
```

Replace with:

```swift
    var body: some View {
        GlassCard(cornerRadius: 22, style: .transparent) {
            VStack(spacing: 12) {
                header
                VStack(spacing: 0) {
                    teamRow(match.homeTeam, score: match.homeScore)
                    divider
                    teamRow(match.awayTeam, score: match.awayScore)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(match.accessibilityLabel)
        .accessibilityHint(Text("Double tap to view match details", comment: "VoiceOver hint on a match card button."))
    }
```

- [ ] **Step 3: `TeamCrestBadge`**

In `BR2026/Components/TeamCrestBadge.swift`, find:

```swift
    var body: some View {
        Group {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .task(id: team.crestURL) {
            await loadCrest()
        }
    }
```

Replace with:

```swift
    var body: some View {
        Group {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .task(id: team.crestURL) {
            await loadCrest()
        }
        .accessibilityHidden(true)
    }
```

- [ ] **Step 4: `LiveChip`**

In `BR2026/Components/LiveChip.swift`, find the closing of `body` (the `.onAppear` block at
the end):

```swift
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
```

Replace with:

```swift
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .accessibilityHidden(true)
    }
}
```

- [ ] **Step 5: `RefreshPulseDot`**

In `BR2026/Components/RefreshPulseDot.swift`, find:

```swift
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}
```

Replace with:

```swift
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
            .accessibilityHidden(true)
    }
}
```

- [ ] **Step 6: Fixtures' round picker pills and section headers**

In `BR2026/Views/Fixtures/FixturesView.swift`, find `roundPill`:

```swift
    private func roundPill(_ round: Int) -> some View {
        let isSelected = viewModel.selectedRound == round
        return Button {
            viewModel.selectedRound = round
        } label: {
            VStack(spacing: 2) {
                Text("Round")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.4)
                Text("\(round)")
                    .font(.system(size: 17, weight: .heavy))
                    .monospacedDigit()
            }
            .foregroundStyle(isSelected ? themeTokens.textColor : themeTokens.textColor.opacity(0.55))
            .frame(width: 60, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? (themeTokens.overridePillFillColor ?? themeTokens.overrideTabSelectionColor ?? Color.accentColor) : Color.white.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .id(round)
    }
```

Replace with:

```swift
    private func roundPill(_ round: Int) -> some View {
        let isSelected = viewModel.selectedRound == round
        return Button {
            viewModel.selectedRound = round
        } label: {
            VStack(spacing: 2) {
                Text("Round")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.4)
                Text("\(round)")
                    .font(.system(size: 17, weight: .heavy))
                    .monospacedDigit()
            }
            .foregroundStyle(isSelected ? themeTokens.textColor : themeTokens.textColor.opacity(0.55))
            .frame(width: 60, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? (themeTokens.overridePillFillColor ?? themeTokens.overrideTabSelectionColor ?? Color.accentColor) : Color.white.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .id(round)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Round \(round)", comment: "VoiceOver label for a round-picker pill. Argument: the round number."))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
```

- [ ] **Step 7: Matchday's section headers**

In `BR2026/Views/Matchday/MatchdayView.swift`, find `matchSection`:

```swift
    private func matchSection(title: Text, matches: [Match]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            title
                .font(.system(size: 13, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(themeTokens.textColor.opacity(0.5))
                .textCase(.uppercase)
```

Replace the `title` block with:

```swift
    private func matchSection(title: Text, matches: [Match]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            title
                .font(.system(size: 13, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(themeTokens.textColor.opacity(0.5))
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
```

- [ ] **Step 8: Add the "Round %@" catalog entry (if not already present)**

The key `"Round %1$@"` for the round-picker label already exists in the catalog from a prior
fix this session (`Round %lld` was the match-detail eyebrow; this new one is a distinct key
`"Round %1$@"` since it interpolates a pre-stringified value — check the catalog first):

```bash
python3 -c "
import json
with open('BR2026/Resources/Localizable.xcstrings') as f:
    data = json.load(f)
print('Round %1\$@' in data['strings'])
"
```

If it prints `False`, add it:

```python
import json

with open("BR2026/Resources/Localizable.xcstrings") as f:
    data = json.load(f)

ENTRIES = {
    "Round %1$@": {
        "en": "Round %1$@", "en-GB": "Round %1$@", "fr": "Journée %1$@",
        "pt-BR": "Rodada %1$@", "pt-PT": "Jornada %1$@", "es": "Ronda %1$@"
    }
}

for key, translations in ENTRIES.items():
    data["strings"][key] = {
        "extractionState": "manual",
        "localizations": {
            locale: {"stringUnit": {"state": "translated", "value": value}}
            for locale, value in translations.items()
        }
    }

with open("BR2026/Resources/Localizable.xcstrings", "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False, sort_keys=False)
    f.write("\n")
```

- [ ] **Step 9: Build to verify it compiles**

Run: `rm -rf ~/Library/Developer/Xcode/DerivedData/BR2026-* && xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation clean build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 10: Manual verification**

Install and launch `BR2026` on a simulator. Turn on VoiceOver (Settings → Accessibility →
VoiceOver, or `xcrun simctl` doesn't support toggling VoiceOver directly — use the
Accessibility Inspector app instead, targeting the running simulator, to inspect each element's
computed label). Confirm: swiping through Matchday's hero card reads one combined sentence
(not separate crest/name/score stops); Fixtures' round pills read "Round 19" (not "Round"
then "19" separately); the round pill correctly reports selected state.

- [ ] **Step 11: Commit**

```bash
git add BR2026/Components/HeroMatchCard.swift BR2026/Components/FixtureMatchCard.swift BR2026/Components/TeamCrestBadge.swift BR2026/Components/LiveChip.swift BR2026/Components/RefreshPulseDot.swift BR2026/Views/Fixtures/FixturesView.swift BR2026/Views/Matchday/MatchdayView.swift BR2026/Resources/Localizable.xcstrings
git commit -m "Wire VoiceOver support into Matchday and Fixtures"
```

---

### Task 7: Standings View wiring

**Files:**
- Modify: `BR2026/Views/Standings/StandingsView.swift`

**Interfaces:**
- Consumes: `Standing.accessibilityLabel` from Task 3. `TeamCrestBadge` is already
  `.accessibilityHidden(true)` from Task 6.

- [ ] **Step 1: Combine each row**

In `BR2026/Views/Standings/StandingsView.swift`, find `row(for:)`:

```swift
    private func row(for standing: Standing) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("\(standing.position)")
                    .lineLimit(1)
                    .frame(width: Self.positionWidth, alignment: .leading)
                TeamCrestBadge(team: standing.team, size: 20)
            }
            .frame(width: Self.leadingWidth, alignment: .leading)
            Text(standing.team.displayName)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            statCell("\(standing.playedGames)")
            statCell("\(standing.won)")
            statCell("\(standing.draw)")
            statCell("\(standing.lost)")
            statCell(signed(standing.goalDifference), width: Self.goalDifferenceWidth)
            statCell("\(standing.points)", emphasized: true)
        }
        .font(.system(size: 14, weight: .semibold))
        .monospacedDigit()
        .foregroundStyle(themeTokens.textColor)
        .padding(.vertical, 8)
    }
```

Replace with:

```swift
    private func row(for standing: Standing) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("\(standing.position)")
                    .lineLimit(1)
                    .frame(width: Self.positionWidth, alignment: .leading)
                TeamCrestBadge(team: standing.team, size: 20)
            }
            .frame(width: Self.leadingWidth, alignment: .leading)
            Text(standing.team.displayName)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            statCell("\(standing.playedGames)")
            statCell("\(standing.won)")
            statCell("\(standing.draw)")
            statCell("\(standing.lost)")
            statCell(signed(standing.goalDifference), width: Self.goalDifferenceWidth)
            statCell("\(standing.points)", emphasized: true)
        }
        .font(.system(size: 14, weight: .semibold))
        .monospacedDigit()
        .foregroundStyle(themeTokens.textColor)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(standing.accessibilityLabel)
    }
```

- [ ] **Step 2: Hide the header row**

Find `header`:

```swift
    private var header: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: Self.leadingWidth)
            Color.clear.frame(maxWidth: .infinity)
            columnHeader(String(localized: "P", comment: "Standings table column header: abbreviation for \"Played\" (games played). Keep as short as the other column headers in this table."))
            columnHeader(String(localized: "W", comment: "Standings table column header: abbreviation for \"Won\" (games won). Keep as short as the other column headers in this table."))
            columnHeader(String(localized: "D", comment: "Standings table column header: abbreviation for \"Drawn\" (games drawn). Keep as short as the other column headers in this table."))
            columnHeader(String(localized: "L", comment: "Standings table column header: abbreviation for \"Lost\" (games lost). Keep as short as the other column headers in this table."))
            columnHeader(String(localized: "GD", comment: "Standings table column header: abbreviation for \"Goal Difference\". Keep as short as the other column headers in this table."), width: Self.goalDifferenceWidth)
            columnHeader(String(localized: "Pts", comment: "Standings table column header: abbreviation for \"Points\". Keep as short as the other column headers in this table."))
        }
        .padding(.bottom, 8)
    }
```

Replace the closing with an added modifier — full replacement:

```swift
    private var header: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: Self.leadingWidth)
            Color.clear.frame(maxWidth: .infinity)
            columnHeader(String(localized: "P", comment: "Standings table column header: abbreviation for \"Played\" (games played). Keep as short as the other column headers in this table."))
            columnHeader(String(localized: "W", comment: "Standings table column header: abbreviation for \"Won\" (games won). Keep as short as the other column headers in this table."))
            columnHeader(String(localized: "D", comment: "Standings table column header: abbreviation for \"Drawn\" (games drawn). Keep as short as the other column headers in this table."))
            columnHeader(String(localized: "L", comment: "Standings table column header: abbreviation for \"Lost\" (games lost). Keep as short as the other column headers in this table."))
            columnHeader(String(localized: "GD", comment: "Standings table column header: abbreviation for \"Goal Difference\". Keep as short as the other column headers in this table."), width: Self.goalDifferenceWidth)
            columnHeader(String(localized: "Pts", comment: "Standings table column header: abbreviation for \"Points\". Keep as short as the other column headers in this table."))
        }
        .padding(.bottom, 8)
        .accessibilityHidden(true)
    }
```

- [ ] **Step 3: Build to verify it compiles**

Run: `rm -rf ~/Library/Developer/Xcode/DerivedData/BR2026-* && xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation clean build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Manual verification**

Using Accessibility Inspector against the running simulator, confirm a standings row reads as
one combined sentence (e.g. "3rd place, Flamengo, 10 played, ...") and the abbreviated
`P`/`W`/`D`/`L`/`GD`/`Pts` header row is skipped by VoiceOver navigation entirely.

- [ ] **Step 5: Commit**

```bash
git add BR2026/Views/Standings/StandingsView.swift
git commit -m "Wire VoiceOver support into Standings"
```

---

### Task 8: Match Detail View wiring

**Files:**
- Modify: `BR2026/Views/MatchDetail/MatchDetailView.swift`
- Modify: `BR2026/Components/MatchTimelineRow.swift`

**Interfaces:**
- Consumes: `Match.accessibilityLabel` from Task 1, `MatchEvent.accessibilityLabel` from
  Task 4.

- [ ] **Step 1: Combine the team/score/status block**

In `BR2026/Views/MatchDetail/MatchDetailView.swift`, find the `header` computed property's
`HStack` (the team columns + center score):

```swift
            HStack(alignment: .center, spacing: 16) {
                teamColumn(match.homeTeam, isDimmed: isHomeDimmed)
                centerScore
                    .frame(minWidth: 80)
                teamColumn(match.awayTeam, isDimmed: isAwayDimmed)
            }
```

Replace with:

```swift
            HStack(alignment: .center, spacing: 16) {
                teamColumn(match.homeTeam, isDimmed: isHomeDimmed)
                centerScore
                    .frame(minWidth: 80)
                teamColumn(match.awayTeam, isDimmed: isAwayDimmed)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(match.accessibilityLabel)
```

- [ ] **Step 2: Add a label to the venue row**

Find where the venue is rendered (look for the `(i)` info icon paired with a venue name — the
element containing `Image(systemName: "info.circle")` or similar, adjacent to
`Text(match.venue ...)` or an equivalent venue label — the exact surrounding code depends on
what's there; add `.accessibilityElement(children: .combine)` and
`.accessibilityLabel(String(localized: "Venue: \(venueName)", comment: "VoiceOver label for the match detail venue row. Argument: the venue name."))`
to that row's container, using whatever the actual venue string variable is called in this
file (read the file first — the plan's earlier design-phase read of this file found the row as
`Image(systemName: "info.circle") ... Text("Barradao")`-shaped, but confirm the exact current
code before editing, since this file may have changed since the design phase).

Add the catalog entry:

```python
import json

with open("BR2026/Resources/Localizable.xcstrings") as f:
    data = json.load(f)

ENTRIES = {
    "Venue: %1$@": {
        "en": "Venue: %1$@", "en-GB": "Venue: %1$@", "fr": "Stade : %1$@",
        "pt-BR": "Local: %1$@", "pt-PT": "Local: %1$@", "es": "Sede: %1$@"
    }
}

for key, translations in ENTRIES.items():
    data["strings"][key] = {
        "extractionState": "manual",
        "localizations": {
            locale: {"stringUnit": {"state": "translated", "value": value}}
            for locale, value in translations.items()
        }
    }

with open("BR2026/Resources/Localizable.xcstrings", "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False, sort_keys=False)
    f.write("\n")
```

- [ ] **Step 3: "Timeline" section header**

Find, in `timelineSection`:

```swift
            Text("Timeline")
                .font(.system(size: 13, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(themeTokens.textColor.opacity(0.5))
                .textCase(.uppercase)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
```

Replace with:

```swift
            Text("Timeline")
                .font(.system(size: 13, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(themeTokens.textColor.opacity(0.5))
                .textCase(.uppercase)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
                .accessibilityAddTraits(.isHeader)
```

- [ ] **Step 4: `MatchTimelineRow`**

In `BR2026/Components/MatchTimelineRow.swift`, find the closing of `body`:

```swift
            Group {
                if event.team == .away { content } else { Color.clear }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
    }
```

Replace with:

```swift
            Group {
                if event.team == .away { content } else { Color.clear }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(event.accessibilityLabel)
    }
```

Also hide the type icon (now redundant — its meaning is folded into `event.accessibilityLabel`
above). Find `icon`:

```swift
    @ViewBuilder
    private var icon: some View {
        switch event.type {
        case .goal:
            Image(systemName: "soccerball")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.8))
        case .yellowCard:
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.yellow)
                .frame(width: 10, height: 14)
        case .redCard:
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.red)
                .frame(width: 10, height: 14)
        case .substitution:
            HStack(spacing: 2) {
                Image(systemName: "arrow.down")
                    .foregroundStyle(Color.red)
                Image(systemName: "arrow.up")
                    .foregroundStyle(Color.green)
            }
            .font(.system(size: 11, weight: .bold))
        case .unknown:
            EmptyView()
        }
    }
```

Replace with:

```swift
    @ViewBuilder
    private var icon: some View {
        switch event.type {
        case .goal:
            Image(systemName: "soccerball")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.8))
        case .yellowCard:
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.yellow)
                .frame(width: 10, height: 14)
        case .redCard:
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.red)
                .frame(width: 10, height: 14)
        case .substitution:
            HStack(spacing: 2) {
                Image(systemName: "arrow.down")
                    .foregroundStyle(Color.red)
                Image(systemName: "arrow.up")
                    .foregroundStyle(Color.green)
            }
            .font(.system(size: 11, weight: .bold))
        case .unknown:
            EmptyView()
        }
    }
```

(No change needed here beyond what's already correct — the icon's containing `HStack` in
`content` doesn't need its own `.accessibilityHidden(true)` since the *entire row* already
became one combined+labeled element in the edit above, which removes all of its children,
including the icon, from VoiceOver's individual navigation automatically. Skip re-editing
`icon` itself.)

- [ ] **Step 5: Build to verify it compiles**

Run: `rm -rf ~/Library/Developer/Xcode/DerivedData/BR2026-* && xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation clean build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Manual verification**

Present Match Detail on a match with at least one timeline event (or verify against live data
during a live match, per this project's established manual-verification pattern). Confirm the
header reads as one combined sentence and each timeline row reads as one combined sentence
(e.g. "67th minute, goal, Neymar") rather than separate icon/name/subtitle stops.

- [ ] **Step 7: Commit**

```bash
git add BR2026/Views/MatchDetail/MatchDetailView.swift BR2026/Components/MatchTimelineRow.swift BR2026/Resources/Localizable.xcstrings
git commit -m "Wire VoiceOver support into Match Detail"
```

---

### Task 9: More screen wiring

**Files:**
- Modify: `BR2026/Views/More/MoreView.swift`

- [ ] **Step 1: Combine each row, hide decorative icons, mark disabled rows**

Find `rowLabel`:

```swift
    private func rowLabel(_ row: MoreRow, showsChevron: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: row.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 24)
            Text(row.titleKey)
                .font(.system(size: 16, weight: .semibold))
            Spacer()
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(themeTokens.textColor.opacity(0.3))
            }
        }
        .foregroundStyle(themeTokens.textColor)
        .padding(.vertical, 10)
        // Without this, the row's tappable area stops at the last piece of drawn
        // content (the icon/title on the left, or the chevron on the right) — the
        // `Spacer()` in between has nothing to hit-test against, so tapping the empty
        // middle of the row does nothing.
        .contentShape(Rectangle())
    }
```

Replace with:

```swift
    private func rowLabel(_ row: MoreRow, showsChevron: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: row.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 24)
            Text(row.titleKey)
                .font(.system(size: 16, weight: .semibold))
            Spacer()
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(themeTokens.textColor.opacity(0.3))
            }
        }
        .foregroundStyle(themeTokens.textColor)
        .padding(.vertical, 10)
        // Without this, the row's tappable area stops at the last piece of drawn
        // content (the icon/title on the left, or the chevron on the right) — the
        // `Spacer()` in between has nothing to hit-test against, so tapping the empty
        // middle of the row does nothing.
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: row.titleKey))
        .accessibilityAddTraits(row.isEnabled ? [] : .notEnabled)
    }
```

- [ ] **Step 2: Hide the competition logo**

Find `logoView`:

```swift
    @ViewBuilder
    private var logoView: some View {
        if let logoData = viewModel.competitionLogoData, let uiImage = UIImage(data: logoData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
        } else {
            AsyncImage(url: viewModel.competitionLogoURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                default:
                    Circle()
                        .fill(.white.opacity(0.07))
                        .overlay(
                            Image(systemName: "soccerball")
                                .font(.system(size: 28))
                                .foregroundStyle(themeTokens.textColor.opacity(0.55))
                        )
                }
            }
        }
    }
```

Replace with:

```swift
    @ViewBuilder
    private var logoView: some View {
        if let logoData = viewModel.competitionLogoData, let uiImage = UIImage(data: logoData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
        } else {
            AsyncImage(url: viewModel.competitionLogoURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                default:
                    Circle()
                        .fill(.white.opacity(0.07))
                        .overlay(
                            Image(systemName: "soccerball")
                                .font(.system(size: 28))
                                .foregroundStyle(themeTokens.textColor.opacity(0.55))
                        )
                }
            }
            .accessibilityHidden(true)
        }
    }
```

- [ ] **Step 3: Build to verify it compiles**

Run: `rm -rf ~/Library/Developer/Xcode/DerivedData/BR2026-* && xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation clean build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Manual verification**

Confirm each More row reads its title as one combined stop, the competition logo is skipped,
and any row currently rendered at reduced opacity (disabled) is announced as such.

- [ ] **Step 5: Commit**

```bash
git add BR2026/Views/More/MoreView.swift
git commit -m "Wire VoiceOver support into the More screen"
```

---

### Task 10: App Icon picker & Team Theme picker wiring

**Files:**
- Modify: `BR2026/Views/More/AppIconPickerView.swift`
- Modify: `BR2026/Views/More/TeamThemePickerView.swift`

- [ ] **Step 1: `AppIconPickerView.freeRowView`**

Find:

```swift
    private func freeRowView(_ option: AppIconOption) -> some View {
        Button {
            Task { await viewModel.select(option) }
        } label: {
            HStack(spacing: 12) {
                Image(option.previewImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(option.displayName)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                if viewModel.isSelected(option) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .foregroundStyle(themeTokens.textColor)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
```

Replace with:

```swift
    private func freeRowView(_ option: AppIconOption) -> some View {
        let isSelected = viewModel.isSelected(option)
        return Button {
            Task { await viewModel.select(option) }
        } label: {
            HStack(spacing: 12) {
                Image(option.previewImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
                Text(option.displayName)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(themeTokens.textColor)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isSelected ? String(localized: "\(option.displayName), selected", comment: "VoiceOver label for the currently-selected app icon option. Argument: the icon's display name.") : option.displayName)
    }
```

- [ ] **Step 2: `AppIconPickerView.teamRowView`**

Find:

```swift
    private func teamRowView(_ option: TeamIconOption) -> some View {
        Button {
            Task { await viewModel.select(option) }
        } label: {
            HStack(spacing: 12) {
                Image(option.previewImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(option.displayName)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                teamTrailingSlot(option)
            }
            .foregroundStyle(themeTokens.textColor)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
```

Replace with:

```swift
    private func teamRowView(_ option: TeamIconOption) -> some View {
        Button {
            Task { await viewModel.select(option) }
        } label: {
            HStack(spacing: 12) {
                Image(option.previewImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
                Text(option.displayName)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                teamTrailingSlot(option)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(themeTokens.textColor)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(teamRowAccessibilityLabel(option))
    }

    private func teamRowAccessibilityLabel(_ option: TeamIconOption) -> String {
        if !viewModel.isPurchased(option) {
            let price = viewModel.price(for: option) ?? ""
            return String(
                localized: "\(option.displayName), locked, \(price)",
                comment: "VoiceOver label for a locked, purchasable team icon option. Arguments: the option's display name, its price."
            )
        }
        if viewModel.isSelected(option) {
            return String(
                localized: "\(option.displayName), selected",
                comment: "VoiceOver label for the currently-selected team icon option. Argument: the option's display name."
            )
        }
        return option.displayName
    }
```

- [ ] **Step 3: `TeamThemePickerView.rowView`**

Find:

```swift
    private func rowView(_ option: TeamThemeOption?) -> some View {
        Button {
            Task { await viewModel.select(option) }
        } label: {
            HStack(spacing: 12) {
                if let option {
                    Text(option.displayName)
                } else {
                    Text("Default")
                }
                Spacer()
                trailingSlot(option)
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(themeTokens.textColor)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
```

Replace with:

```swift
    private func rowView(_ option: TeamThemeOption?) -> some View {
        Button {
            Task { await viewModel.select(option) }
        } label: {
            HStack(spacing: 12) {
                if let option {
                    Text(option.displayName)
                } else {
                    Text("Default")
                }
                Spacer()
                trailingSlot(option)
                    .accessibilityHidden(true)
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(themeTokens.textColor)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel(option))
    }

    private func rowAccessibilityLabel(_ option: TeamThemeOption?) -> String {
        let name = option?.displayName ?? String(localized: "Default", comment: "VoiceOver label for the Team Theme picker's non-team default row.")
        if let option, !viewModel.isPurchased(option) {
            let price = viewModel.price(for: option) ?? ""
            return String(
                localized: "\(name), locked, \(price)",
                comment: "VoiceOver label for a locked, purchasable team theme option. Arguments: the option's display name, its price."
            )
        }
        if viewModel.selectedOption == option {
            return String(
                localized: "\(name), selected",
                comment: "VoiceOver label for the currently-selected team theme option (or Default). Argument: the option's display name."
            )
        }
        return name
    }
```

- [ ] **Step 4: Add the catalog entries**

```python
import json

with open("BR2026/Resources/Localizable.xcstrings") as f:
    data = json.load(f)

ENTRIES = {
    "%1$@, selected": {
        "en": "%1$@, selected", "en-GB": "%1$@, selected", "fr": "%1$@, sélectionné",
        "pt-BR": "%1$@, selecionado", "pt-PT": "%1$@, selecionado", "es": "%1$@, seleccionado"
    },
    "%1$@, locked, %2$@": {
        "en": "%1$@, locked, %2$@", "en-GB": "%1$@, locked, %2$@",
        "fr": "%1$@, verrouillé, %2$@", "pt-BR": "%1$@, bloqueado, %2$@",
        "pt-PT": "%1$@, bloqueado, %2$@", "es": "%1$@, bloqueado, %2$@"
    }
}

for key, translations in ENTRIES.items():
    data["strings"][key] = {
        "extractionState": "manual",
        "localizations": {
            locale: {"stringUnit": {"state": "translated", "value": value}}
            for locale, value in translations.items()
        }
    }

with open("BR2026/Resources/Localizable.xcstrings", "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False, sort_keys=False)
    f.write("\n")
```

(Note: `"Default"` as a bare word is very likely already a catalog key from other existing UI
in this app — check with the same `python3 -c "print('Default' in data['strings'])"` pattern
from Task 6 Step 8 before adding it again; if present, skip re-adding it.)

- [ ] **Step 5: Build to verify it compiles**

Run: `rm -rf ~/Library/Developer/Xcode/DerivedData/BR2026-* && xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation clean build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Manual verification**

In the App Icon and Team Theme pickers, confirm a locked team option reads e.g. "Palmeiras
(Home), locked, $0.99" and the currently-selected option reads "..., selected" — not silent
lock/checkmark icons with no spoken state.

- [ ] **Step 7: Commit**

```bash
git add BR2026/Views/More/AppIconPickerView.swift BR2026/Views/More/TeamThemePickerView.swift BR2026/Resources/Localizable.xcstrings
git commit -m "Wire VoiceOver support into the App Icon and Team Theme pickers"
```

---

### Task 11: Automated accessibility audit UI tests

**Files:**
- Create: `BR2026UITests/AccessibilityAuditUITests.swift`

**Interfaces:**
- Consumes: all of Tasks 6-10's wiring (this task is the regression gate for all of them).

- [ ] **Step 1: Write the test file**

```swift
// BR2026UITests/AccessibilityAuditUITests.swift
import XCTest

final class AccessibilityAuditUITests: XCTestCase {
    private static let auditTypes: XCUIAccessibilityAuditType = [
        .sufficientElementDescription, .trait, .action, .parentChild, .elementDetection
    ]

    private func launchedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        let tabBar = app.tabBars.firstMatch
        _ = tabBar.waitForExistence(timeout: 10)
        return app
    }

    func testMatchdayAudit() throws {
        let app = launchedApp()
        app.tabBars.firstMatch.buttons.element(boundBy: 0).tap()
        sleep(2)
        try app.performAccessibilityAudit(for: Self.auditTypes)
    }

    func testFixturesAudit() throws {
        let app = launchedApp()
        app.tabBars.firstMatch.buttons.element(boundBy: 1).tap()
        sleep(2)
        try app.performAccessibilityAudit(for: Self.auditTypes)
    }

    func testStandingsAudit() throws {
        let app = launchedApp()
        app.tabBars.firstMatch.buttons.element(boundBy: 2).tap()
        sleep(2)
        try app.performAccessibilityAudit(for: Self.auditTypes)
    }

    func testMoreAudit() throws {
        let app = launchedApp()
        app.tabBars.firstMatch.buttons.element(boundBy: 3).tap()
        sleep(2)
        try app.performAccessibilityAudit(for: Self.auditTypes)
    }

    func testMatchDetailAudit() throws {
        let app = launchedApp()
        app.tabBars.firstMatch.buttons.element(boundBy: 0).tap()
        sleep(2)
        let heroCoordinate = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        heroCoordinate.tap()
        sleep(2)
        try app.performAccessibilityAudit(for: Self.auditTypes)
    }

    func testAppIconPickerAudit() throws {
        let app = launchedApp()
        app.tabBars.firstMatch.buttons.element(boundBy: 3).tap()
        sleep(1)
        app.staticTexts["App Icon"].firstMatch.tap()
        sleep(2)
        try app.performAccessibilityAudit(for: Self.auditTypes)
    }

    func testTeamThemePickerAudit() throws {
        let app = launchedApp()
        app.tabBars.firstMatch.buttons.element(boundBy: 3).tap()
        sleep(1)
        app.staticTexts["Team Theme"].firstMatch.tap()
        sleep(2)
        try app.performAccessibilityAudit(for: Self.auditTypes)
    }
}
```

**Note:** `testAppIconPickerAudit`/`testTeamThemePickerAudit` tap a row by its visible label
text (`app.staticTexts["App Icon"]`/`["Team Theme"]`). If the More screen's row titles differ
from these exact strings in the running app (check `MoreViewModel`'s section/row definitions
if the tap fails to find the element), adjust the lookup string to match — do not guess
further than one correction; if it's still not found after checking `MoreViewModel`, escalate
rather than deleting the test.

- [ ] **Step 2: Register the new file in the Xcode project**

```bash
eval "$(rbenv init -)"
bundle exec ruby -e '
require "xcodeproj"
project = Xcodeproj::Project.open("BR2026.xcodeproj")
group = project.main_group.find_subpath("BR2026UITests", false)
raise "group not found" unless group
file_ref = group.new_reference("AccessibilityAuditUITests.swift")
target = project.targets.find { |t| t.name == "BR2026UITests" } or raise "no BR2026UITests target"
target.source_build_phase.add_file_reference(file_ref)
project.save
puts "Registered AccessibilityAuditUITests.swift"
'
```

- [ ] **Step 3: Run the full test suite (fully clean)**

Run: `rm -rf ~/Library/Developer/Xcode/DerivedData/BR2026-* && eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: all tests pass, including the 7 new UI audit tests. If any audit finds a real issue
(missing label, wrong trait, etc.) that Tasks 6-10 should have already fixed, treat it as a
regression in this plan's own work — fix the underlying View, not the audit test.

- [ ] **Step 4: Commit**

```bash
git add BR2026UITests/AccessibilityAuditUITests.swift BR2026.xcodeproj/project.pbxproj
git commit -m "Add automated accessibility audit UI tests"
```

---

### Task 12: Full verification across all 6 targets

**Files:** None (verification only).

- [ ] **Step 1: Run the full unit + UI test suite (fully clean)**

Run: `rm -rf ~/Library/Developer/Xcode/DerivedData/BR2026-* && eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: all tests pass (existing suite + every test added in Tasks 1-4 and 11).

- [ ] **Step 2: Build all 6 targets (fully clean)**

Run (repeat for each scheme — `BR2026`, `PremierLeague2026`, `Ligue12026`,
`PrimeiraLiga2026`, `ScottishPremiership2026`, `LaLiga2026`):

```bash
xcodebuild -project BR2026.xcodeproj -scheme <Scheme> -destination 'generic/platform=iOS Simulator' -skipMacroValidation clean build
```

Expected: `** BUILD SUCCEEDED **` for all six.

- [ ] **Step 3: Manual VoiceOver pass**

Enable VoiceOver on a simulator or device (Settings → Accessibility → VoiceOver) and swipe
through each of the 4 tabs, Match Detail, and both pickers. Confirm: every match/standing row
reads one coherent sentence; no bare abbreviations or unlabeled icons are announced; disabled
More rows are announced as such; a live match's score change (if one is available) triggers an
announcement without the user navigating away and back.

No commit for this task — verification only.
