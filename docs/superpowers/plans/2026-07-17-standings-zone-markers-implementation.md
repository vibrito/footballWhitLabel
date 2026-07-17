# Standings Zone Markers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Visually mark relegation and continental-qualification position ranges in the
Standings table, driven by the API's newly-observed `description` field, classified into two
keyword-based buckets and shown via our own localized labels — never the raw API text.

**Architecture:** New `description: String?` field threaded from `StandingDTO` through
`Standing` (SwiftData model). A pure computed `StandingZone` classification (plain Swift, no
UI dependency) drives both a new leading colored bar in `StandingsView`'s row and an appended
clause in `Standing.accessibilityLabel`. No new files beyond tests — everything lives in the
existing `Standing`/`StandingDTO`/`StandingsView` files.

**Tech Stack:** Swift Testing (`@Test`), no new dependencies.

## Global Constraints

- Full spec: `docs/superpowers/specs/2026-07-17-standings-zone-markers-design.md`.
- Real, verified API values this plan is built against (fetched live from all 6
  competitions on 2026-07-17): `"Promotion - Copa Libertadores (Group Stage)"`, `"Promotion -
  Copa Libertadores (Qualification)"`, `"Promotion - Copa Sudamericana (Group Stage)"`,
  `"Relegation - Serie B"`, `"None"` (BSA); `"Champions League league stage"`, `"Relegation"`
  (PL, PD); `"Champions League"`, `"Relegation Playoffs"`, `"Relegation"` (FL1); `"Promotion -
  Champions League (League phase)"`, `"Promotion - Champions League (Qualification)"`, `"Liga
  Portugal (Relegation)"`, `"Relegation - Liga Portugal 2"` (PPL); `"Promotion - Premiership
  (Championship Group)"`, `"Premiership (Relegation Group)"` (SPL).
- Classification (must match exactly, case-sensitive substring match — the API's own casing
  is consistent in all observed samples):
  - `relegation`: `description` contains `"Relegation"`.
  - `qualification`: `description` contains `"Promotion"`, OR contains any of `"Champions
    League"`, `"Europa League"`, `"Conference League"`, `"Libertadores"`, `"Sudamericana"`.
    Check `relegation` first — if a description ever matched both (not observed in any real
    sample), relegation wins, since it's the more specific/definitive signal.
  - Otherwise (including the literal string `"None"`, and `nil`): `.none` — no marker, no
    label.
- The raw `description` string is NEVER displayed anywhere in the UI — it only drives
  classification. All user-facing text is our own, newly-added, fully translated (6 locales)
  strings.
- New colors: `qualification` reuses CLAUDE.md's existing `advance: #2dd4bf` (teal) — do not
  introduce a second color for this. `relegation` is a new color, `#ef4444`, to be documented
  in CLAUDE.md's Status section alongside `advance`/`playoff`.
- Follow this project's established `String(localized:)` discipline: every interpolated
  value must be pre-converted to `String` before interpolation (never a raw `Int`/other
  type); after writing any new catalog entry, verify the actual runtime-generated key via a
  throwaway `String.LocalizationValue` + `dump()` reflection script before trusting it
  matches what's in `Localizable.xcstrings` — this project's history has hit this exact bug
  multiple times when this step was skipped.
- No changes to `LiveMatchService.fetchStandings()`'s delete-and-reinsert refresh strategy —
  this plan only adds a field to what's already fetched/persisted.

---

### Task 1: `description` field, `StandingZone` classification, and VoiceOver wiring

**Files:**
- Modify: `BR2026/Models/StandingDTO.swift`
- Modify: `BR2026/Models/Standing.swift`
- Modify: `BR2026Tests/Models/StandingTests.swift`
- Modify: `BR2026/Resources/Localizable.xcstrings`

**Interfaces:**
- Produces: `Standing.zoneDescription: String?`, `Standing.zone: StandingZone` (new enum,
  cases `.qualification`, `.relegation`, `.none`), `Standing.zoneAccessibilityLabel: String?`
  — Task 3 (View wiring) consumes `zone` and reuses the same two localized strings
  `zoneAccessibilityLabel` produces, for the legend.

- [ ] **Step 1: Write the failing tests**

Add to `BR2026Tests/Models/StandingTests.swift`, inside `@Suite("Standing decoding") struct
StandingTests`, after the existing tests:

