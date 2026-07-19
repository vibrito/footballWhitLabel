# Match Detail: Statistics and Lineups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Statistics and Lineups tabs to `MatchDetailView`, alongside the existing Timeline, using two backend endpoints that already return real data but aren't consumed yet.

**Architecture:** New Model-layer types (`MatchStatistics`, `MatchLineup`/`TeamLineup`/`LineupPlayer`) follow this codebase's existing DTO→model conventions (`Standing`/`StandingDTO` for computed fields, `MatchEvent` for direct-decode-no-DTO where nothing needs computing). `MatchService` gains two lazily-fetched, non-cached methods mirroring `fetchEvents`'s existing precedent. A new `MatchDetailSegment` enum drives a segmented control in `MatchDetailView`, replacing today's unconditional Timeline-only body; `StatisticsView` and `LineupsView` are new self-contained components.

**Tech Stack:** SwiftUI (iOS 26+), Swift Testing, `@Observable`, `@ScaledMetric` for Dynamic Type — same stack as the rest of the app, no new dependencies.

## Global Constraints

- No force-unwraps (`!`) outside of tests (CLAUDE.md).
- `@Observable` over `ObservableObject` (CLAUDE.md).
- All user-facing strings go through `String(localized:)` or a `Text(_:comment:)` literal — no hardcoded English strings in View/ViewModel files (CLAUDE.md).
- Every new `String(localized:)`/`Text(_:comment:)` call site needs entries in all 6 supported locales in `BR2026/Resources/Localizable.xcstrings`: `pt-BR`, `pt-PT`, `fr`, `en-US`, `en-GB`, `es`. Source language is `en` (used for both `en` and `en-GB` unless the wording genuinely differs).
- **Format-specifier safety:** `String(localized:)` string interpolation generates a **bare, type-dependent** format specifier in the catalog **key** (`String` → `%@`, `Int` → `%lld`), with specifiers **repeated verbatim** if the same type appears more than once — **never** write positional `%1$@`/`%2$@` in Swift source or in the catalog key. Positional numbering (`%1$@`, `%2$@`, ...) only ever appears in each locale's translated **value**, and only when that locale's word order needs it. When in doubt, verify a new key's exact expected format with a throwaway script: `swift -e 'import Foundation; dump(String.LocalizationValue("..."))'`.
- Unit test ViewModels, Services, and Models — not Views (CLAUDE.md). No new SwiftUI view tests; `AccessibilityAuditUITests` is the only UI-level coverage this plan touches.
- `MatchStatistics`/`MatchLineup` are **not** SwiftData `@Model` types and are **not** cached — same transient, per-sheet-visit lifecycle as `MatchEvent`/`fetchEvents`, not the persisted matches/standings/competition pattern.
- Reuse `WCAGContrast` (`BR2026/Models/WCAGContrast.swift`) for jersey number legibility — no per-team curated override table (that pattern, `TeamThemeOption`'s curated hexes, only covers BSA's 20 teams and doesn't exist for the other 5 leagues).

---

### Task 1: Data layer — `MatchStatistics`, `MatchLineup` models, `WCAGContrast` extension

**Files:**
- Create: `BR2026/Models/MatchStatistics.swift`
- Create: `BR2026/Models/MatchLineupDTO.swift`
- Create: `BR2026/Models/MatchLineup.swift`
- Modify: `BR2026/Models/WCAGContrast.swift`
- Test: `BR2026Tests/Models/MatchStatisticsTests.swift`
- Test: `BR2026Tests/Models/MatchLineupTests.swift`
- Test: `BR2026Tests/Models/WCAGContrastTests.swift` (add to existing file)

**Interfaces:**
- Produces: `struct MatchStatistics: Decodable { let home: TeamStats; let away: TeamStats }`, `struct TeamStats: Decodable { let fouls, shots, corners, possession, passAccuracy, shotsOnTarget: Int }`.
- Produces: `struct LineupPlayer: Decodable { let name: String; let number: Int; let position: String; let col: Int?; let row: Int? }` with computed `var positionAccessibilityLabel: String`.
- Produces: `struct TeamLineup { let formation: String; let startingXI: [LineupPlayer]; let substitutes: [LineupPlayer]; let kitColorHex: String; let kitFontColorHex: String }`, `struct MatchLineup { let home: TeamLineup; let away: TeamLineup; init(dto: MatchLineupDTO) }`.
- Produces: `WCAGContrast.accessibleColorHex(candidateHex: String, against backgroundHex: String) -> String`.
- Consumed by: Task 2 (service layer decodes `MatchStatistics`/`MatchLineupDTO` directly, maps `MatchLineupDTO` → `MatchLineup`), Task 5/6 (views render these types).

- [ ] **Step 1: Write the failing tests for `WCAGContrast.accessibleColorHex`**

```swift
// Append to BR2026Tests/Models/WCAGContrastTests.swift, inside the existing @Suite struct
    @Test("accessibleColorHex returns the candidate unchanged when it already passes WCAG AA against the background")
    func accessibleColorHexReturnsCandidateWhenPassing() {
        // Fluminense's real away-kit-vs-shirt case: white number on grenat shirt, real API data.
        #expect(WCAGContrast.accessibleColorHex(candidateHex: "FFFFFF", against: "6E202E") == "FFFFFF")
    }

    @Test("accessibleColorHex falls back to whichever of black/white contrasts better when the candidate fails")
    func accessibleColorHexFallsBackWhenFailing() {
        // Real API data: Botafogo's home lineup response gave fontColor ffffff against
        // mainColor f7f7f7 (near-white on near-white) — the exact case this exists to fix.
        let result = WCAGContrast.accessibleColorHex(candidateHex: "FFFFFF", against: "F7F7F7")
        #expect(result == "000000")
    }

    @Test("accessibleColorHex picks white when black would contrast worse against a dark background")
    func accessibleColorHexPicksWhiteAgainstDarkBackground() {
        let result = WCAGContrast.accessibleColorHex(candidateHex: "111111", against: "000000")
        #expect(result == "FFFFFF")
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BR2026Tests/WCAGContrastTests`
Expected: FAIL — `accessibleColorHex` doesn't exist yet (build error).

- [ ] **Step 3: Add `accessibleColorHex` to `WCAGContrast.swift`**

```swift
// Add inside the WCAGContrast enum, after contrastRatio(_:_:)
    /// WCAG AA's minimum contrast ratio for normal text — same threshold `ThemeTokens.
    /// accessibleFontColorHex` already uses.
    private static let minimumContrastRatio = 4.5

    /// Validates `candidateHex` (e.g. a jersey number's color) against a single
    /// `backgroundHex` it's drawn directly on top of (e.g. that jersey's own fill) — a
    /// one-surface simplification of `ThemeTokens.accessibleFontColorHex`'s two-surface
    /// check, for callers (like match-lineup kit colors) with only one background to
    /// validate against. Returns `candidateHex` unchanged if it already passes; otherwise
    /// returns whichever of pure white or pure black contrasts better against
    /// `backgroundHex`.
    static func accessibleColorHex(candidateHex: String, against backgroundHex: String) -> String {
        guard contrastRatio(candidateHex, backgroundHex) < minimumContrastRatio else { return candidateHex }
        let whiteRatio = contrastRatio("FFFFFF", backgroundHex)
        let blackRatio = contrastRatio("000000", backgroundHex)
        return whiteRatio >= blackRatio ? "FFFFFF" : "000000"
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BR2026Tests/WCAGContrastTests`
Expected: PASS

- [ ] **Step 5: Write the failing tests for `MatchStatistics`**

```swift
// BR2026Tests/Models/MatchStatisticsTests.swift
import Testing
import Foundation
@testable import BR2026

@Suite("MatchStatistics decoding")
struct MatchStatisticsTests {
    @Test("Decodes match statistics from real-shaped API JSON")
    func decodesStatistics() throws {
        // Real response for BSA match 1492291 (Botafogo vs Santos, round 19).
        let json = Data("""
        {
            "home": { "fouls": 10, "shots": 17, "corners": 5, "possession": 48, "passAccuracy": 81, "shotsOnTarget": 7 },
            "away": { "fouls": 13, "shots": 22, "corners": 5, "possession": 52, "passAccuracy": 79, "shotsOnTarget": 9 }
        }
        """.utf8)
        let stats = try JSONDecoder().decode(MatchStatistics.self, from: json)
        #expect(stats.home.fouls == 10)
        #expect(stats.home.possession == 48)
        #expect(stats.away.shotsOnTarget == 9)
    }
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BR2026Tests/MatchStatisticsTests`
Expected: FAIL — `MatchStatistics` doesn't exist yet.

- [ ] **Step 7: Create `MatchStatistics.swift`**

```swift
// BR2026/Models/MatchStatistics.swift
import Foundation

/// Per-team match statistics. Fetched once per match-detail Stats tab selection — not
/// persisted, and not partially updated like `Match` (mirrors `MatchEvent`'s lifecycle:
/// no SwiftData caching, no DTO layer needed since every field decodes directly with no
/// computation required).
struct TeamStats: Decodable {
    let fouls: Int
    let shots: Int
    let corners: Int
    let possession: Int
    let passAccuracy: Int
    let shotsOnTarget: Int

    /// The API always returns HTTP 200 with this shape, even for a match that hasn't
    /// started yet — as a block of zeros, never an omitted/null response (confirmed
    /// directly against the live backend: `GET .../matches/{scheduled-match-id}/statistics`
    /// returns `{"fouls":0,"shots":0,...}` for both teams, not 404 or an empty body).
    /// `LiveMatchService.fetchMatchStatistics` uses this to decide when to surface `nil`
    /// ("not yet available") instead of a real-but-empty `MatchStatistics`.
    var hasAnyValue: Bool {
        fouls != 0 || shots != 0 || corners != 0 || possession != 0 || passAccuracy != 0 || shotsOnTarget != 0
    }
}

struct MatchStatistics: Decodable {
    let home: TeamStats
    let away: TeamStats
}
```

- [ ] **Step 8: Run test to verify it passes**

Run: `xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BR2026Tests/MatchStatisticsTests`
Expected: PASS

- [ ] **Step 9: Write the failing tests for `MatchLineup`**

```swift
// BR2026Tests/Models/MatchLineupTests.swift
import Testing
import Foundation
@testable import BR2026

@Suite("MatchLineup decoding and mapping")
struct MatchLineupTests {
    // Real response for BSA match 1492295 (Fluminense vs RB Bragantino, round 19) — chosen
    // because the two teams' real kit colors are visually distinct and don't need the
    // WCAG-correction fallback, unlike Botafogo/Santos (covered by the next test).
    private let fluminenseVsBragantinoJSON = Data("""
    {
        "home": {
            "colors": { "fontColor": "ffffff", "mainColor": "6e202e", "secondaryColor": "6e202e" },
            "formation": "4-2-3-1",
            "startingXI": [
                { "col": 1, "row": 1, "name": "Fábio", "number": 1, "position": "G" },
                { "col": 1, "row": 5, "name": "Hulk", "number": 7, "position": "F" }
            ],
            "substitutes": [
                { "name": "Backup GK", "number": 12, "position": "G" }
            ]
        },
        "away": {
            "colors": { "fontColor": "f50000", "mainColor": "fcfcfc", "secondaryColor": "fcfcfc" },
            "formation": "4-1-4-1",
            "startingXI": [
                { "col": 1, "row": 1, "name": "Tiago Volpi", "number": 18, "position": "G" }
            ],
            "substitutes": []
        }
    }
    """.utf8)

    @Test("Decodes a lineups response and maps it to the display model")
    func decodesAndMaps() throws {
        let dto = try JSONDecoder().decode(MatchLineupDTO.self, from: fluminenseVsBragantinoJSON)
        let lineup = MatchLineup(dto: dto)

        #expect(lineup.home.formation == "4-2-3-1")
        #expect(lineup.home.startingXI.count == 2)
        #expect(lineup.home.startingXI[0].name == "Fábio")
        #expect(lineup.home.startingXI[0].col == 1)
        #expect(lineup.home.startingXI[0].row == 1)
        #expect(lineup.home.substitutes.count == 1)
        #expect(lineup.home.substitutes[0].col == nil)
        #expect(lineup.home.substitutes[0].row == nil)
    }

    @Test("A passing kit color pair is used unchanged; a failing one is corrected")
    func kitColorsCorrectOnlyWhenFailing() throws {
        let dto = try JSONDecoder().decode(MatchLineupDTO.self, from: fluminenseVsBragantinoJSON)
        let lineup = MatchLineup(dto: dto)

        // Fluminense: white on grenat, 11.0:1 — passes, unchanged.
        #expect(lineup.home.kitColorHex == "6e202e")
        #expect(lineup.home.kitFontColorHex == "ffffff")
        // Bragantino: red f50000 on white fcfcfc is only 4.19:1 — verified below the 4.5
        // WCAG AA threshold despite looking reasonable, so it's corrected to black
        // (20.5:1) rather than kept as the real API value. A useful reminder that "looks
        // fine" and "passes WCAG AA" aren't the same thing — always compute the ratio
        // rather than eyeballing a color pair, including during this feature's own design.
        #expect(lineup.away.kitColorHex == "fcfcfc")
        #expect(lineup.away.kitFontColorHex == "000000")
    }

    @Test("Kit font color is corrected when the real API value fails WCAG AA against the kit color")
    func kitFontColorCorrectedWhenFailing() throws {
        // Real response for BSA match 1492291 (Botafogo vs Santos): fontColor ffffff
        // against mainColor f7f7f7 — near-white on near-white, fails WCAG AA.
        let json = Data("""
        {
            "home": {
                "colors": { "fontColor": "ffffff", "mainColor": "f7f7f7", "secondaryColor": "f7f7f7" },
                "formation": "4-4-2",
                "startingXI": [ { "col": 1, "row": 1, "name": "Léo Linck", "number": 24, "position": "G" } ],
                "substitutes": []
            },
            "away": {
                "colors": { "fontColor": "000000", "mainColor": "ffffff", "secondaryColor": "ffffff" },
                "formation": "4-2-3-1",
                "startingXI": [ { "col": 1, "row": 1, "name": "Gabriel Brazão", "number": 77, "position": "G" } ],
                "substitutes": []
            }
        }
        """.utf8)
        let dto = try JSONDecoder().decode(MatchLineupDTO.self, from: json)
        let lineup = MatchLineup(dto: dto)

        #expect(lineup.home.kitFontColorHex == "000000")
        // Away's real values (black on white) already pass — unchanged.
        #expect(lineup.away.kitFontColorHex == "000000")
    }

    @Test("Decodes a scheduled match's empty placeholder lineups response without crashing")
    func decodesScheduledMatchPlaceholderResponse() throws {
        // Real response for a not-yet-played BSA match: HTTP 200, empty formation/players,
        // and critically `"colors": null` — not omitted, not a 404. Confirmed directly
        // against the live backend.
        let json = Data("""
        {
            "home": { "formation": "", "startingXI": [], "substitutes": [], "colors": null },
            "away": { "formation": "", "startingXI": [], "substitutes": [], "colors": null }
        }
        """.utf8)
        let dto = try JSONDecoder().decode(MatchLineupDTO.self, from: json)
        let lineup = MatchLineup(dto: dto)

        #expect(lineup.home.startingXI.isEmpty)
        #expect(lineup.home.kitColorHex == "808080")
        // The "FFFFFF" fallback font candidate actually fails WCAG AA against the "808080"
        // fallback main color (3.95:1, below the 4.5 threshold — verified directly), so
        // accessibleColorHex corrects it to black (5.32:1) — exercising the same
        // correction path a real near-invisible per-match kit color would take.
        #expect(lineup.home.kitFontColorHex == "000000")
    }

    @Test("LineupPlayer's position letter maps to a full localized word")
    func positionAccessibilityLabels() {
        let goalkeeper = LineupPlayer(name: "Test", number: 1, position: "G", col: 1, row: 1)
        let defender = LineupPlayer(name: "Test", number: 2, position: "D", col: 1, row: 2)
        let midfielder = LineupPlayer(name: "Test", number: 3, position: "M", col: 1, row: 3)
        let forward = LineupPlayer(name: "Test", number: 4, position: "F", col: 1, row: 4)

        #expect(goalkeeper.positionAccessibilityLabel == "Goalkeeper")
        #expect(defender.positionAccessibilityLabel == "Defender")
        #expect(midfielder.positionAccessibilityLabel == "Midfielder")
        #expect(forward.positionAccessibilityLabel == "Forward")
    }
}
```

- [ ] **Step 10: Run tests to verify they fail**

Run: `xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BR2026Tests/MatchLineupTests`
Expected: FAIL — `MatchLineupDTO`/`MatchLineup`/`LineupPlayer` don't exist yet.

- [ ] **Step 11: Create `MatchLineupDTO.swift`**

```swift
// BR2026/Models/MatchLineupDTO.swift
import Foundation

struct LineupColorsDTO: Decodable {
    let fontColor: String
    let mainColor: String
    let secondaryColor: String
}

struct TeamLineupDTO: Decodable {
    // Optional: a scheduled match's lineups response returns `"colors": null` (confirmed
    // directly against the live backend) alongside an empty formation/startingXI — there's
    // no real kit to report yet. `MatchLineup.map(_:)` supplies a neutral fallback when nil.
    let colors: LineupColorsDTO?
    let formation: String
    let startingXI: [LineupPlayer]
    let substitutes: [LineupPlayer]
}

struct MatchLineupDTO: Decodable {
    let home: TeamLineupDTO
    let away: TeamLineupDTO
}
```

- [ ] **Step 12: Create `MatchLineup.swift`**

```swift
// BR2026/Models/MatchLineup.swift
import Foundation

/// A single player in a lineup. Used directly as the `Decodable` target for both
/// `startingXI` (which has `col`/`row`) and `substitutes` (which doesn't) — Swift's
/// synthesized `Decodable` conformance already decodes an `Optional` property as `nil`
/// when its key is absent, so one type covers both API shapes with no separate DTO.
struct LineupPlayer: Decodable, Equatable {
    let name: String
    let number: Int
    let position: String   // "G" / "D" / "M" / "F"
    let col: Int?           // nil for substitutes
    let row: Int?           // nil for substitutes

    /// The API's bare position letter, spelled out for VoiceOver — mirrors
    /// `Standing.zoneAccessibilityLabel`'s pattern of never speaking a raw abbreviation.
    var positionAccessibilityLabel: String {
        switch position {
        case "G": String(localized: "Goalkeeper", comment: "VoiceOver: full word for a lineup player's position, abbreviated \"G\" by the API.")
        case "D": String(localized: "Defender", comment: "VoiceOver: full word for a lineup player's position, abbreviated \"D\" by the API.")
        case "M": String(localized: "Midfielder", comment: "VoiceOver: full word for a lineup player's position, abbreviated \"M\" by the API.")
        case "F": String(localized: "Forward", comment: "VoiceOver: full word for a lineup player's position, abbreviated \"F\" by the API.")
        default: position
        }
    }
}

/// One team's lineup. `kitColorHex`/`kitFontColorHex` are this specific match's actual
/// kit colors (distinct from `TeamThemeColorSet`'s generic per-team brand colors) — real,
/// live, per-match values that sometimes need correcting (see `MatchLineup.init(dto:)`).
struct TeamLineup {
    let formation: String
    let startingXI: [LineupPlayer]
    let substitutes: [LineupPlayer]
    let kitColorHex: String
    let kitFontColorHex: String
}

struct MatchLineup {
    let home: TeamLineup
    let away: TeamLineup

    init(dto: MatchLineupDTO) {
        home = Self.map(dto.home)
        away = Self.map(dto.away)
    }

    /// Real per-match kit colors sometimes fail to contrast with each other (confirmed
    /// directly against the live API: Botafogo's lineup response gave `fontColor: ffffff`
    /// against `mainColor: f7f7f7`, near-white on near-white) — corrected via the same
    /// "validate the real value, fall back to black/white only on failure" pattern already
    /// established for Team Theme colors (`ThemeTokens.accessibleFontColorHex`), not a
    /// per-team curated override table (which wouldn't exist for the other 5 leagues).
    /// `dto.colors` is nil for a scheduled match's still-empty lineup (see
    /// `TeamLineupDTO`'s doc comment) — `startingXI` is empty in that case too, so no
    /// jersey ever actually renders with the neutral gray/white fallback; the fallback
    /// only needs to be a valid, non-crashing pair of hex strings, not a meaningful color.
    private static func map(_ dto: TeamLineupDTO) -> TeamLineup {
        let mainColorHex = dto.colors?.mainColor ?? "808080"
        let fontColorHex = dto.colors?.fontColor ?? "FFFFFF"
        return TeamLineup(
            formation: dto.formation,
            startingXI: dto.startingXI,
            substitutes: dto.substitutes,
            kitColorHex: mainColorHex,
            kitFontColorHex: WCAGContrast.accessibleColorHex(candidateHex: fontColorHex, against: mainColorHex)
        )
    }
}
```

- [ ] **Step 13: Run tests to verify they pass**

Run: `xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BR2026Tests/MatchLineupTests`
Expected: PASS

- [ ] **Step 14: Add the 4 position-word localized strings**

Run this script (adjust nothing — it inserts real, complete translations for all 6 locales):

```bash
python3 << 'EOF'
import json

path = "BR2026/Resources/Localizable.xcstrings"
with open(path, encoding="utf-8") as f:
    data = json.load(f)

def entry(comment, values):
    return {
        "extractionState": "manual",
        "comment": comment,
        "localizations": {
            locale: {"stringUnit": {"state": "translated", "value": value}}
            for locale, value in values.items()
        }
    }

new_strings = {
    "Goalkeeper": entry(
        "VoiceOver: full word for a lineup player's position, abbreviated \"G\" by the API.",
        {"en": "Goalkeeper", "en-GB": "Goalkeeper", "es": "Portero", "fr": "Gardien", "pt-BR": "Goleiro", "pt-PT": "Guarda-redes"}
    ),
    "Defender": entry(
        "VoiceOver: full word for a lineup player's position, abbreviated \"D\" by the API.",
        {"en": "Defender", "en-GB": "Defender", "es": "Defensa", "fr": "Défenseur", "pt-BR": "Defensor", "pt-PT": "Defesa"}
    ),
    "Midfielder": entry(
        "VoiceOver: full word for a lineup player's position, abbreviated \"M\" by the API.",
        {"en": "Midfielder", "en-GB": "Midfielder", "es": "Centrocampista", "fr": "Milieu", "pt-BR": "Meio-campista", "pt-PT": "Médio"}
    ),
    "Forward": entry(
        "VoiceOver: full word for a lineup player's position, abbreviated \"F\" by the API.",
        {"en": "Forward", "en-GB": "Forward", "es": "Delantero", "fr": "Attaquant", "pt-BR": "Atacante", "pt-PT": "Avançado"}
    ),
}

for key, value in new_strings.items():
    if key in data["strings"]:
        raise SystemExit(f"Key already exists, aborting: {key}")
    data["strings"][key] = value

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2, sort_keys=True)
    f.write("\n")
EOF
```

- [ ] **Step 15: Verify the script's format-specifier safety and JSON validity**

Run: `python3 -c "import json; json.load(open('BR2026/Resources/Localizable.xcstrings'))" && echo "valid JSON"`
Expected: `valid JSON` (none of the 4 new strings interpolate any arguments, so there's no format-specifier risk to verify here — this step only confirms the script didn't corrupt the file).

- [ ] **Step 16: Build and run the full test suite**

Run: `xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `** BUILD SUCCEEDED **`

Run: `xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BR2026Tests`
Expected: All tests pass, including the new `WCAGContrastTests`/`MatchStatisticsTests`/`MatchLineupTests` cases.

- [ ] **Step 17: Commit**

```bash
git add BR2026/Models/MatchStatistics.swift BR2026/Models/MatchLineupDTO.swift BR2026/Models/MatchLineup.swift BR2026/Models/WCAGContrast.swift BR2026/Resources/Localizable.xcstrings BR2026Tests/Models/MatchStatisticsTests.swift BR2026Tests/Models/MatchLineupTests.swift BR2026Tests/Models/WCAGContrastTests.swift
git commit -m "Add MatchStatistics/MatchLineup models with WCAG-corrected kit colors"
```

---

### Task 2: Service layer — `MatchService` protocol, `LiveMatchService`, `MockMatchService`

**Files:**
- Modify: `BR2026/Services/MatchService.swift`
- Modify: `BR2026/Services/LiveMatchService.swift`
- Modify: `BR2026/Services/MockMatchService.swift`
- Modify: `BR2026/MockData/MockDataProvider.swift`
- Modify: `BR2026Tests/ViewModels/MatchdayViewModelTests.swift` (shared `StubMatchService`)
- Test: `BR2026Tests/Services/MockMatchServiceTests.swift` (add to existing file if present, else create)

**Interfaces:**
- Consumes: `MatchStatistics`, `MatchLineupDTO`, `MatchLineup` from Task 1.
- Produces: `MatchService.fetchMatchStatistics(matchID: Int) async throws -> MatchStatistics?`, `MatchService.fetchMatchLineups(matchID: Int) async throws -> MatchLineup?`.
- Consumed by: Task 3 (`MatchDetailViewModel` calls these two methods).

- [ ] **Step 1: Check for an existing `MockMatchServiceTests.swift`**

Run: `find BR2026Tests -iname "MockMatchServiceTests.swift"`

If it exists, add the two tests from Step 6 below into its existing `@Suite`. If it doesn't, create it fresh with the full file shown in Step 6.

- [ ] **Step 2: Add the two methods to the `MatchService` protocol**

```swift
// BR2026/Services/MatchService.swift — add these two lines inside the protocol, after fetchEvents
    /// Returns match statistics, or nil if not yet available (e.g. the match hasn't
    /// started). Not cached — same transient, per-sheet-visit lifecycle as fetchEvents.
    func fetchMatchStatistics(matchID: Int) async throws -> MatchStatistics?
    /// Returns both teams' lineups, or nil if not yet published. Not cached — same
    /// transient, per-sheet-visit lifecycle as fetchEvents.
    func fetchMatchLineups(matchID: Int) async throws -> MatchLineup?
```

- [ ] **Step 3: Implement both methods in `LiveMatchService`**

The backend was confirmed directly to **always** return HTTP 200 for these two endpoints, even for a match that hasn't started — never a 404 or an omitted body. A scheduled match's statistics come back as a block of zeros (`{"fouls":0,"shots":0,...}` for both teams); its lineups come back with `formation: ""`, empty `startingXI`/`substitutes` arrays, and `colors: null`. So `nil` (not yet available) has to be detected from the decoded *content*, not from decode failure or an HTTP status — and a genuine network/decode failure should still propagate as a thrown error (`try`, not `try?`), matching the confirmed design: `nil` is an expected, normal state distinct from a real failure.

```swift
// BR2026/Services/LiveMatchService.swift — add after fetchEvents(matchID:)
    func fetchMatchStatistics(matchID: Int) async throws -> MatchStatistics? {
        let url = config.apiBaseURL
            .appendingPathComponent("v4/competitions/\(config.competitionCode)/matches/\(matchID)/statistics")
        let statistics: MatchStatistics = try await get(url)
        guard statistics.home.hasAnyValue || statistics.away.hasAnyValue else { return nil }
        return statistics
    }

    func fetchMatchLineups(matchID: Int) async throws -> MatchLineup? {
        let url = config.apiBaseURL
            .appendingPathComponent("v4/competitions/\(config.competitionCode)/matches/\(matchID)/lineups")
        let dto: MatchLineupDTO = try await get(url)
        guard !dto.home.startingXI.isEmpty || !dto.away.startingXI.isEmpty else { return nil }
        return MatchLineup(dto: dto)
    }
```

- [ ] **Step 4: Add mock fixture JSON to `MockDataProvider.swift`**

```swift
// BR2026/MockData/MockDataProvider.swift — add after eventsJSON
    static let statisticsJSON = """
    {
        "home": { "fouls": 10, "shots": 17, "corners": 5, "possession": 48, "passAccuracy": 81, "shotsOnTarget": 7 },
        "away": { "fouls": 13, "shots": 22, "corners": 5, "possession": 52, "passAccuracy": 79, "shotsOnTarget": 9 }
    }
    """

    static let lineupsJSON = """
    {
        "home": {
            "colors": { "fontColor": "ffffff", "mainColor": "1e1e20", "secondaryColor": "1e1e20" },
            "formation": "4-4-2",
            "startingXI": [
                { "col": 1, "row": 1, "name": "Léo Linck", "number": 24, "position": "G" },
                { "col": 4, "row": 2, "name": "Vitinho", "number": 2, "position": "D" },
                { "col": 3, "row": 2, "name": "Gabriel Justino", "number": 34, "position": "D" },
                { "col": 2, "row": 2, "name": "Nahuel Ferraresi", "number": 5, "position": "D" },
                { "col": 1, "row": 2, "name": "Alex Telles", "number": 13, "position": "D" },
                { "col": 4, "row": 3, "name": "Lucas Villalba", "number": 77, "position": "M" },
                { "col": 3, "row": 3, "name": "Huguinho", "number": 75, "position": "M" },
                { "col": 2, "row": 3, "name": "Marlon Freitas", "number": 8, "position": "M" },
                { "col": 1, "row": 3, "name": "Allan", "number": 14, "position": "M" },
                { "col": 2, "row": 4, "name": "Chris Ramos", "number": 19, "position": "F" },
                { "col": 1, "row": 4, "name": "Igor Jesus", "number": 9, "position": "F" }
            ],
            "substitutes": [
                { "name": "Diogenes", "number": 1, "position": "G" },
                { "name": "Adonis Frías", "number": 98, "position": "D" },
                { "name": "Gabriel Menino", "number": 25, "position": "M" }
            ]
        },
        "away": {
            "colors": { "fontColor": "000000", "mainColor": "ffffff", "secondaryColor": "ffffff" },
            "formation": "4-2-3-1",
            "startingXI": [
                { "col": 1, "row": 1, "name": "Gabriel Brazão", "number": 77, "position": "G" },
                { "col": 4, "row": 2, "name": "Igor Vinícius", "number": 18, "position": "D" },
                { "col": 3, "row": 2, "name": "Lucas Veríssimo", "number": 4, "position": "D" },
                { "col": 2, "row": 2, "name": "Luan Peres", "number": 14, "position": "D" },
                { "col": 1, "row": 2, "name": "Gonzalo Escobar", "number": 31, "position": "D" },
                { "col": 2, "row": 3, "name": "Gustavo Henrique Pereira", "number": 48, "position": "M" },
                { "col": 1, "row": 3, "name": "Willian Arão", "number": 15, "position": "M" },
                { "col": 3, "row": 4, "name": "Miguelito", "number": 30, "position": "M" },
                { "col": 2, "row": 4, "name": "Benjamín Rollheiser", "number": 32, "position": "M" },
                { "col": 1, "row": 4, "name": "Álvaro Barreal", "number": 22, "position": "M" },
                { "col": 1, "row": 5, "name": "Thaciano", "number": 16, "position": "F" }
            ],
            "substitutes": [
                { "name": "João Paulo Ananias", "number": 26, "position": "D" },
                { "name": "Rony", "number": 11, "position": "F" }
            ]
        }
    }
    """
```

- [ ] **Step 5: Wire fixtures into `MockMatchService`**

```swift
// BR2026/Services/MockMatchService.swift — modify the init() and add two stored properties + two methods
```

Change the class's stored properties (add two after `private let events: [MatchEvent]`):

```swift
    private let events: [MatchEvent]
    private let statistics: MatchStatistics?
    private let lineups: MatchLineup?
```

Change `init()` — add after `let eventsResponse = try? decoder.decode(MatchEventsResponse.self, from: eventsData)`:

```swift
        let statisticsData = Data(MockDataProvider.statisticsJSON.utf8)
        let lineupsData = Data(MockDataProvider.lineupsJSON.utf8)
```

And after `self.events = eventsResponse?.events ?? []`:

```swift
        self.statistics = try? decoder.decode(MatchStatistics.self, from: statisticsData)
        if let lineupsDTO = try? decoder.decode(MatchLineupDTO.self, from: lineupsData) {
            self.lineups = MatchLineup(dto: lineupsDTO)
        } else {
            self.lineups = nil
        }
```

Add after `func fetchEvents(matchID: Int) async throws -> [MatchEvent] { events }`:

```swift
    func fetchMatchStatistics(matchID: Int) async throws -> MatchStatistics? { statistics }
    func fetchMatchLineups(matchID: Int) async throws -> MatchLineup? { lineups }
```

- [ ] **Step 6: Add `MockMatchService` fetch tests**

```swift
// BR2026Tests/Services/MockMatchServiceTests.swift
// If the file already exists, add these two @Test funcs inside its existing @Suite struct
// instead of creating this whole file.
import Testing
@testable import BR2026

@Suite("MockMatchService")
struct MockMatchServiceTests {
    @Test("fetchMatchStatistics returns real-shaped mock statistics")
    func fetchMatchStatisticsReturnsRealShapedData() async throws {
        let service = MockMatchService()
        let statistics = try await service.fetchMatchStatistics(matchID: 1)
        #expect(statistics?.home.possession == 48)
        #expect(statistics?.away.possession == 52)
    }

    @Test("fetchMatchLineups returns real-shaped mock lineups with WCAG-safe kit colors")
    func fetchMatchLineupsReturnsRealShapedData() async throws {
        let service = MockMatchService()
        let lineups = try await service.fetchMatchLineups(matchID: 1)
        #expect(lineups?.home.formation == "4-4-2")
        #expect(lineups?.home.startingXI.count == 11)
        #expect(lineups?.home.substitutes.count == 3)
        #expect(lineups?.home.substitutes.first?.row == nil)
    }
}
```

- [ ] **Step 7: Update the shared `StubMatchService` (used by `MatchDetailViewModelTests` and others)**

```swift
// BR2026Tests/ViewModels/MatchdayViewModelTests.swift — modify the StubMatchService class
```

Add two stored properties after `let events: [MatchEvent]`:

```swift
    var statisticsOverride: MatchStatistics?
    var lineupsOverride: MatchLineup?
```

Add two methods after `func fetchEvents(matchID: Int) async throws -> [MatchEvent] { ... }`:

```swift
    func fetchMatchStatistics(matchID: Int) async throws -> MatchStatistics? {
        if shouldThrowOnFetch { throw StubServiceError.simulatedFailure }
        return statisticsOverride
    }

    func fetchMatchLineups(matchID: Int) async throws -> MatchLineup? {
        if shouldThrowOnFetch { throw StubServiceError.simulatedFailure }
        return lineupsOverride
    }
```

- [ ] **Step 8: Build and run the full test suite**

Run: `xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `** BUILD SUCCEEDED **`

Run: `xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BR2026Tests`
Expected: All tests pass, including the two new `MockMatchServiceTests` cases. Every other test file that references `StubMatchService` must still compile and pass unchanged — the two new properties both default to `nil`, so existing tests that never set them keep their prior behavior (`fetchMatchStatistics`/`fetchMatchLineups` returning `nil` unless a test opts in).

- [ ] **Step 9: Commit**

```bash
git add BR2026/Services/MatchService.swift BR2026/Services/LiveMatchService.swift BR2026/Services/MockMatchService.swift BR2026/MockData/MockDataProvider.swift BR2026Tests/ViewModels/MatchdayViewModelTests.swift BR2026Tests/Services/MockMatchServiceTests.swift
git commit -m "Wire statistics/lineups endpoints into MatchService, LiveMatchService, MockMatchService"
```

---

### Task 3: `MatchDetailViewModel` lazy loading

**Files:**
- Modify: `BR2026/ViewModels/MatchDetailViewModel.swift`
- Test: `BR2026Tests/ViewModels/MatchDetailViewModelTests.swift`

**Interfaces:**
- Consumes: `MatchService.fetchMatchStatistics(matchID:)`/`fetchMatchLineups(matchID:)` from Task 2.
- Produces: `MatchDetailViewModel.statistics: MatchStatistics?`, `.lineups: MatchLineup?`, `.loadStatisticsIfNeeded() async`, `.loadLineupsIfNeeded() async`, `enum MatchDetailSegment: CaseIterable { case timeline, stats, lineups }`, `.selectedSegment: MatchDetailSegment`.
- Consumed by: Task 4 (segmented control binds to `selectedSegment`, triggers the two `loadIfNeeded` methods), Task 5/6 (views read `.statistics`/`.lineups`).

- [ ] **Step 1: Write the failing tests**

```swift
// Add to BR2026Tests/ViewModels/MatchDetailViewModelTests.swift, inside the existing @Suite struct
    @Test("selectedSegment defaults to .timeline")
    func selectedSegmentDefaultsToTimeline() {
        let match = Match(
            id: 42, utcDate: Date(), status: .finished, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 2, awayScore: 1, winner: "HOME_TEAM", venue: nil, minute: 90
        )
        let service = StubMatchService(matches: [match], standings: [])
        let viewModel = MatchDetailViewModel(match: match, service: service)

        #expect(viewModel.selectedSegment == .timeline)
    }

    @Test("loadStatisticsIfNeeded() fetches statistics for the given match ID")
    func loadStatisticsIfNeededFetchesStatistics() async {
        let match = Match(
            id: 42, utcDate: Date(), status: .finished, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 2, awayScore: 1, winner: "HOME_TEAM", venue: nil, minute: 90
        )
        let stats = MatchStatistics(
            home: TeamStats(fouls: 10, shots: 17, corners: 5, possession: 48, passAccuracy: 81, shotsOnTarget: 7),
            away: TeamStats(fouls: 13, shots: 22, corners: 5, possession: 52, passAccuracy: 79, shotsOnTarget: 9)
        )
        let service = StubMatchService(matches: [match], standings: [])
        service.statisticsOverride = stats
        let viewModel = MatchDetailViewModel(match: match, service: service)

        await viewModel.loadStatisticsIfNeeded()

        #expect(viewModel.statistics?.home.possession == 48)
    }

    @Test("loadStatisticsIfNeeded() is a no-op on a second call")
    func loadStatisticsIfNeededIsNoOpOnSecondCall() async {
        let match = Match(
            id: 42, utcDate: Date(), status: .finished, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 2, awayScore: 1, winner: "HOME_TEAM", venue: nil, minute: 90
        )
        let stats = MatchStatistics(
            home: TeamStats(fouls: 10, shots: 17, corners: 5, possession: 48, passAccuracy: 81, shotsOnTarget: 7),
            away: TeamStats(fouls: 13, shots: 22, corners: 5, possession: 52, passAccuracy: 79, shotsOnTarget: 9)
        )
        let service = StubMatchService(matches: [match], standings: [])
        service.statisticsOverride = stats
        let viewModel = MatchDetailViewModel(match: match, service: service)

        await viewModel.loadStatisticsIfNeeded()
        service.statisticsOverride = nil
        await viewModel.loadStatisticsIfNeeded()

        // Still the first-loaded value — the second call never re-fetched.
        #expect(viewModel.statistics?.home.possession == 48)
    }

    @Test("loadLineupsIfNeeded() fetches lineups for the given match ID")
    func loadLineupsIfNeededFetchesLineups() async {
        let match = Match(
            id: 42, utcDate: Date(), status: .finished, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 2, awayScore: 1, winner: "HOME_TEAM", venue: nil, minute: 90
        )
        let lineup = MatchLineup(dto: try! JSONDecoder().decode(MatchLineupDTO.self, from: Data("""
        {
            "home": { "colors": { "fontColor": "ffffff", "mainColor": "6e202e", "secondaryColor": "6e202e" }, "formation": "4-2-3-1", "startingXI": [], "substitutes": [] },
            "away": { "colors": { "fontColor": "f50000", "mainColor": "fcfcfc", "secondaryColor": "fcfcfc" }, "formation": "4-1-4-1", "startingXI": [], "substitutes": [] }
        }
        """.utf8)))
        let service = StubMatchService(matches: [match], standings: [])
        service.lineupsOverride = lineup
        let viewModel = MatchDetailViewModel(match: match, service: service)

        await viewModel.loadLineupsIfNeeded()

        #expect(viewModel.lineups?.home.formation == "4-2-3-1")
    }

    @Test("statistics and lineups are nil before either load method runs")
    func statisticsAndLineupsNilBeforeLoad() {
        let match = Match(
            id: 42, utcDate: Date(), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [match], standings: [])
        let viewModel = MatchDetailViewModel(match: match, service: service)

        #expect(viewModel.statistics == nil)
        #expect(viewModel.lineups == nil)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BR2026Tests/MatchDetailViewModelTests`
Expected: FAIL — `selectedSegment`/`loadStatisticsIfNeeded`/`loadLineupsIfNeeded`/`statistics`/`lineups` don't exist yet.

- [ ] **Step 3: Add the segment enum, properties, and load methods to `MatchDetailViewModel`**

```swift
// BR2026/ViewModels/MatchDetailViewModel.swift — full new file content
import Foundation
import Observation

enum MatchDetailSegment: CaseIterable {
    case timeline
    case stats
    case lineups
}

@Observable
@MainActor
final class MatchDetailViewModel {
    let match: Match
    private(set) var events: [MatchEvent] = []
    private(set) var statistics: MatchStatistics?
    private(set) var lineups: MatchLineup?
    private(set) var isLoading = false
    var selectedSegment: MatchDetailSegment = .timeline
    private var hasLoadedStatistics = false
    private var hasLoadedLineups = false
    private nonisolated(unsafe) let service: MatchService

    init(match: Match, service: MatchService) {
        self.match = match
        self.service = service
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        if let fresh = try? await service.fetchEvents(matchID: match.id) {
            events = fresh
        }
    }

    var isLive: Bool {
        match.status.isLiveOrHalftime
    }

    func pollWhileLive() async {
        await LivePoller.run(interval: .seconds(30), shouldContinue: { isLive }, action: { await load() })
    }

    // Guarded the same way selectRoundIfNeeded() guards FixturesViewModel's round
    // auto-selection — the segmented control's onChange fires every time the user taps a
    // tab, including tapping back to one already loaded, but the fetch itself should only
    // ever happen once per sheet visit.
    func loadStatisticsIfNeeded() async {
        guard !hasLoadedStatistics else { return }
        hasLoadedStatistics = true
        statistics = try? await service.fetchMatchStatistics(matchID: match.id)
    }

    func loadLineupsIfNeeded() async {
        guard !hasLoadedLineups else { return }
        hasLoadedLineups = true
        lineups = try? await service.fetchMatchLineups(matchID: match.id)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BR2026Tests/MatchDetailViewModelTests`
Expected: PASS, all tests including the 5 new ones.

- [ ] **Step 5: Build and run the full test suite**

Run: `xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `** BUILD SUCCEEDED **`

Run: `xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BR2026Tests`
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add BR2026/ViewModels/MatchDetailViewModel.swift BR2026Tests/ViewModels/MatchDetailViewModelTests.swift
git commit -m "Add lazy statistics/lineups loading to MatchDetailViewModel"
```

---

### Task 4: Segmented control + `StatisticsView`

**Files:**
- Modify: `BR2026/Views/MatchDetail/MatchDetailView.swift`
- Create: `BR2026/Components/StatisticsView.swift`

**Interfaces:**
- Consumes: `MatchDetailSegment`, `MatchDetailViewModel.selectedSegment/.statistics/.loadStatisticsIfNeeded()/.loadLineupsIfNeeded()` from Task 3; `MatchStatistics`/`TeamStats` from Task 1.
- Produces: `StatisticsView(statistics: MatchStatistics)`, wired into `MatchDetailView`'s body.
- Consumed by: Task 5 (adds the Lineups case to the same `switch`), Task 6 (extends `testMatchDetailAudit` to select this segment).

- [ ] **Step 1: Add the 6 stat-label and 2 segment-label localized strings, plus the empty-state and VoiceOver-comparison strings**

```bash
python3 << 'EOF'
import json

path = "BR2026/Resources/Localizable.xcstrings"
with open(path, encoding="utf-8") as f:
    data = json.load(f)

def entry(comment, values):
    return {
        "extractionState": "manual",
        "comment": comment,
        "localizations": {
            locale: {"stringUnit": {"state": "translated", "value": value}}
            for locale, value in values.items()
        }
    }

new_strings = {
    "Stats": entry(
        "Match detail segmented control option: shows match statistics (possession, shots, etc.).",
        {"en": "Stats", "en-GB": "Stats", "es": "Estadísticas", "fr": "Stats", "pt-BR": "Estatísticas", "pt-PT": "Estatísticas"}
    ),
    "Lineups": entry(
        "Match detail segmented control option: shows both teams' starting lineups.",
        {"en": "Lineups", "en-GB": "Lineups", "es": "Alineaciones", "fr": "Compositions", "pt-BR": "Escalações", "pt-PT": "Onzes"}
    ),
    "Possession": entry(
        "Match statistics row label: percentage of the match each team controlled the ball.",
        {"en": "Possession", "en-GB": "Possession", "es": "Posesión", "fr": "Possession", "pt-BR": "Posse de Bola", "pt-PT": "Posse de Bola"}
    ),
    "Shots": entry(
        "Match statistics row label: total shot attempts.",
        {"en": "Shots", "en-GB": "Shots", "es": "Tiros", "fr": "Tirs", "pt-BR": "Finalizações", "pt-PT": "Remates"}
    ),
    "Shots on Target": entry(
        "Match statistics row label: shot attempts that were on target.",
        {"en": "Shots on Target", "en-GB": "Shots on Target", "es": "Tiros a Puerta", "fr": "Tirs Cadrés", "pt-BR": "Finalizações no Alvo", "pt-PT": "Remates à Baliza"}
    ),
    "Corners": entry(
        "Match statistics row label: corner kicks taken.",
        {"en": "Corners", "en-GB": "Corners", "es": "Córners", "fr": "Corners", "pt-BR": "Escanteios", "pt-PT": "Cantos"}
    ),
    "Fouls": entry(
        "Match statistics row label: fouls committed.",
        {"en": "Fouls", "en-GB": "Fouls", "es": "Faltas", "fr": "Fautes", "pt-BR": "Faltas", "pt-PT": "Faltas"}
    ),
    "Pass Accuracy": entry(
        "Match statistics row label: percentage of completed passes.",
        {"en": "Pass Accuracy", "en-GB": "Pass Accuracy", "es": "Precisión de Pases", "fr": "Précision des Passes", "pt-BR": "Precisão de Passes", "pt-PT": "Precisão de Passe"}
    ),
    "Statistics not yet available": entry(
        "Match detail Stats tab empty state, shown when the match hasn't started or the API hasn't published statistics yet.",
        {"en": "Statistics not yet available", "en-GB": "Statistics not yet available", "es": "Estadísticas aún no disponibles", "fr": "Statistiques pas encore disponibles", "pt-BR": "Estatísticas ainda não disponíveis", "pt-PT": "Estatísticas ainda não disponíveis"}
    ),
}

for key, value in new_strings.items():
    if key in data["strings"]:
        raise SystemExit(f"Key already exists, aborting: {key}")
    data["strings"][key] = value

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2, sort_keys=True)
    f.write("\n")
EOF
```

- [ ] **Step 2: Add the VoiceOver comparison-label string separately, verifying its format specifier**

This string has 3 `String` arguments interpolated (stat name, home value, away value) — verify the exact key Swift generates before writing the catalog entry, so the key matches character-for-character:

Run: `swift -e 'import Foundation; let label = "Possession"; let home = "48%"; let away = "52%"; dump(String.LocalizationValue("\(label): Home \(home), Away \(away)"))'`
Expected output includes `key: "%@: Home %@, Away %@"` — confirms 3 bare, unnumbered `%@` (no `%1$@`/`%2$@`/`%3$@` in the key itself).

```bash
python3 << 'EOF'
import json

path = "BR2026/Resources/Localizable.xcstrings"
with open(path, encoding="utf-8") as f:
    data = json.load(f)

key = "%@: Home %@, Away %@"
data["strings"][key] = {
    "extractionState": "manual",
    "comment": "VoiceOver label for one match-statistics comparison row. Arguments: stat name (already localized), home team's value (already formatted, e.g. \"48%\"), away team's value (already formatted).",
    "localizations": {
        "en": {"stringUnit": {"state": "translated", "value": "%1$@: Home %2$@, Away %3$@"}},
        "en-GB": {"stringUnit": {"state": "translated", "value": "%1$@: Home %2$@, Away %3$@"}},
        "es": {"stringUnit": {"state": "translated", "value": "%1$@: local %2$@, visitante %3$@"}},
        "fr": {"stringUnit": {"state": "translated", "value": "%1$@ : domicile %2$@, extérieur %3$@"}},
        "pt-BR": {"stringUnit": {"state": "translated", "value": "%1$@: mandante %2$@, visitante %3$@"}},
        "pt-PT": {"stringUnit": {"state": "translated", "value": "%1$@: casa %2$@, fora %3$@"}},
    }
}

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2, sort_keys=True)
    f.write("\n")
EOF
```

- [ ] **Step 3: Verify JSON validity**

Run: `python3 -c "import json; json.load(open('BR2026/Resources/Localizable.xcstrings'))" && echo "valid JSON"`
Expected: `valid JSON`

- [ ] **Step 4: Create `StatisticsView.swift`**

```swift
// BR2026/Components/StatisticsView.swift
import SwiftUI

/// Six comparison-bar rows (Possession, Shots, Shots on Target, Corners, Fouls, Pass
/// Accuracy) — teal fill for the home team's share, muted white for away's, proportional
/// to each stat's total. Matches the approved brainstorming-session mockup.
struct StatisticsView: View {
    let statistics: MatchStatistics
    @Environment(\.themeTokens) private var themeTokens
    @ScaledMetric private var valueFontSize: CGFloat = 15
    @ScaledMetric private var labelFontSize: CGFloat = 11

    private struct StatRow {
        let label: String
        let home: Int
        let away: Int
        let suffix: String
    }

    private var rows: [StatRow] {
        [
            StatRow(label: String(localized: "Possession", comment: "Match statistics row label: percentage of the match each team controlled the ball."), home: statistics.home.possession, away: statistics.away.possession, suffix: "%"),
            StatRow(label: String(localized: "Shots", comment: "Match statistics row label: total shot attempts."), home: statistics.home.shots, away: statistics.away.shots, suffix: ""),
            StatRow(label: String(localized: "Shots on Target", comment: "Match statistics row label: shot attempts that were on target."), home: statistics.home.shotsOnTarget, away: statistics.away.shotsOnTarget, suffix: ""),
            StatRow(label: String(localized: "Corners", comment: "Match statistics row label: corner kicks taken."), home: statistics.home.corners, away: statistics.away.corners, suffix: ""),
            StatRow(label: String(localized: "Fouls", comment: "Match statistics row label: fouls committed."), home: statistics.home.fouls, away: statistics.away.fouls, suffix: ""),
            StatRow(label: String(localized: "Pass Accuracy", comment: "Match statistics row label: percentage of completed passes."), home: statistics.home.passAccuracy, away: statistics.away.passAccuracy, suffix: "%")
        ]
    }

    var body: some View {
        VStack(spacing: 18) {
            ForEach(rows.indices, id: \.self) { index in
                statRow(rows[index])
            }
        }
    }

    private func statRow(_ row: StatRow) -> some View {
        let total = max(row.home + row.away, 1)
        let homeFraction = Double(row.home) / Double(total)
        return VStack(spacing: 6) {
            HStack {
                Text("\(row.home)\(row.suffix)")
                Spacer()
                Text("\(row.away)\(row.suffix)")
            }
            .font(.system(size: valueFontSize, weight: .heavy))
            .monospacedDigit()
            .foregroundStyle(themeTokens.textColor)

            Text(row.label)
                .font(.system(size: labelFontSize, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(themeTokens.textColor.opacity(0.5))
                .textCase(.uppercase)

            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(hex: "2dd4bf"))
                        .frame(width: geometry.size.width * homeFraction)
                    Rectangle()
                        .fill(Color.white.opacity(0.35))
                }
            }
            .frame(height: 6)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statAccessibilityLabel(row))
    }

    private func statAccessibilityLabel(_ row: StatRow) -> String {
        let homeText = "\(row.home)\(row.suffix)"
        let awayText = "\(row.away)\(row.suffix)"
        return String(
            localized: "\(row.label): Home \(homeText), Away \(awayText)",
            comment: "VoiceOver label for one match-statistics comparison row. Arguments: stat name (already localized), home team's value (already formatted, e.g. \"48%\"), away team's value (already formatted)."
        )
    }
}
```

- [ ] **Step 5: Wire the segmented control and `StatisticsView` into `MatchDetailView`**

Replace the existing `body` (Step 5a) and `timelineSection` (Step 5b, unchanged, just relocated) in `BR2026/Views/MatchDetail/MatchDetailView.swift`:

Find:
```swift
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.horizontal, 16)
                timelineSection
                    .padding(.top, 24)
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
        .background(StadiumBackground())
        .presentationDragIndicator(.visible)
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await viewModel.load()
            await viewModel.pollWhileLive()
        }
        .trackScreen("MatchDetail")
    }
```

Replace with:
```swift
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.horizontal, 16)
                segmentPicker
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                segmentContent
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
        .background(StadiumBackground())
        .presentationDragIndicator(.visible)
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await viewModel.load()
            await viewModel.pollWhileLive()
        }
        .onChange(of: viewModel.selectedSegment) { _, newValue in
            Task {
                switch newValue {
                case .stats: await viewModel.loadStatisticsIfNeeded()
                case .lineups: await viewModel.loadLineupsIfNeeded()
                case .timeline: break
                }
            }
        }
        .trackScreen("MatchDetail")
    }

    private var segmentPicker: some View {
        Picker("", selection: $viewModel.selectedSegment) {
            Text("Timeline", comment: "Match detail segmented control option: shows the goals/cards/substitutions timeline.").tag(MatchDetailSegment.timeline)
            Text("Stats", comment: "Match detail segmented control option: shows match statistics (possession, shots, etc.).").tag(MatchDetailSegment.stats)
            Text("Lineups", comment: "Match detail segmented control option: shows both teams' starting lineups.").tag(MatchDetailSegment.lineups)
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var segmentContent: some View {
        switch viewModel.selectedSegment {
        case .timeline:
            timelineSection
        case .stats:
            if let statistics = viewModel.statistics {
                StatisticsView(statistics: statistics)
            } else {
                Text("Statistics not yet available", comment: "Match detail Stats tab empty state, shown when the match hasn't started or the API hasn't published statistics yet.")
                    .font(.system(size: emptyEventsFontSize))
                    .foregroundStyle(themeTokens.textColor.opacity(0.45))
                    .padding(.top, 20)
            }
        case .lineups:
            // Lineups case added in Task 5.
            EmptyView()
        }
    }
```

Note: `Text("Timeline", comment:)` reuses the catalog key `"Timeline"` that already exists from the prior standalone `timelineSection` header — no new string needed for that one.

- [ ] **Step 6: Build**

Run: `xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: Run the full test suite**

Run: `xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BR2026Tests`
Expected: All tests pass. This task adds no new unit tests of its own (no View-layer tests per CLAUDE.md) — just confirms the existing suite still passes with the wiring change.

- [ ] **Step 8: Commit**

```bash
git add BR2026/Views/MatchDetail/MatchDetailView.swift BR2026/Components/StatisticsView.swift BR2026/Resources/Localizable.xcstrings
git commit -m "Add segmented control and StatisticsView to MatchDetailView"
```

---

### Task 5: `LineupsView` — pitch, jersey markers, own-half placement

**Files:**
- Create: `BR2026/Components/LineupsView.swift`
- Modify: `BR2026/Views/MatchDetail/MatchDetailView.swift`

**Interfaces:**
- Consumes: `MatchLineup`/`TeamLineup`/`LineupPlayer` from Task 1, `MatchDetailViewModel.lineups` from Task 3, `MatchDetailSegment.lineups` case (currently `EmptyView()`) from Task 4.
- Produces: `LineupsView(lineup: MatchLineup, homeTeamName: String, awayTeamName: String)`, wired into `MatchDetailView`'s `segmentContent`.
- Consumed by: Task 6 (extends `testMatchDetailAudit` to select this segment).

- [ ] **Step 1: Add the 2 remaining localized strings for this task (Lineups empty state, formation header)**

```bash
python3 << 'EOF'
import json

path = "BR2026/Resources/Localizable.xcstrings"
with open(path, encoding="utf-8") as f:
    data = json.load(f)

def entry(comment, values):
    return {
        "extractionState": "manual",
        "comment": comment,
        "localizations": {
            locale: {"stringUnit": {"state": "translated", "value": value}}
            for locale, value in values.items()
        }
    }

new_strings = {
    "Lineups not yet available": entry(
        "Match detail Lineups tab empty state, shown when the API hasn't published starting lineups yet (typically ~1 hour before kickoff).",
        {"en": "Lineups not yet available", "en-GB": "Lineups not yet available", "es": "Alineaciones aún no disponibles", "fr": "Compositions pas encore disponibles", "pt-BR": "Escalações ainda não disponíveis", "pt-PT": "Onzes ainda não disponíveis"}
    ),
    "Substitutes": entry(
        "Match detail Lineups tab section header, above the list of bench players.",
        {"en": "Substitutes", "en-GB": "Substitutes", "es": "Suplentes", "fr": "Remplaçants", "pt-BR": "Reservas", "pt-PT": "Suplentes"}
    ),
}

for key, value in new_strings.items():
    if key in data["strings"]:
        raise SystemExit(f"Key already exists, aborting: {key}")
    data["strings"][key] = value

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2, sort_keys=True)
    f.write("\n")
EOF
```

- [ ] **Step 2: Add the two VoiceOver template strings (player label, formation header), verifying format specifiers first**

Run: `swift -e 'import Foundation; let name = "Fábio"; let number = "1"; let position = "Goalkeeper"; let team = "Fluminense"; dump(String.LocalizationValue("\(name), number \(number), \(position), \(team)"))'`
Expected output includes `key: "%@, number %@, %@, %@"` (4 bare `%@`).

Run: `swift -e 'import Foundation; let team = "Fluminense"; let formation = "4-2-3-1"; dump(String.LocalizationValue("\(team), formation \(formation)"))'`
Expected output includes `key: "%@, formation %@"` (2 bare `%@`).

```bash
python3 << 'EOF'
import json

path = "BR2026/Resources/Localizable.xcstrings"
with open(path, encoding="utf-8") as f:
    data = json.load(f)

data["strings"]["%@, number %@, %@, %@"] = {
    "extractionState": "manual",
    "comment": "VoiceOver label for one lineup player marker on the formation pitch. Arguments: player name, jersey number (already formatted as a string), position (already localized, e.g. \"Goalkeeper\"), team name.",
    "localizations": {
        "en": {"stringUnit": {"state": "translated", "value": "%1$@, number %2$@, %3$@, %4$@"}},
        "en-GB": {"stringUnit": {"state": "translated", "value": "%1$@, number %2$@, %3$@, %4$@"}},
        "es": {"stringUnit": {"state": "translated", "value": "%1$@, número %2$@, %3$@, %4$@"}},
        "fr": {"stringUnit": {"state": "translated", "value": "%1$@, numéro %2$@, %3$@, %4$@"}},
        "pt-BR": {"stringUnit": {"state": "translated", "value": "%1$@, número %2$@, %3$@, %4$@"}},
        "pt-PT": {"stringUnit": {"state": "translated", "value": "%1$@, número %2$@, %3$@, %4$@"}},
    }
}

data["strings"]["%@, formation %@"] = {
    "extractionState": "manual",
    "comment": "VoiceOver heading label spoken before a team's players on the lineup formation pitch. Arguments: team name, formation string (e.g. \"4-2-3-1\").",
    "localizations": {
        "en": {"stringUnit": {"state": "translated", "value": "%1$@, formation %2$@"}},
        "en-GB": {"stringUnit": {"state": "translated", "value": "%1$@, formation %2$@"}},
        "es": {"stringUnit": {"state": "translated", "value": "%1$@, formación %2$@"}},
        "fr": {"stringUnit": {"state": "translated", "value": "%1$@, formation %2$@"}},
        "pt-BR": {"stringUnit": {"state": "translated", "value": "%1$@, formação %2$@"}},
        "pt-PT": {"stringUnit": {"state": "translated", "value": "%1$@, formação %2$@"}},
    }
}

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2, sort_keys=True)
    f.write("\n")
EOF
```

- [ ] **Step 3: Verify JSON validity**

Run: `python3 -c "import json; json.load(open('BR2026/Resources/Localizable.xcstrings'))" && echo "valid JSON"`
Expected: `valid JSON`

- [ ] **Step 4: Create `LineupsView.swift`**

```swift
// BR2026/Components/LineupsView.swift
import SwiftUI

/// A jersey-shaped marker: sleeves plus a V-neck notch. Polygon points are fractions of
/// the marker's own bounding box, matching the approved brainstorming-session mockup's
/// CSS `clip-path: polygon(...)` exactly.
private struct JerseyShape: Shape {
    private static let points: [(CGFloat, CGFloat)] = [
        (0.30, 0.0), (0.42, 0.0), (0.50, 0.16), (0.58, 0.0), (0.70, 0.0),
        (1.0, 0.22), (0.85, 0.40), (0.85, 1.0), (0.15, 1.0), (0.15, 0.40), (0.0, 0.22)
    ]

    func path(in rect: CGRect) -> Path {
        let scaled = Self.points.map { CGPoint(x: rect.minX + $0.0 * rect.width, y: rect.minY + $0.1 * rect.height) }
        var path = Path()
        path.move(to: scaled[0])
        for point in scaled.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }
}

private enum PitchSide {
    case home
    case away
}

private struct PlacedPlayer: Identifiable {
    let id: String
    let player: LineupPlayer
    let xPercent: Double
    let yPercent: Double
    let teamName: String
    let kitColorHex: String
    let kitFontColorHex: String
}

/// A soccer-pitch-shaped formation grid: each starting player renders as a jersey marker
/// positioned via the API's col/row grid coordinates, confined strictly to its own team's
/// half. Substitutes (which have no col/row) render as a plain list below. Matches the
/// approved brainstorming-session mockup, including the fix for a real overlap bug found
/// during that review (see `bylineMargin`/`halfwayMargin`).
struct LineupsView: View {
    let lineup: MatchLineup
    let homeTeamName: String
    let awayTeamName: String
    @Environment(\.themeTokens) private var themeTokens
    @ScaledMetric private var jerseyNumberFontSize: CGFloat = 11
    @ScaledMetric private var playerNameFontSize: CGFloat = 9
    @ScaledMetric private var formationLabelFontSize: CGFloat = 12
    @ScaledMetric private var substitutesHeaderFontSize: CGFloat = 13
    @ScaledMetric private var substituteRowFontSize: CGFloat = 13

    private static let jerseyWidth: CGFloat = 30
    private static let jerseyHeight: CGFloat = 32
    // GK stays off the very edge (byline); the deepest attacking line stays well clear of
    // the halfway line so the two teams' closest rows never collide regardless of
    // formation. An earlier mockup iteration used halfwayMargin = 2, which visually
    // collided the two teams' lone strikers (each centered horizontally, since each was
    // the only player in its row) directly on the halfway line — do not regress this
    // value back down without re-checking that exact case.
    private static let bylineMargin: Double = 6
    private static let halfwayMargin: Double = 12

    var body: some View {
        VStack(spacing: 16) {
            formationLabels
            pitch
            substitutesList
        }
    }

    private var formationLabels: some View {
        HStack {
            Text("\(homeTeamName.uppercased()) · \(lineup.home.formation)")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(formationAccessibilityLabel(teamName: homeTeamName, formation: lineup.home.formation))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Text("\(awayTeamName.uppercased()) · \(lineup.away.formation)")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(formationAccessibilityLabel(teamName: awayTeamName, formation: lineup.away.formation))
                .accessibilityAddTraits(.isHeader)
        }
        .font(.system(size: formationLabelFontSize, weight: .bold))
        .foregroundStyle(themeTokens.textColor.opacity(0.55))
    }

    private func formationAccessibilityLabel(teamName: String, formation: String) -> String {
        String(
            localized: "\(teamName), formation \(formation)",
            comment: "VoiceOver heading label spoken before a team's players on the lineup formation pitch. Arguments: team name, formation string (e.g. \"4-2-3-1\")."
        )
    }

    private var pitch: some View {
        GeometryReader { geometry in
            ZStack {
                pitchLines
                ForEach(placedPlayers(for: lineup.home, side: .home, teamName: homeTeamName)) { placed in
                    playerMarker(placed, in: geometry.size)
                }
                ForEach(placedPlayers(for: lineup.away, side: .away, teamName: awayTeamName)) { placed in
                    playerMarker(placed, in: geometry.size)
                }
            }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .background(
            LinearGradient(
                colors: [Color(hex: "1d6b3a"), Color(hex: "1a5f33"), Color(hex: "1d6b3a")],
                startPoint: .top, endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    private var pitchLines: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                    .frame(width: geometry.size.width, height: 0)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                Circle()
                    .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                    .frame(width: 70, height: 70)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                Rectangle()
                    .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                    .frame(width: geometry.size.width * 0.55, height: geometry.size.height * 0.14)
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.07)
                Rectangle()
                    .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                    .frame(width: geometry.size.width * 0.55, height: geometry.size.height * 0.14)
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.93)
            }
        }
        .accessibilityHidden(true)
    }

    private func placedPlayers(for team: TeamLineup, side: PitchSide, teamName: String) -> [PlacedPlayer] {
        guard let maxRow = team.startingXI.compactMap(\.row).max(), maxRow >= 1 else { return [] }
        let rows = Dictionary(grouping: team.startingXI, by: { $0.row ?? 0 })
        var placed: [PlacedPlayer] = []
        for (row, players) in rows {
            let sorted = players.sorted { ($0.col ?? 0) < ($1.col ?? 0) }
            for (index, player) in sorted.enumerated() {
                let xPercent = Double(index + 1) / Double(sorted.count + 1) * 100
                let t = maxRow == 1 ? 0.0 : Double(row - 1) / Double(maxRow - 1)
                let yPercent: Double
                switch side {
                case .home:
                    yPercent = (100 - Self.bylineMargin) - t * ((100 - Self.bylineMargin) - (50 + Self.halfwayMargin))
                case .away:
                    yPercent = Self.bylineMargin + t * ((50 - Self.halfwayMargin) - Self.bylineMargin)
                }
                placed.append(PlacedPlayer(
                    id: "\(side == .home ? "home" : "away")-\(player.number)",
                    player: player,
                    xPercent: xPercent,
                    yPercent: yPercent,
                    teamName: teamName,
                    kitColorHex: team.kitColorHex,
                    kitFontColorHex: team.kitFontColorHex
                ))
            }
        }
        return placed
    }

    private func playerMarker(_ placed: PlacedPlayer, in size: CGSize) -> some View {
        VStack(spacing: 2) {
            JerseyShape()
                .fill(Color(hex: placed.kitColorHex))
                .frame(width: Self.jerseyWidth, height: Self.jerseyHeight)
                .overlay(JerseyShape().stroke(Color.black.opacity(0.25), lineWidth: 1))
                .overlay(
                    Text("\(placed.player.number)")
                        .font(.system(size: jerseyNumberFontSize, weight: .heavy))
                        .foregroundStyle(Color(hex: placed.kitFontColorHex))
                        .padding(.top, 6)
                )
            Text(placed.player.name)
                .font(.system(size: playerNameFontSize, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .fixedSize()
        }
        .position(x: size.width * placed.xPercent / 100, y: size.height * placed.yPercent / 100)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(playerAccessibilityLabel(placed))
    }

    private func playerAccessibilityLabel(_ placed: PlacedPlayer) -> String {
        String(
            localized: "\(placed.player.name), number \(String(placed.player.number)), \(placed.player.positionAccessibilityLabel), \(placed.teamName)",
            comment: "VoiceOver label for one lineup player marker on the formation pitch. Arguments: player name, jersey number (already formatted as a string), position (already localized, e.g. \"Goalkeeper\"), team name."
        )
    }

    private var substitutesList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Substitutes", comment: "Match detail Lineups tab section header, above the list of bench players.")
                .font(.system(size: substitutesHeaderFontSize, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(themeTokens.textColor.opacity(0.5))
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)

            // Enumerated, not `id: \.number` — two different teams' substitutes can share
            // the same jersey number (e.g. both backup goalkeepers wearing #12), which
            // would break ForEach's identity requirement across the combined array.
            ForEach(Array((lineup.home.substitutes + lineup.away.substitutes).enumerated()), id: \.offset) { _, player in
                Text("\(player.number)  \(player.name) (\(player.position))")
                    .font(.system(size: substituteRowFontSize, weight: .medium))
                    .foregroundStyle(themeTokens.textColor.opacity(0.65))
            }
        }
    }
}
```

- [ ] **Step 5: Wire `LineupsView` into `MatchDetailView`'s `segmentContent`**

Find (added in Task 4):
```swift
        case .lineups:
            // Lineups case added in Task 5.
            EmptyView()
```

Replace with:
```swift
        case .lineups:
            if let lineups = viewModel.lineups {
                LineupsView(lineup: lineups, homeTeamName: match.homeTeam.displayName, awayTeamName: match.awayTeam.displayName)
            } else {
                Text("Lineups not yet available", comment: "Match detail Lineups tab empty state, shown when the API hasn't published starting lineups yet (typically ~1 hour before kickoff).")
                    .font(.system(size: emptyEventsFontSize))
                    .foregroundStyle(themeTokens.textColor.opacity(0.45))
                    .padding(.top, 20)
            }
```

- [ ] **Step 6: Build**

Run: `xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: Run the full test suite**

Run: `xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BR2026Tests`
Expected: All tests pass.

- [ ] **Step 8: Manual sanity check with mock data**

Run the app in the simulator (`xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17'` build + install + launch, or via Xcode directly), open any match's detail sheet, tap the Lineups segment, and visually confirm: both teams' 11 starting players render on the pitch confined to their own half, jersey colors match the mock fixture (`1e1e20` charcoal home, `ffffff` white away), no two markers overlap, and the Substitutes list shows both teams' bench players below.

- [ ] **Step 9: Commit**

```bash
git add BR2026/Components/LineupsView.swift BR2026/Views/MatchDetail/MatchDetailView.swift BR2026/Resources/Localizable.xcstrings
git commit -m "Add LineupsView with pitch formation grid and jersey markers"
```

---

### Task 6: Extend the accessibility audit and final verification

**Files:**
- Modify: `BR2026UITests/AccessibilityAuditUITests.swift`

**Interfaces:**
- Consumes: the finished `MatchDetailView` segmented control from Tasks 4-5.
- Produces: nothing new — this task only extends existing UI test coverage and performs final whole-feature verification. No later task depends on it.

- [ ] **Step 1: Confirm the existing test's exact structure**

`testMatchDetailAudit` currently reads (confirmed by reading the file directly):

```swift
    func testMatchDetailAudit() throws {
        let app = launchedApp()
        app.tabBars.firstMatch.buttons.element(boundBy: 0).tap()
        sleep(2)
        let heroCoordinate = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        heroCoordinate.tap()
        // ... (comment block explaining the ScrollView-count check, unchanged)
        let matchDetailScrollView = app.scrollViews.element(boundBy: 1)
        XCTAssertTrue(
            matchDetailScrollView.waitForExistence(timeout: 5),
            "Match Detail sheet did not open after tapping the hero card coordinate — hero card may be absent or the tap missed its target"
        )
        try app.performAccessibilityAudit(for: Self.auditTypes) { issue in
            isDynamicTypeCapFalsePositive(issue)
        }
    }
```

`Self.auditTypes` (a class-level constant, defined once near the top of `AccessibilityAuditUITests`) is `[.sufficientElementDescription, .trait, .elementDetection, .dynamicType, .textClipped]` — **deliberately excludes `.contrast`** (documented in this file: this app's Liquid Glass design uses intentionally low-alpha text tiers that produce hundreds of out-of-scope `.contrast` failures). Reuse `Self.auditTypes` and the same `isDynamicTypeCapFalsePositive` issue-handler closure for the two new audit calls below — do not introduce a different audit-type set.

- [ ] **Step 2: Extend the test to audit the Stats and Lineups segments too**

Insert this immediately after the existing `try app.performAccessibilityAudit(for: Self.auditTypes) { ... }` call shown in Step 1, before the function's closing brace:

```swift
        // The audit only catches issues in whatever's currently on screen — extend
        // coverage to the two new segments, not just the default Timeline one, the same
        // lesson the Dynamic Type phase learned the hard way (two picker audits had been
        // silently checking the wrong screen for an entire prior phase). Index-based
        // `.buttons.element(boundBy:)`, matching this file's own established convention:
        // SwiftUI segmented-control buttons don't reliably propagate
        // `.accessibilityIdentifier`, and a text-based lookup would break on this
        // project's pt-BR test-simulator locale (see testAppIconPickerAudit's comment for
        // that exact prior failure).
        let segmentedControl = app.segmentedControls.firstMatch
        segmentedControl.buttons.element(boundBy: 1).tap()  // Stats
        sleep(1)
        try app.performAccessibilityAudit(for: Self.auditTypes) { issue in
            isDynamicTypeCapFalsePositive(issue)
        }

        segmentedControl.buttons.element(boundBy: 2).tap()  // Lineups
        sleep(1)
        try app.performAccessibilityAudit(for: Self.auditTypes) { issue in
            isDynamicTypeCapFalsePositive(issue)
        }
```

- [ ] **Step 3: Run the extended UI test**

Run: `xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BR2026UITests/AccessibilityAuditUITests/testMatchDetailAudit`
Expected: PASS. If it fails with a genuine audit finding (e.g. a real clipping/contrast issue in `StatisticsView`/`LineupsView`), fix the underlying view per systematic-debugging (root-cause the specific flagged element via `xcrun xcresulttool` attachment extraction, matching this project's established pattern from the Standings header-clipping and Fixtures venue-clipping fixes earlier this session) — do not weaken or skip the audit to make it pass.

- [ ] **Step 4: Run the complete test suite (unit + UI) one final time**

Run: `xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: All tests pass, 0 failures.

- [ ] **Step 5: Verify all 6 targets still build**

This feature's new files (`MatchStatistics.swift`, `MatchLineupDTO.swift`, `MatchLineup.swift`, `StatisticsView.swift`, `LineupsView.swift`) must be registered in every target's Xcode project membership, not just `BR2026` — the Dynamic Type phase found a real production-blocking regression this exact way (`WCAGContrast.swift` had only ever been added to the `BR2026` target). Run:

```bash
for scheme in PremierLeague2026 Ligue12026 PrimeiraLiga2026 ScottishPremiership2026 LaLiga2026; do
  echo "=== $scheme ==="
  xcodebuild -project BR2026.xcodeproj -scheme "$scheme" -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
done
```

Expected: `** BUILD SUCCEEDED **` for every scheme. If any target fails to find the new types, use the `xcodeproj` Ruby gem to add the missing file(s) to that target's membership (see `docs/superpowers/plans/2026-07-12-firebase-integration-implementation.md` Task 1 for the established script pattern), then re-run this step.

- [ ] **Step 6: Commit**

```bash
git add BR2026UITests/AccessibilityAuditUITests.swift
git commit -m "Extend testMatchDetailAudit to cover the Stats and Lineups segments"
```