```swift
    @Test("Decodes the description field from API JSON")
    func decodesDescription() throws {
        let json = Data("""
        {
            "position": 1,
            "team": { "id": 121, "tla": null, "name": "Palmeiras", "crest": "https://media.api-sports.io/football/teams/121.png", "shortName": "Palmeiras" },
            "playedGames": 15,
            "won": 12,
            "draw": 5,
            "lost": 1,
            "goalsFor": 41,
            "goalsAgainst": 18,
            "goalDifference": 23,
            "points": 41,
            "description": "Promotion - Copa Libertadores (Group Stage)"
        }
        """.utf8)
        let dto = try JSONDecoder().decode(StandingDTO.self, from: json)
        #expect(dto.description == "Promotion - Copa Libertadores (Group Stage)")
        let standing = Standing(dto: dto)
        #expect(standing.zoneDescription == "Promotion - Copa Libertadores (Group Stage)")
    }

    @Test("Decodes standings entries with no description field at all (optional, absent key)")
    func decodesMissingDescription() throws {
        let json = Data("""
        {
            "position": 12,
            "team": { "id": 131, "tla": null, "name": "Corinthians", "crest": null, "shortName": "Corinthians" },
            "playedGames": 15, "won": 5, "draw": 5, "lost": 5,
            "goalsFor": 16, "goalsAgainst": 16, "goalDifference": 0, "points": 20
        }
        """.utf8)
        let dto = try JSONDecoder().decode(StandingDTO.self, from: json)
        #expect(dto.description == nil)
    }

    @Test("zone classifies real observed API description values correctly", arguments: [
        ("Promotion - Copa Libertadores (Group Stage)", StandingZone.qualification),
        ("Promotion - Copa Libertadores (Qualification)", StandingZone.qualification),
        ("Promotion - Copa Sudamericana (Group Stage)", StandingZone.qualification),
        ("Champions League league stage", StandingZone.qualification),
        ("Champions League", StandingZone.qualification),
        ("Promotion - Champions League (League phase)", StandingZone.qualification),
        ("Promotion - Premiership (Championship Group)", StandingZone.qualification),
        ("Relegation - Serie B", StandingZone.relegation),
        ("Relegation", StandingZone.relegation),
        ("Relegation Playoffs", StandingZone.relegation),
        ("Liga Portugal (Relegation)", StandingZone.relegation),
        ("Relegation - Liga Portugal 2", StandingZone.relegation),
        ("Premiership (Relegation Group)", StandingZone.relegation),
        ("None", StandingZone.none),
    ])
    func zoneClassifiesRealAPIValues(description: String, expectedZone: StandingZone) throws {
        let team = Team(id: 1, name: "Test", shortName: "Test", crestURL: nil)
        let standing = Standing(
            position: 1, team: team, playedGames: 10, won: 5, draw: 3, lost: 2,
            goalsFor: 10, goalsAgainst: 10, goalDifference: 0, points: 18,
            zoneDescription: description
        )
        #expect(standing.zone == expectedZone)
    }

    @Test("zone is .none when zoneDescription is nil")
    func zoneIsNoneWhenDescriptionIsNil() throws {
        let team = Team(id: 1, name: "Test", shortName: "Test", crestURL: nil)
        let standing = Standing(
            position: 1, team: team, playedGames: 10, won: 5, draw: 3, lost: 2,
            goalsFor: 10, goalsAgainst: 10, goalDifference: 0, points: 18
        )
        #expect(standing.zone == .none)
    }

    @Test("accessibilityLabel appends the qualification label when zone is qualification")
    func accessibilityLabelAppendsQualification() throws {
        let team = Team(id: 121, name: "Palmeiras", shortName: "Palmeiras", crestURL: nil)
        let standing = Standing(
            position: 1, team: team, playedGames: 15, won: 12, draw: 5, lost: 1,
            goalsFor: 41, goalsAgainst: 18, goalDifference: 23, points: 41,
            zoneDescription: "Promotion - Copa Libertadores (Group Stage)"
        )
        #expect(standing.accessibilityLabel.hasSuffix("Continental qualification"))
    }

    @Test("accessibilityLabel appends the relegation label when zone is relegation")
    func accessibilityLabelAppendsRelegation() throws {
        let team = Team(id: 132, name: "Chapecoense-sc", shortName: "Chapecoense-sc", crestURL: nil)
        let standing = Standing(
            position: 20, team: team, playedGames: 15, won: 2, draw: 4, lost: 9,
            goalsFor: 9, goalsAgainst: 27, goalDifference: -18, points: 10,
            zoneDescription: "Relegation - Serie B"
        )
        #expect(standing.accessibilityLabel.hasSuffix("Relegation zone"))
    }

    @Test("accessibilityLabel is unchanged (no trailing zone clause) when zone is .none")
    func accessibilityLabelUnchangedWhenNoZone() throws {
        let team = Team(id: 131, name: "Corinthians", shortName: "Corinthians", crestURL: nil)
        let standing = Standing(
            position: 12, team: team, playedGames: 15, won: 5, draw: 5, lost: 5,
            goalsFor: 16, goalsAgainst: 16, goalDifference: 0, points: 20
        )
        #expect(standing.accessibilityLabel.hasSuffix("points"))
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: FAIL to build — `Cannot find 'StandingZone' in scope`, `Value of type 'StandingDTO'
has no member 'description'`, and similar.

- [ ] **Step 3: Add `description` to `StandingDTO`**

In `BR2026/Models/StandingDTO.swift`, find:

```swift
struct StandingDTO: Decodable {
    let position: Int
    let team: TeamDTO
    let playedGames: Int
    let won: Int
    let draw: Int
    let lost: Int
    let goalsFor: Int
    let goalsAgainst: Int
    let goalDifference: Int
    let points: Int
}
```

Replace with:

```swift
struct StandingDTO: Decodable {
    let position: Int
    let team: TeamDTO
    let playedGames: Int
    let won: Int
    let draw: Int
    let lost: Int
    let goalsFor: Int
    let goalsAgainst: Int
    let goalDifference: Int
    let points: Int
    /// A free-text, English-only field from the upstream provider describing this position's
    /// zone within the competition — e.g. "Promotion - Copa Libertadores (Group Stage)",
    /// "Relegation", or the literal string "None" for a mid-table position with no zone.
    /// Never displayed directly (see `Standing.zone`/`Standing.zoneAccessibilityLabel`) —
    /// only used to classify into `StandingZone`. `nil` when the key is absent from the
    /// response entirely (distinct from the literal string "None", which `StandingZone`
    /// treats the same way).
    let description: String?
}
```

- [ ] **Step 4: Add `zoneDescription`, `StandingZone`, `zone`, and `zoneAccessibilityLabel` to `Standing`**

In `BR2026/Models/Standing.swift`, find the property list and designated init:

```swift
@Model
final class Standing: Identifiable {
    @Attribute(.unique) var teamID: Int
    var position: Int
    var team: Team
    var playedGames: Int
    var won: Int
    var draw: Int
    var lost: Int
    var goalsFor: Int
    var goalsAgainst: Int
    var goalDifference: Int
    var points: Int

    var id: Int { teamID }

    init(
        position: Int,
        team: Team,
        playedGames: Int,
        won: Int,
        draw: Int,
        lost: Int,
        goalsFor: Int,
        goalsAgainst: Int,
        goalDifference: Int,
        points: Int
    ) {
        self.teamID = team.id
        self.position = position
        self.team = team
        self.playedGames = playedGames
        self.won = won
        self.draw = draw
        self.lost = lost
        self.goalsFor = goalsFor
        self.goalsAgainst = goalsAgainst
        self.goalDifference = goalDifference
        self.points = points
    }

    convenience init(dto: StandingDTO) {
        self.init(
            position: dto.position,
            team: Team(dto: dto.team),
            playedGames: dto.playedGames,
            won: dto.won,
            draw: dto.draw,
            lost: dto.lost,
            goalsFor: dto.goalsFor,
            goalsAgainst: dto.goalsAgainst,
            goalDifference: dto.goalDifference,
            points: dto.points
        )
    }
```

Replace with:

```swift
@Model
final class Standing: Identifiable {
    @Attribute(.unique) var teamID: Int
    var position: Int
    var team: Team
    var playedGames: Int
    var won: Int
    var draw: Int
    var lost: Int
    var goalsFor: Int
    var goalsAgainst: Int
    var goalDifference: Int
    var points: Int
    var zoneDescription: String?

    var id: Int { teamID }

    init(
        position: Int,
        team: Team,
        playedGames: Int,
        won: Int,
        draw: Int,
        lost: Int,
        goalsFor: Int,
        goalsAgainst: Int,
        goalDifference: Int,
        points: Int,
        zoneDescription: String? = nil
    ) {
        self.teamID = team.id
        self.position = position
        self.team = team
        self.playedGames = playedGames
        self.won = won
        self.draw = draw
        self.lost = lost
        self.goalsFor = goalsFor
        self.goalsAgainst = goalsAgainst
        self.goalDifference = goalDifference
        self.points = points
        self.zoneDescription = zoneDescription
    }

    convenience init(dto: StandingDTO) {
        self.init(
            position: dto.position,
            team: Team(dto: dto.team),
            playedGames: dto.playedGames,
            won: dto.won,
            draw: dto.draw,
            lost: dto.lost,
            goalsFor: dto.goalsFor,
            goalsAgainst: dto.goalsAgainst,
            goalDifference: dto.goalDifference,
            points: dto.points,
            zoneDescription: dto.description
        )
    }

    /// Which zone (if any) this standings position falls into, classified from the raw API
    /// `description` text by keyword — see the plan's Global Constraints for the exact rule.
    /// Never derived from a per-competition position-range table (e.g. "bottom 4 teams") —
    /// those rules vary by competition/season and the API's own `description` field already
    /// encodes the current season's actual boundaries.
    var zone: StandingZone {
        guard let zoneDescription else { return .none }
        if zoneDescription.contains("Relegation") { return .relegation }
        let qualificationKeywords = ["Promotion", "Champions League", "Europa League", "Conference League", "Libertadores", "Sudamericana"]
        if qualificationKeywords.contains(where: { zoneDescription.contains($0) }) { return .qualification }
        return .none
    }

    /// Our own localized label for `zone` — never the raw `zoneDescription` API text, which
    /// is English-only and inconsistently worded across competitions. `nil` for `.none`.
    var zoneAccessibilityLabel: String? {
        switch zone {
        case .qualification:
            return String(localized: "Continental qualification", comment: "VoiceOver/legend label for a standings row in a continental-competition qualification position (Champions League, Copa Libertadores, Copa Sudamericana, etc., regardless of which specific competition or stage).")
        case .relegation:
            return String(localized: "Relegation zone", comment: "VoiceOver/legend label for a standings row in a relegation position.")
        case .none:
            return nil
        }
    }
```

- [ ] **Step 5: Add the `StandingZone` enum**

In `BR2026/Models/Standing.swift`, after the closing `}` of the `Standing` class, add:

```swift

enum StandingZone {
    case qualification
    case relegation
    case none
}
```

- [ ] **Step 6: Fold `zoneAccessibilityLabel` into `accessibilityLabel`**

In `BR2026/Models/Standing.swift`, find:

```swift
        return String(
            localized: "\(positionText) place, \(team.displayName), \(playedGamesText) played, \(wonText) won, \(drawText) drawn, \(lostText) lost, goal difference \(goalDifferenceText), \(pointsText) points",
            comment: "VoiceOver label for one standings table row. Arguments: ordinal position, team name, games played, wins, draws, losses, goal difference (already spelled out with plus/minus), points."
        )
    }
}
```

Replace with:

```swift
        let baseLabel = String(
            localized: "\(positionText) place, \(team.displayName), \(playedGamesText) played, \(wonText) won, \(drawText) drawn, \(lostText) lost, goal difference \(goalDifferenceText), \(pointsText) points",
            comment: "VoiceOver label for one standings table row. Arguments: ordinal position, team name, games played, wins, draws, losses, goal difference (already spelled out with plus/minus), points."
        )
        guard let zoneLabel = zoneAccessibilityLabel else { return baseLabel }
        return "\(baseLabel), \(zoneLabel)"
    }
}
```

(This is plain Swift string concatenation of two independently-localized strings — not a
new `String(localized:)` interpolation, so it doesn't touch or require re-translating any
existing catalog entry for the base sentence.)

- [ ] **Step 7: Add the catalog entries**

First, independently verify the two new strings generate bare, no-argument catalog keys
(they're plain literals with no interpolation, so this should be trivial, but confirm rather
than assume): write a throwaway Swift script doing
`dump(String.LocalizationValue("Continental qualification"))` and
`dump(String.LocalizationValue("Relegation zone"))`, run with `swift <file>.swift`, and
confirm the `key:` field in each dump matches the literal string exactly.

```python
import json

with open("BR2026/Resources/Localizable.xcstrings") as f:
    data = json.load(f)

ENTRIES = {
    "Continental qualification": {
        "en": "Continental qualification", "en-GB": "Continental qualification",
        "fr": "Qualification continentale", "pt-BR": "Classificação continental",
        "pt-PT": "Qualificação continental", "es": "Clasificación continental"
    },
    "Relegation zone": {
        "en": "Relegation zone", "en-GB": "Relegation zone",
        "fr": "Zone de relégation", "pt-BR": "Zona de rebaixamento",
        "pt-PT": "Zona de despromoção", "es": "Zona de descenso"
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

- [ ] **Step 8: Run the tests to verify they pass**

Run: `rm -rf ~/Library/Developer/Xcode/DerivedData/BR2026-* && eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: all tests pass, including the new ones (7 new `@Test`s, one of which is
parameterized with 14 arguments).

- [ ] **Step 9: Commit**

```bash
git add BR2026/Models/StandingDTO.swift BR2026/Models/Standing.swift BR2026Tests/Models/StandingTests.swift BR2026/Resources/Localizable.xcstrings
git commit -m "Add StandingZone classification and VoiceOver wiring for relegation/qualification zones"
```

---

### Task 2: Mock data fixture

**Files:**
- Modify: `BR2026/MockData/MockDataProvider.swift`

**Interfaces:**
- Consumes: `Standing`/`StandingDTO`'s new `description` field from Task 1. No new
  interfaces produced — this task only adds realistic sample data so the app's mock/preview
  path (used by `MockMatchService`, which backs unit tests and any SwiftUI preview) reflects
  the feature end-to-end.

- [ ] **Step 1: Add `description` values to all 20 mock standings entries**

In `BR2026/MockData/MockDataProvider.swift`'s `standingsJSON`, add a `"description"` key to
each of the 20 entries, following the exact real-world pattern observed live for Brasileirão
(positions 1-4 Libertadores Group Stage, position 5 Libertadores Qualification, positions
6-11 Sudamericana Group Stage, positions 12-16 no marker, positions 17-20 Relegation). Apply
each of the following 20 Find/Replace pairs (each `Find` block is unique in the file, since
every entry has a distinct team `id`/`name`/stat line):

Find:
```swift
            {
                "position": 1,
                "team": { "id": 121, "tla": null, "name": "Palmeiras", "crest": "https://media.api-sports.io/football/teams/121.png", "shortName": "Palmeiras" },
                "playedGames": 15, "won": 10, "draw": 3, "lost": 2,
                "goalsFor": 30, "goalsAgainst": 12, "goalDifference": 18, "points": 33
            },
```
Replace:
```swift
            {
                "position": 1,
                "team": { "id": 121, "tla": null, "name": "Palmeiras", "crest": "https://media.api-sports.io/football/teams/121.png", "shortName": "Palmeiras" },
                "playedGames": 15, "won": 10, "draw": 3, "lost": 2,
                "goalsFor": 30, "goalsAgainst": 12, "goalDifference": 18, "points": 33,
                "description": "Promotion - Copa Libertadores (Group Stage)"
            },
```

Find:
```swift
            {
                "position": 2,
                "team": { "id": 127, "tla": null, "name": "Flamengo", "crest": "https://media.api-sports.io/football/teams/127.png", "shortName": "Flamengo" },
                "playedGames": 15, "won": 9, "draw": 4, "lost": 2,
                "goalsFor": 28, "goalsAgainst": 14, "goalDifference": 14, "points": 31
            },
```
Replace:
```swift
            {
                "position": 2,
                "team": { "id": 127, "tla": null, "name": "Flamengo", "crest": "https://media.api-sports.io/football/teams/127.png", "shortName": "Flamengo" },
                "playedGames": 15, "won": 9, "draw": 4, "lost": 2,
                "goalsFor": 28, "goalsAgainst": 14, "goalDifference": 14, "points": 31,
                "description": "Promotion - Copa Libertadores (Group Stage)"
            },
```

Find:
```swift
            {
                "position": 3,
                "team": { "id": 119, "tla": null, "name": "Internacional", "crest": "https://media.api-sports.io/football/teams/119.png", "shortName": "Internacional" },
                "playedGames": 15, "won": 8, "draw": 5, "lost": 2,
                "goalsFor": 25, "goalsAgainst": 15, "goalDifference": 10, "points": 29
            },
```
Replace:
```swift
            {
                "position": 3,
                "team": { "id": 119, "tla": null, "name": "Internacional", "crest": "https://media.api-sports.io/football/teams/119.png", "shortName": "Internacional" },
                "playedGames": 15, "won": 8, "draw": 5, "lost": 2,
                "goalsFor": 25, "goalsAgainst": 15, "goalDifference": 10, "points": 29,
                "description": "Promotion - Copa Libertadores (Group Stage)"
            },
```

Find:
```swift
            {
                "position": 4,
                "team": { "id": 120, "tla": null, "name": "Botafogo", "crest": "https://media.api-sports.io/football/teams/120.png", "shortName": "Botafogo" },
                "playedGames": 15, "won": 8, "draw": 4, "lost": 3,
                "goalsFor": 24, "goalsAgainst": 16, "goalDifference": 8, "points": 28
            },
```
Replace:
```swift
            {
                "position": 4,
                "team": { "id": 120, "tla": null, "name": "Botafogo", "crest": "https://media.api-sports.io/football/teams/120.png", "shortName": "Botafogo" },
                "playedGames": 15, "won": 8, "draw": 4, "lost": 3,
                "goalsFor": 24, "goalsAgainst": 16, "goalDifference": 8, "points": 28,
                "description": "Promotion - Copa Libertadores (Group Stage)"
            },
```

Find:
```swift
            {
                "position": 5,
                "team": { "id": 126, "tla": null, "name": "São Paulo", "crest": "https://media.api-sports.io/football/teams/126.png", "shortName": "São Paulo" },
                "playedGames": 15, "won": 8, "draw": 3, "lost": 4,
                "goalsFor": 22, "goalsAgainst": 17, "goalDifference": 5, "points": 27
            },
```
Replace:
```swift
            {
                "position": 5,
                "team": { "id": 126, "tla": null, "name": "São Paulo", "crest": "https://media.api-sports.io/football/teams/126.png", "shortName": "São Paulo" },
                "playedGames": 15, "won": 8, "draw": 3, "lost": 4,
                "goalsFor": 22, "goalsAgainst": 17, "goalDifference": 5, "points": 27,
                "description": "Promotion - Copa Libertadores (Qualification)"
            },
```

Find:
```swift
            {
                "position": 6,
                "team": { "id": 131, "tla": null, "name": "Corinthians", "crest": "https://media.api-sports.io/football/teams/131.png", "shortName": "Corinthians" },
                "playedGames": 15, "won": 7, "draw": 5, "lost": 3,
                "goalsFor": 21, "goalsAgainst": 16, "goalDifference": 5, "points": 26
            },
```
Replace:
```swift
            {
                "position": 6,
                "team": { "id": 131, "tla": null, "name": "Corinthians", "crest": "https://media.api-sports.io/football/teams/131.png", "shortName": "Corinthians" },
                "playedGames": 15, "won": 7, "draw": 5, "lost": 3,
                "goalsFor": 21, "goalsAgainst": 16, "goalDifference": 5, "points": 26,
                "description": "Promotion - Copa Sudamericana (Group Stage)"
            },
```

Find:
```swift
            {
                "position": 7,
                "team": { "id": 135, "tla": null, "name": "Cruzeiro", "crest": "https://media.api-sports.io/football/teams/135.png", "shortName": "Cruzeiro" },
                "playedGames": 15, "won": 7, "draw": 4, "lost": 4,
                "goalsFor": 20, "goalsAgainst": 17, "goalDifference": 3, "points": 25
            },
```
Replace:
```swift
            {
                "position": 7,
                "team": { "id": 135, "tla": null, "name": "Cruzeiro", "crest": "https://media.api-sports.io/football/teams/135.png", "shortName": "Cruzeiro" },
                "playedGames": 15, "won": 7, "draw": 4, "lost": 4,
                "goalsFor": 20, "goalsAgainst": 17, "goalDifference": 3, "points": 25,
                "description": "Promotion - Copa Sudamericana (Group Stage)"
            },
```

Find:
```swift
            {
                "position": 8,
                "team": { "id": 1062, "tla": null, "name": "Atlético-MG", "crest": "https://media.api-sports.io/football/teams/1062.png", "shortName": "Atlético-MG" },
                "playedGames": 15, "won": 7, "draw": 3, "lost": 5,
                "goalsFor": 19, "goalsAgainst": 18, "goalDifference": 1, "points": 24
            },
```
Replace:
```swift
            {
                "position": 8,
                "team": { "id": 1062, "tla": null, "name": "Atlético-MG", "crest": "https://media.api-sports.io/football/teams/1062.png", "shortName": "Atlético-MG" },
                "playedGames": 15, "won": 7, "draw": 3, "lost": 5,
                "goalsFor": 19, "goalsAgainst": 18, "goalDifference": 1, "points": 24,
                "description": "Promotion - Copa Sudamericana (Group Stage)"
            },
```

Find:
```swift
            {
                "position": 9,
                "team": { "id": 118, "tla": null, "name": "Bahia", "crest": "https://media.api-sports.io/football/teams/118.png", "shortName": "Bahia" },
                "playedGames": 15, "won": 6, "draw": 5, "lost": 4,
                "goalsFor": 18, "goalsAgainst": 17, "goalDifference": 1, "points": 23
            },
```
Replace:
```swift
            {
                "position": 9,
                "team": { "id": 118, "tla": null, "name": "Bahia", "crest": "https://media.api-sports.io/football/teams/118.png", "shortName": "Bahia" },
                "playedGames": 15, "won": 6, "draw": 5, "lost": 4,
                "goalsFor": 18, "goalsAgainst": 17, "goalDifference": 1, "points": 23,
                "description": "Promotion - Copa Sudamericana (Group Stage)"
            },
```

Find:
```swift
            {
                "position": 10,
                "team": { "id": 124, "tla": null, "name": "Fluminense", "crest": "https://media.api-sports.io/football/teams/124.png", "shortName": "Fluminense" },
                "playedGames": 15, "won": 6, "draw": 4, "lost": 5,
                "goalsFor": 17, "goalsAgainst": 18, "goalDifference": -1, "points": 22
            },
```
Replace:
```swift
            {
                "position": 10,
                "team": { "id": 124, "tla": null, "name": "Fluminense", "crest": "https://media.api-sports.io/football/teams/124.png", "shortName": "Fluminense" },
                "playedGames": 15, "won": 6, "draw": 4, "lost": 5,
                "goalsFor": 17, "goalsAgainst": 18, "goalDifference": -1, "points": 22,
                "description": "Promotion - Copa Sudamericana (Group Stage)"
            },
```

Find:
```swift
            {
                "position": 11,
                "team": { "id": 130, "tla": null, "name": "Grêmio", "crest": "https://media.api-sports.io/football/teams/130.png", "shortName": "Grêmio" },
                "playedGames": 15, "won": 6, "draw": 3, "lost": 6,
                "goalsFor": 16, "goalsAgainst": 18, "goalDifference": -2, "points": 21
            },
```
Replace:
```swift
            {
                "position": 11,
                "team": { "id": 130, "tla": null, "name": "Grêmio", "crest": "https://media.api-sports.io/football/teams/130.png", "shortName": "Grêmio" },
                "playedGames": 15, "won": 6, "draw": 3, "lost": 6,
                "goalsFor": 16, "goalsAgainst": 18, "goalDifference": -2, "points": 21,
                "description": "Promotion - Copa Sudamericana (Group Stage)"
            },
```

Find:
```swift
            {
                "position": 12,
                "team": { "id": 133, "tla": null, "name": "Vasco da Gama", "crest": "https://media.api-sports.io/football/teams/133.png", "shortName": "Vasco da Gama" },
                "playedGames": 15, "won": 5, "draw": 5, "lost": 5,
                "goalsFor": 16, "goalsAgainst": 19, "goalDifference": -3, "points": 20
            },
```
Replace:
```swift
            {
                "position": 12,
                "team": { "id": 133, "tla": null, "name": "Vasco da Gama", "crest": "https://media.api-sports.io/football/teams/133.png", "shortName": "Vasco da Gama" },
                "playedGames": 15, "won": 5, "draw": 5, "lost": 5,
                "goalsFor": 16, "goalsAgainst": 19, "goalDifference": -3, "points": 20,
                "description": "None"
            },
```

Find:
```swift
            {
                "position": 13,
                "team": { "id": 207, "tla": null, "name": "Fortaleza", "crest": "https://media.api-sports.io/football/teams/207.png", "shortName": "Fortaleza" },
                "playedGames": 15, "won": 5, "draw": 4, "lost": 6,
                "goalsFor": 15, "goalsAgainst": 19, "goalDifference": -4, "points": 19
            },
```
Replace:
```swift
            {
                "position": 13,
                "team": { "id": 207, "tla": null, "name": "Fortaleza", "crest": "https://media.api-sports.io/football/teams/207.png", "shortName": "Fortaleza" },
                "playedGames": 15, "won": 5, "draw": 4, "lost": 6,
                "goalsFor": 15, "goalsAgainst": 19, "goalDifference": -4, "points": 19,
                "description": "None"
            },
```

Find:
```swift
            {
                "position": 14,
                "team": { "id": 794, "tla": null, "name": "Bragantino", "crest": "https://media.api-sports.io/football/teams/794.png", "shortName": "Bragantino" },
                "playedGames": 15, "won": 5, "draw": 3, "lost": 7,
                "goalsFor": 14, "goalsAgainst": 20, "goalDifference": -6, "points": 18
            },
```
Replace:
```swift
            {
                "position": 14,
                "team": { "id": 794, "tla": null, "name": "Bragantino", "crest": "https://media.api-sports.io/football/teams/794.png", "shortName": "Bragantino" },
                "playedGames": 15, "won": 5, "draw": 3, "lost": 7,
                "goalsFor": 14, "goalsAgainst": 20, "goalDifference": -6, "points": 18,
                "description": "None"
            },
```

Find:
```swift
            {
                "position": 15,
                "team": { "id": 134, "tla": null, "name": "Athletico-PR", "crest": "https://media.api-sports.io/football/teams/134.png", "shortName": "Athletico-PR" },
                "playedGames": 15, "won": 4, "draw": 5, "lost": 6,
                "goalsFor": 13, "goalsAgainst": 19, "goalDifference": -6, "points": 17
            },
```
Replace:
```swift
            {
                "position": 15,
                "team": { "id": 134, "tla": null, "name": "Athletico-PR", "crest": "https://media.api-sports.io/football/teams/134.png", "shortName": "Athletico-PR" },
                "playedGames": 15, "won": 4, "draw": 5, "lost": 6,
                "goalsFor": 13, "goalsAgainst": 19, "goalDifference": -6, "points": 17,
                "description": "None"
            },
```

Find:
```swift
            {
                "position": 16,
                "team": { "id": 210, "tla": null, "name": "Juventude", "crest": "https://media.api-sports.io/football/teams/210.png", "shortName": "Juventude" },
                "playedGames": 15, "won": 4, "draw": 4, "lost": 7,
                "goalsFor": 13, "goalsAgainst": 21, "goalDifference": -8, "points": 16
            },
```
Replace:
```swift
            {
                "position": 16,
                "team": { "id": 210, "tla": null, "name": "Juventude", "crest": "https://media.api-sports.io/football/teams/210.png", "shortName": "Juventude" },
                "playedGames": 15, "won": 4, "draw": 4, "lost": 7,
                "goalsFor": 13, "goalsAgainst": 21, "goalDifference": -8, "points": 16,
                "description": "None"
            },
```

Find:
```swift
            {
                "position": 17,
                "team": { "id": 211, "tla": null, "name": "Cuiabá", "crest": "https://media.api-sports.io/football/teams/211.png", "shortName": "Cuiabá" },
                "playedGames": 15, "won": 4, "draw": 3, "lost": 8,
                "goalsFor": 12, "goalsAgainst": 22, "goalDifference": -10, "points": 15
            },
```
Replace:
```swift
            {
                "position": 17,
                "team": { "id": 211, "tla": null, "name": "Cuiabá", "crest": "https://media.api-sports.io/football/teams/211.png", "shortName": "Cuiabá" },
                "playedGames": 15, "won": 4, "draw": 3, "lost": 8,
                "goalsFor": 12, "goalsAgainst": 22, "goalDifference": -10, "points": 15,
                "description": "Relegation - Serie B"
            },
```

Find:
```swift
            {
                "position": 18,
                "team": { "id": 136, "tla": null, "name": "Vitória", "crest": "https://media.api-sports.io/football/teams/136.png", "shortName": "Vitória" },
                "playedGames": 15, "won": 3, "draw": 4, "lost": 8,
                "goalsFor": 11, "goalsAgainst": 23, "goalDifference": -12, "points": 13
            },
```
Replace:
```swift
            {
                "position": 18,
                "team": { "id": 136, "tla": null, "name": "Vitória", "crest": "https://media.api-sports.io/football/teams/136.png", "shortName": "Vitória" },
                "playedGames": 15, "won": 3, "draw": 4, "lost": 8,
                "goalsFor": 11, "goalsAgainst": 23, "goalDifference": -12, "points": 13,
                "description": "Relegation - Serie B"
            },
```

Find:
```swift
            {
                "position": 19,
                "team": { "id": 132, "tla": null, "name": "Chapecoense-sc", "crest": "https://media.api-sports.io/football/teams/132.png", "shortName": "Chapecoense-sc" },
                "playedGames": 15, "won": 3, "draw": 3, "lost": 9,
                "goalsFor": 10, "goalsAgainst": 25, "goalDifference": -15, "points": 12
            },
```
Replace:
```swift
            {
                "position": 19,
                "team": { "id": 132, "tla": null, "name": "Chapecoense-sc", "crest": "https://media.api-sports.io/football/teams/132.png", "shortName": "Chapecoense-sc" },
                "playedGames": 15, "won": 3, "draw": 3, "lost": 9,
                "goalsFor": 10, "goalsAgainst": 25, "goalDifference": -15, "points": 12,
                "description": "Relegation - Serie B"
            },
```

Find:
```swift
            {
                "position": 20,
                "team": { "id": 7848, "tla": null, "name": "Mirassol", "crest": "https://media.api-sports.io/football/teams/7848.png", "shortName": "Mirassol" },
                "playedGames": 15, "won": 2, "draw": 4, "lost": 9,
                "goalsFor": 9, "goalsAgainst": 27, "goalDifference": -18, "points": 10
            }
        ]
    }
    """
```
Replace:
```swift
            {
                "position": 20,
                "team": { "id": 7848, "tla": null, "name": "Mirassol", "crest": "https://media.api-sports.io/football/teams/7848.png", "shortName": "Mirassol" },
                "playedGames": 15, "won": 2, "draw": 4, "lost": 9,
                "goalsFor": 9, "goalsAgainst": 27, "goalDifference": -18, "points": 10,
                "description": "Relegation - Serie B"
            }
        ]
    }
    """
```

(Note position 20 has no trailing `,` after its closing `}` — it's the last array element,
identical to the original file's structure — only the `"description"` key and its own
trailing comma-vs-not follow the same in-object-not-last-key-vs-last-key convention as every
other entry above.)

- [ ] **Step 2: Run the tests to verify they pass**

Run: `rm -rf ~/Library/Developer/Xcode/DerivedData/BR2026-* && eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: all tests pass (no new tests in this task — this is sample-data-only; confirms the
mock JSON is still valid and decodes correctly with the new field present on every entry).

- [ ] **Step 3: Commit**

```bash
git add BR2026/MockData/MockDataProvider.swift
git commit -m "Add realistic zone description values to mock standings data"
```

---

### Task 3: View wiring — leading colored bar and legend

**Files:**
- Modify: `BR2026/Views/Standings/StandingsView.swift`
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: `Standing.zone` and `Standing.zoneAccessibilityLabel` from Task 1.

- [ ] **Step 1: Add the leading colored bar to each row**

In `BR2026/Views/Standings/StandingsView.swift`, find:

```swift
        .font(.system(size: rowFontSize, weight: .semibold))
        .monospacedDigit()
        .foregroundStyle(themeTokens.textColor)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(standing.accessibilityLabel)
    }
```

Replace with:

```swift
        .font(.system(size: rowFontSize, weight: .semibold))
        .monospacedDigit()
        .foregroundStyle(themeTokens.textColor)
        .padding(.vertical, 8)
        .overlay(alignment: .leading) {
            if let barColor = zoneBarColor(for: standing.zone) {
                Rectangle()
                    .fill(barColor)
                    .frame(width: 3)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(standing.accessibilityLabel)
    }

    private func zoneBarColor(for zone: StandingZone) -> Color? {
        switch zone {
        case .qualification: return Color(hex: "2dd4bf")
        case .relegation: return Color(hex: "ef4444")
        case .none: return nil
        }
    }
```

- [ ] **Step 2: Add the legend**

Add a new `@ScaledMetric` property to the struct's property list, alongside the existing
two:

```swift
    @ScaledMetric private var columnHeaderFontSize: CGFloat = 11
    @ScaledMetric private var rowFontSize: CGFloat = 14
    @ScaledMetric private var legendFontSize: CGFloat = 11
```

Find:

```swift
                ScrollView {
                    GlassCard(cornerRadius: 24, style: .transparent) {
                        VStack(spacing: 0) {
                            Color.clear.frame(height: 0).id(Self.topAnchor)
                            header
                            ForEach(viewModel.standings, id: \.id) { standing in
                                row(for: standing)
                            }
                        }
                    }
                    .padding(16)
                }
```

Replace with:

```swift
                ScrollView {
                    VStack(spacing: 12) {
                        GlassCard(cornerRadius: 24, style: .transparent) {
                            VStack(spacing: 0) {
                                Color.clear.frame(height: 0).id(Self.topAnchor)
                                header
                                ForEach(viewModel.standings, id: \.id) { standing in
                                    row(for: standing)
                                }
                            }
                        }
                        if viewModel.standings.contains(where: { $0.zone != .none }) {
                            legend
                        }
                    }
                    .padding(16)
                }
```

Then, after the `zoneBarColor(for:)` function added in Step 1, add:

```swift

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: Color(hex: "2dd4bf"), label: String(localized: "Continental qualification", comment: "VoiceOver/legend label for a standings row in a continental-competition qualification position (Champions League, Copa Libertadores, Copa Sudamericana, etc., regardless of which specific competition or stage)."))
            legendItem(color: Color(hex: "ef4444"), label: String(localized: "Relegation zone", comment: "VoiceOver/legend label for a standings row in a relegation position."))
            Spacer()
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: legendFontSize, weight: .semibold))
                .foregroundStyle(themeTokens.textColor.opacity(0.7))
        }
        .accessibilityElement(children: .combine)
    }
```

(The two `String(localized:)` calls here use the exact same literal text as
`Standing.zoneAccessibilityLabel` in Task 1 — they resolve to the same catalog entries
already added in Task 1, Step 7. No new catalog entries needed in this task.)

- [ ] **Step 3: Document the new color in CLAUDE.md**

In `CLAUDE.md`, find:

```
// Status
advance: #2dd4bf   // teal
playoff: #fbbf24   // amber
```

Replace with:

```
// Status
advance: #2dd4bf   // teal
playoff: #fbbf24   // amber
relegation: #ef4444   // red
```

- [ ] **Step 4: Build to verify it compiles**

Run: `rm -rf ~/Library/Developer/Xcode/DerivedData/BR2026-* && xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation clean build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Run the full test suite**

Run: `eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: all existing tests still pass (no new tests in this task — View-layer wiring,
matching this project's established convention).

- [ ] **Step 6: Manual verification**

Run the app against the live API (Brasileirão has real zone data as of this plan's writing)
or the mock data path. Confirm: rows in the Libertadores/Sudamericana qualification range
show a teal leading bar, rows in the relegation range show a red leading bar, mid-table rows
show no bar; the legend appears below the table only when at least one zone marker is
present; VoiceOver reads each marked row's zone as the final clause of its existing spoken
label.

- [ ] **Step 7: Commit**

```bash
git add BR2026/Views/Standings/StandingsView.swift CLAUDE.md
git commit -m "Show relegation/qualification zone markers and a legend in Standings"
```

---

### Task 4: Full 6-target verification

**Files:** None (verification only).

- [ ] **Step 1: Run the full unit + UI test suite (fully clean)**

Run: `rm -rf ~/Library/Developer/Xcode/DerivedData/BR2026-* && eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: all tests pass (existing suite + every test added in Task 1).

- [ ] **Step 2: Build all 6 targets (fully clean)**

Run (repeat for each scheme — `BR2026`, `PremierLeague2026`, `Ligue12026`,
`PrimeiraLiga2026`, `ScottishPremiership2026`, `LaLiga2026`):

```bash
xcodebuild -project BR2026.xcodeproj -scheme <Scheme> -destination 'generic/platform=iOS Simulator' -skipMacroValidation clean build
```

Expected: `** BUILD SUCCEEDED **` for all six. This project has a documented history of a
new shared file/field silently breaking builds for targets beyond `BR2026` (see the Contrast
plan's `WCAGContrast.swift` registration gap, found and fixed 2026-07-17) — this task's own
files (`Standing.swift`, `StandingDTO.swift`, `StandingsView.swift`) are all pre-existing
files modified in place, not new files needing Xcode project registration, so this class of
bug shouldn't apply here, but verify all 6 targets build clean regardless rather than
assuming.

No commit for this task — verification only.

---
