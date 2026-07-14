# Palmeiras Team Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user recolor the whole app to one of Palmeiras's three real kit color sets (Home/Away/Third), applied to the background gradient, glow blobs, `HeroMatchCard`'s border, the app's accent, and all body text — per `docs/superpowers/specs/2026-07-14-palmeiras-team-theme-design.md`.

**Architecture:** A new `TeamThemeStore` (`@Observable @MainActor`) owns whether a Palmeiras kit theme is selected (persisted via `UserDefaults`) and its resolved colors (fetched through a new `MatchService` method, cached in SwiftData). It exposes one `ThemeTokens` value — always fully resolved, defaulting to today's exact fixed values when inactive — injected once into the SwiftUI environment at `ContentView`. Every consumer (background, hero card, body text) reads `@Environment(\.themeTokens)` instead of a literal color.

**Tech Stack:** Swift 6, SwiftUI (iOS 26+), SwiftData, Swift Testing (`@Test`/`@Suite`), `xcodeproj` Ruby gem 1.28.1 (already a `fastlane` transitive dependency) for `project.pbxproj` file registration.

## Global Constraints

- The 4 already-shipped app targets (`BR2026`, `PremierLeague2026`, `Ligue12026`, `PrimeiraLiga2026`) must render pixel-identical to today when no theme is selected — every new default value in this feature is built around this.
- Only `home.mainColor`/`home.fontColor`, `away.mainColor`/`away.fontColor`, `third.mainColor`/`third.fontColor` are used from `GET /v4/competitions/{code}/teams/{id}/colors` — `secondaryColor`/`matchesConsidered` are never decoded.
- The Palmeiras theme (all 3 kit variants) is gated to the default `BR2026` target only, via the existing `#if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA)` pattern already used by `AppIconOption`.
- `TeamThemeOption.isPurchased` is hardcoded `true` — no real StoreKit 2 purchasing in this pass.
- No per-team app icons, no other teams beyond Palmeiras, no match-context-dependent kit switching.
- New Swift source files must be registered into all 4 app targets' Sources build phase (or `BR2026Tests`'s, for test files) via the `xcodeproj` gem — this project does not use file-system-synchronized groups, so files created on disk are invisible to Xcode/`xcodebuild` until registered.
- Test command: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test` (runs the `BR2026Tests` suite via `scan` against the default `BR2026` scheme).
- Build command (per scheme): `xcodebuild -project BR2026.xcodeproj -scheme <SchemeName> -destination 'generic/platform=iOS Simulator' -skipMacroValidation build`.

---

## Xcode Project Registration Recipe (reused by several tasks below)

Each task that creates new Swift files includes a step that runs a Ruby script using the `xcodeproj` gem to register those files. The script always follows this shape — only the `new_app_files`/`new_test_files`/`new_groups` blocks change per task:

```ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('BR2026.xcodeproj')

def find_group(root, *path_components)
  group = root
  path_components.each do |name|
    group = group.children.find { |c| c.respond_to?(:display_name) && c.display_name == name }
    raise "Group not found: #{path_components.inspect} at #{name}" unless group
  end
  group
end

app_targets = %w[BR2026 PremierLeague2026 Ligue12026 PrimeiraLiga2026].map { |n| project.native_targets.find { |t| t.name == n } }
test_target = project.native_targets.find { |t| t.name == 'BR2026Tests' }

# --- app files (task-specific) ---
# group = find_group(project.main_group, 'BR2026', '<GroupName>')
# new_app_files = [group.new_file('<FileName>.swift')]
# app_targets.each { |t| t.add_file_references(new_app_files) }

# --- test files (task-specific) ---
# test_group = find_group(project.main_group, 'BR2026Tests', '<GroupName>')
# new_test_files = [test_group.new_file('<FileName>Tests.swift')]
# test_target.add_file_references(new_test_files)

project.save
puts 'OK'
```

Run via: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec ruby /tmp/register_files.rb` (the script itself is a scratch file, not committed — only its effect on `project.pbxproj` is committed).

---

### Task 1: Team theme color models

**Files:**
- Create: `BR2026/Models/TeamThemeColors.swift`
- Create: `BR2026/Models/TeamThemeColorCache.swift`
- Test: `BR2026Tests/Models/TeamThemeColorsTests.swift`

**Interfaces:**
- Produces: `TeamKit` (enum: `.home`, `.away`, `.third`), `TeamThemeColors` (struct: `mainColorHex: String`, `fontColorHex: String`), `TeamThemeColorSet` (struct: `home`/`away`/`third: TeamThemeColors`, `subscript(kit: TeamKit) -> TeamThemeColors`), `TeamThemeColorsResponse` (Decodable) + `TeamThemeColorSet.init(response:)`, `TeamThemeColorCache` (`@Model`, `teamID`/6 hex properties/`cachedAt`, computed `colorSet: TeamThemeColorSet`) — consumed by Task 2's `MatchService`.

- [ ] **Step 1: Write the failing test**

Create `BR2026Tests/Models/TeamThemeColorsTests.swift`:
```swift
import Testing
import Foundation
@testable import BR2026

@Suite("TeamThemeColors decoding")
struct TeamThemeColorsTests {
    private let json = """
    {
      "team": {"id": 121, "name": "Palmeiras"},
      "home": {"fontColor": "ffffff", "mainColor": "225638", "secondaryColor": "225638", "matchesConsidered": 15},
      "away": {"fontColor": "035336", "mainColor": "ffffff", "secondaryColor": "ffffff", "matchesConsidered": 1},
      "third": {"fontColor": "2c5434", "mainColor": "ffffff", "secondaryColor": "ffffff", "matchesConsidered": 1}
    }
    """.data(using: .utf8)!

    @Test("Decodes all 3 kits from the live wire shape, ignoring secondaryColor/matchesConsidered/team")
    func decodesAllThreeKits() throws {
        let response = try JSONDecoder().decode(TeamThemeColorsResponse.self, from: json)
        let colorSet = TeamThemeColorSet(response: response)

        #expect(colorSet.home == TeamThemeColors(mainColorHex: "225638", fontColorHex: "ffffff"))
        #expect(colorSet.away == TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "035336"))
        #expect(colorSet.third == TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "2c5434"))
    }

    @Test("Subscripting by TeamKit returns the matching kit's colors")
    func subscriptByKit() throws {
        let response = try JSONDecoder().decode(TeamThemeColorsResponse.self, from: json)
        let colorSet = TeamThemeColorSet(response: response)

        #expect(colorSet[.home] == colorSet.home)
        #expect(colorSet[.away] == colorSet.away)
        #expect(colorSet[.third] == colorSet.third)
    }

    @Test("TeamThemeColorCache round-trips a TeamThemeColorSet through its colorSet property")
    func cacheRoundTrips() throws {
        let response = try JSONDecoder().decode(TeamThemeColorsResponse.self, from: json)
        let colorSet = TeamThemeColorSet(response: response)
        let cache = TeamThemeColorCache(teamID: 121, colors: colorSet)

        #expect(cache.teamID == 121)
        #expect(cache.colorSet == colorSet)
    }
}
```

- [ ] **Step 2: Run it to confirm it fails to compile**

Run: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test`
Expected: FAIL — `TeamKit`, `TeamThemeColors`, `TeamThemeColorSet`, `TeamThemeColorsResponse`, `TeamThemeColorCache` don't exist yet, and the new test file isn't even registered in the project yet (see Step 3).

- [ ] **Step 3: Register the new files with the Xcode project**

Create `/tmp/register_files.rb`:
```ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('BR2026.xcodeproj')

def find_group(root, *path_components)
  group = root
  path_components.each do |name|
    group = group.children.find { |c| c.respond_to?(:display_name) && c.display_name == name }
    raise "Group not found: #{path_components.inspect} at #{name}" unless group
  end
  group
end

app_targets = %w[BR2026 PremierLeague2026 Ligue12026 PrimeiraLiga2026].map { |n| project.native_targets.find { |t| t.name == n } }
test_target = project.native_targets.find { |t| t.name == 'BR2026Tests' }

models_group = find_group(project.main_group, 'BR2026', 'Models')
new_app_files = [
  models_group.new_file('TeamThemeColors.swift'),
  models_group.new_file('TeamThemeColorCache.swift')
]
app_targets.each { |t| t.add_file_references(new_app_files) }

test_models_group = find_group(project.main_group, 'BR2026Tests', 'Models')
new_test_files = [test_models_group.new_file('TeamThemeColorsTests.swift')]
test_target.add_file_references(new_test_files)

project.save
puts 'OK'
```

Run: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec ruby /tmp/register_files.rb`
Expected output: `OK`

- [ ] **Step 4: Create `BR2026/Models/TeamThemeColors.swift`**

```swift
import Foundation

enum TeamKit: String, Codable, CaseIterable {
    case home, away, third
}

struct TeamThemeColors: Codable, Equatable {
    let mainColorHex: String
    let fontColorHex: String
}

struct TeamThemeColorSet: Codable, Equatable {
    let home: TeamThemeColors
    let away: TeamThemeColors
    let third: TeamThemeColors

    subscript(kit: TeamKit) -> TeamThemeColors {
        switch kit {
        case .home: home
        case .away: away
        case .third: third
        }
    }
}

struct TeamThemeColorsResponse: Decodable {
    let home: KitColorsDTO
    let away: KitColorsDTO
    let third: KitColorsDTO

    struct KitColorsDTO: Decodable {
        let fontColor: String
        let mainColor: String
    }
}

extension TeamThemeColorSet {
    init(response: TeamThemeColorsResponse) {
        func colors(_ dto: TeamThemeColorsResponse.KitColorsDTO) -> TeamThemeColors {
            TeamThemeColors(mainColorHex: dto.mainColor, fontColorHex: dto.fontColor)
        }
        self.init(home: colors(response.home), away: colors(response.away), third: colors(response.third))
    }
}
```

- [ ] **Step 5: Create `BR2026/Models/TeamThemeColorCache.swift`**

```swift
import Foundation
import SwiftData

@Model
final class TeamThemeColorCache {
    @Attribute(.unique) var teamID: Int
    var homeMainColorHex: String
    var homeFontColorHex: String
    var awayMainColorHex: String
    var awayFontColorHex: String
    var thirdMainColorHex: String
    var thirdFontColorHex: String
    var cachedAt: Date

    init(teamID: Int, colors: TeamThemeColorSet, cachedAt: Date = Date()) {
        self.teamID = teamID
        self.homeMainColorHex = colors.home.mainColorHex
        self.homeFontColorHex = colors.home.fontColorHex
        self.awayMainColorHex = colors.away.mainColorHex
        self.awayFontColorHex = colors.away.fontColorHex
        self.thirdMainColorHex = colors.third.mainColorHex
        self.thirdFontColorHex = colors.third.fontColorHex
        self.cachedAt = cachedAt
    }

    var colorSet: TeamThemeColorSet {
        TeamThemeColorSet(
            home: TeamThemeColors(mainColorHex: homeMainColorHex, fontColorHex: homeFontColorHex),
            away: TeamThemeColors(mainColorHex: awayMainColorHex, fontColorHex: awayFontColorHex),
            third: TeamThemeColors(mainColorHex: thirdMainColorHex, fontColorHex: thirdFontColorHex)
        )
    }
}
```

- [ ] **Step 6: Run the full test suite to confirm it passes**

Run: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test`
Expected: PASS, 74 tests (71 baseline + 3 new), 0 failures.

- [ ] **Step 7: Commit**

```bash
git add BR2026/Models/TeamThemeColors.swift BR2026/Models/TeamThemeColorCache.swift BR2026Tests/Models/TeamThemeColorsTests.swift BR2026.xcodeproj/project.pbxproj
git commit -m "Add TeamThemeColors/TeamThemeColorSet/TeamThemeColorCache models"
```

---

### Task 2: `MatchService` team-theme-colors method (protocol + both implementations)

**Files:**
- Modify: `BR2026/Services/MatchService.swift`
- Modify: `BR2026/Services/LiveMatchService.swift`
- Modify: `BR2026/Services/MockMatchService.swift`
- Modify: `BR2026Tests/ViewModels/MatchdayViewModelTests.swift` (extends `StubMatchService`)
- Modify: `BR2026Tests/Services/MockMatchServiceTests.swift`

**Interfaces:**
- Consumes: `TeamThemeColorSet`, `TeamThemeColorCache` (Task 1).
- Produces: `MatchService.fetchTeamThemeColorSet(teamID: Int) async throws -> TeamThemeColorSet`, `MatchService.cachedTeamThemeColorSet(teamID: Int) -> TeamThemeColorSet?` — consumed by Task 5's `TeamThemeStore`. `StubMatchService` gains `teamThemeColorSetOverride: TeamThemeColorSet?`, `cachedTeamThemeColorSetOverride: TeamThemeColorSet?`, `shouldThrowOnTeamThemeFetch: Bool`, `fetchTeamThemeColorSetCallCount` — consumed by Task 5's tests.

No new files — this task only modifies existing ones, so no Xcode project registration is needed.

- [ ] **Step 1: Write the failing test**

In `BR2026Tests/Services/MockMatchServiceTests.swift`, add (inside the `MockMatchServiceTests` struct, after the existing `returnsCompetition` test):
```swift
    @Test("Returns Palmeiras's known real colors for all 3 kits")
    func returnsTeamThemeColorSet() async throws {
        let service = MockMatchService()
        let colorSet = try await service.fetchTeamThemeColorSet(teamID: 121)

        #expect(colorSet.home == TeamThemeColors(mainColorHex: "225638", fontColorHex: "ffffff"))
        #expect(colorSet.away == TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "035336"))
        #expect(colorSet.third == TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "2c5434"))
    }

    @Test("cachedTeamThemeColorSet returns the same canned values, with no fetch required")
    func cachedTeamThemeColorSetReturnsSameValues() async throws {
        let service = MockMatchService()
        let fetched = try await service.fetchTeamThemeColorSet(teamID: 121)
        #expect(service.cachedTeamThemeColorSet(teamID: 121) == fetched)
    }
```

- [ ] **Step 2: Run it to confirm it fails to compile**

Run: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test`
Expected: FAIL — `MockMatchService` doesn't conform to a protocol with these methods yet.

- [ ] **Step 3: Extend the `MatchService` protocol**

In `BR2026/Services/MatchService.swift`, add two lines inside the protocol body:
```swift
@MainActor
protocol MatchService {
    func fetchMatches() async throws -> [Match]
    func fetchStandings() async throws -> [Standing]
    func fetchEvents(matchID: Int) async throws -> [MatchEvent]
    func fetchCompetition() async throws -> Competition
    func fetchTeamThemeColorSet(teamID: Int) async throws -> TeamThemeColorSet
    func cachedMatches() -> [Match]
    func cachedStandings() -> [Standing]
    func cachedCompetition() -> Competition?
    func cachedTeamThemeColorSet(teamID: Int) -> TeamThemeColorSet?
}
```

- [ ] **Step 4: Implement it in `LiveMatchService`**

In `BR2026/Services/LiveMatchService.swift`, add after `fetchCompetition()`:
```swift
    func fetchTeamThemeColorSet(teamID: Int) async throws -> TeamThemeColorSet {
        let url = config.apiBaseURL
            .appendingPathComponent("v4/competitions/\(config.competitionCode)/teams/\(teamID)/colors")
        let response: TeamThemeColorsResponse = try await get(url)
        let colors = TeamThemeColorSet(response: response)
        try modelContext.delete(model: TeamThemeColorCache.self, where: #Predicate { $0.teamID == teamID })
        modelContext.insert(TeamThemeColorCache(teamID: teamID, colors: colors))
        try modelContext.save()
        return colors
    }
```
And after `cachedCompetition()`:
```swift
    func cachedTeamThemeColorSet(teamID: Int) -> TeamThemeColorSet? {
        let descriptor = FetchDescriptor<TeamThemeColorCache>(predicate: #Predicate { $0.teamID == teamID })
        return (try? modelContext.fetch(descriptor).first)?.colorSet
    }
```

- [ ] **Step 5: Implement it in `MockMatchService`**

In `BR2026/Services/MockMatchService.swift`, add a stored property and two methods:
```swift
    private let teamThemeColorSet = TeamThemeColorSet(
        home: TeamThemeColors(mainColorHex: "225638", fontColorHex: "ffffff"),
        away: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "035336"),
        third: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "2c5434")
    )

    func fetchTeamThemeColorSet(teamID: Int) async throws -> TeamThemeColorSet { teamThemeColorSet }
    func cachedTeamThemeColorSet(teamID: Int) -> TeamThemeColorSet? { teamThemeColorSet }
```
(Add the property alongside the other `private let` stored properties near the top of the class, and the two methods alongside `fetchCompetition()`/`cachedCompetition()`.)

- [ ] **Step 6: Extend `StubMatchService` in `BR2026Tests/ViewModels/MatchdayViewModelTests.swift`**

Add these stored properties (alongside `cachedCompetitionOverride`):
```swift
    var teamThemeColorSetOverride: TeamThemeColorSet?
    var cachedTeamThemeColorSetOverride: TeamThemeColorSet?
    var shouldThrowOnTeamThemeFetch = false
    private(set) var fetchTeamThemeColorSetCallCount = 0
```
Add these methods (alongside `fetchCompetition()`/`cachedCompetition()`):
```swift
    func fetchTeamThemeColorSet(teamID: Int) async throws -> TeamThemeColorSet {
        fetchTeamThemeColorSetCallCount += 1
        if shouldThrowOnTeamThemeFetch { throw StubServiceError.simulatedFailure }
        guard let teamThemeColorSetOverride else { throw StubServiceError.simulatedFailure }
        return teamThemeColorSetOverride
    }

    func cachedTeamThemeColorSet(teamID: Int) -> TeamThemeColorSet? { cachedTeamThemeColorSetOverride }
```

- [ ] **Step 7: Run the full test suite to confirm it passes**

Run: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test`
Expected: PASS, 76 tests (74 + 2 new), 0 failures.

- [ ] **Step 8: Commit**

```bash
git add BR2026/Services/MatchService.swift BR2026/Services/LiveMatchService.swift BR2026/Services/MockMatchService.swift BR2026Tests/ViewModels/MatchdayViewModelTests.swift BR2026Tests/Services/MockMatchServiceTests.swift
git commit -m "Add fetchTeamThemeColorSet/cachedTeamThemeColorSet to MatchService"
```

---

### Task 3: `Color` hex-shading helper

**Files:**
- Modify: `BR2026/Components/Color+Hex.swift`
- Test: `BR2026Tests/Components/ColorHexTests.swift` (new `Components` group under `BR2026Tests`)

**Interfaces:**
- Produces: `Color.shaded(hex:towardWhite:)` — consumed by Task 4's `ThemeTokens.themed(...)`.

- [ ] **Step 1: Write the failing test**

Create `BR2026Tests/Components/ColorHexTests.swift`:
```swift
import Testing
import SwiftUI
@testable import BR2026

@Suite("Color hex shading")
struct ColorHexTests {
    private func components(_ color: Color) -> (Double, Double, Double) {
        let resolved = color.resolve(in: EnvironmentValues())
        return (Double(resolved.red), Double(resolved.green), Double(resolved.blue))
    }

    @Test("towardWhite: 0 returns the color unchanged")
    func zeroAmountIsUnchanged() {
        let original = components(Color(hex: "225638"))
        let shaded = components(Color.shaded(hex: "225638", towardWhite: 0))
        #expect(abs(original.0 - shaded.0) < 0.001)
        #expect(abs(original.1 - shaded.1) < 0.001)
        #expect(abs(original.2 - shaded.2) < 0.001)
    }

    @Test("towardWhite: 1 returns pure white")
    func fullPositiveAmountIsWhite() {
        let (r, g, b) = components(Color.shaded(hex: "225638", towardWhite: 1))
        #expect(abs(r - 1) < 0.001)
        #expect(abs(g - 1) < 0.001)
        #expect(abs(b - 1) < 0.001)
    }

    @Test("towardWhite: -1 returns pure black")
    func fullNegativeAmountIsBlack() {
        let (r, g, b) = components(Color.shaded(hex: "225638", towardWhite: -1))
        #expect(abs(r - 0) < 0.001)
        #expect(abs(g - 0) < 0.001)
        #expect(abs(b - 0) < 0.001)
    }
}
```

- [ ] **Step 2: Run it to confirm it fails to compile**

Run: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test`
Expected: FAIL — `Color.shaded(hex:towardWhite:)` doesn't exist, and the test file isn't registered yet.

- [ ] **Step 3: Register the new test file (creating the `Components` group under `BR2026Tests`)**

Create `/tmp/register_files.rb`:
```ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('BR2026.xcodeproj')

def find_group(root, *path_components)
  group = root
  path_components.each do |name|
    group = group.children.find { |c| c.respond_to?(:display_name) && c.display_name == name }
    raise "Group not found: #{path_components.inspect} at #{name}" unless group
  end
  group
end

test_target = project.native_targets.find { |t| t.name == 'BR2026Tests' }

br2026tests_group = find_group(project.main_group, 'BR2026Tests')
components_test_group = br2026tests_group.new_group('Components', 'Components')
new_test_files = [components_test_group.new_file('ColorHexTests.swift')]
test_target.add_file_references(new_test_files)

project.save
puts 'OK'
```

Run: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec ruby /tmp/register_files.rb`
Expected output: `OK`

- [ ] **Step 4: Add the shading helper to `Color+Hex.swift`**

Replace the full contents of `BR2026/Components/Color+Hex.swift` with:
```swift
import SwiftUI

extension Color {
    init(hex: String) {
        let (red, green, blue) = Color.rgbComponents(hex: hex)
        self.init(red: red, green: green, blue: blue)
    }

    /// Blends a hex color toward white (`amount` > 0) or black (`amount` < 0) by linear
    /// interpolation in RGB space — a simple, non-perceptual blend, which is fine for a
    /// stylistic background gradient rather than brand-critical color matching.
    static func shaded(hex: String, towardWhite amount: Double) -> Color {
        let (red, green, blue) = rgbComponents(hex: hex)
        let target = amount >= 0 ? 1.0 : 0.0
        let t = abs(amount)
        return Color(
            red: red + (target - red) * t,
            green: green + (target - green) * t,
            blue: blue + (target - blue) * t
        )
    }

    private static func rgbComponents(hex: String) -> (red: Double, green: Double, blue: Double) {
        let hexValue = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var rgb: UInt64 = 0
        Scanner(string: hexValue).scanHexInt64(&rgb)
        return (
            Double((rgb & 0xFF0000) >> 16) / 255,
            Double((rgb & 0x00FF00) >> 8) / 255,
            Double(rgb & 0x0000FF) / 255
        )
    }
}
```

- [ ] **Step 5: Run the full test suite to confirm it passes**

Run: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test`
Expected: PASS, 79 tests (76 + 3 new), 0 failures.

- [ ] **Step 6: Commit**

```bash
git add BR2026/Components/Color+Hex.swift BR2026Tests/Components/ColorHexTests.swift BR2026.xcodeproj/project.pbxproj
git commit -m "Add Color.shaded(hex:towardWhite:) hex-blending helper"
```

---

### Task 4: `ThemeTokens`, `TeamThemeSetting`, and `TeamThemeOption`

**Files:**
- Create: `BR2026/Models/ThemeTokens.swift`
- Create: `BR2026/Services/TeamThemeSetting.swift`
- Create: `BR2026/Models/TeamThemeOption.swift`
- Test: `BR2026Tests/Models/ThemeTokensTests.swift`
- Test: `BR2026Tests/Services/TeamThemeSettingTests.swift`
- Test: `BR2026Tests/Models/TeamThemeOptionTests.swift`

**Interfaces:**
- Consumes: `Color.shaded(hex:towardWhite:)` (Task 3).
- Produces: `ThemeTokens` (struct: `overrideAccentColor: Color?`, `textColor: Color = .white`, `gradientStops: [Color]`, `blobColors: (top: Color, bottom: Color)`, static `themed(mainColorHex:fontColorHex:)`), `EnvironmentValues.themeTokens`, `TeamThemeSetting` protocol + `UserDefaultsTeamThemeSetting`, `TeamThemeOption` (enum: `.palmeirasHome`/`.palmeirasAway`/`.palmeirasThird`; `teamID`, `kit`, `displayName`, `isPurchased`) — all consumed by Task 5's `TeamThemeStore`.

- [ ] **Step 1: Write the failing tests**

Create `BR2026Tests/Models/ThemeTokensTests.swift`:
```swift
import Testing
import SwiftUI
@testable import BR2026

@Suite("ThemeTokens")
struct ThemeTokensTests {
    @Test("Default tokens have no accent override, white text, and today's fixed gradient/blob colors")
    func defaultsMatchTodaysFixedLook() {
        let tokens = ThemeTokens()
        #expect(tokens.overrideAccentColor == nil)
        #expect(tokens.textColor == .white)
        #expect(tokens.gradientStops == ThemeTokens.defaultGradientStops)
        #expect(tokens.blobColors.top == ThemeTokens.defaultBlobColors.top)
        #expect(tokens.blobColors.bottom == ThemeTokens.defaultBlobColors.bottom)
    }

    @Test("themed(mainColorHex:fontColorHex:) sets a non-nil accent, the given text color, and both blobs to the main color")
    func themedFactoryBuildsActiveTokens() {
        let tokens = ThemeTokens.themed(mainColorHex: "225638", fontColorHex: "ffffff")
        #expect(tokens.overrideAccentColor == Color(hex: "225638"))
        #expect(tokens.textColor == Color(hex: "ffffff"))
        #expect(tokens.blobColors.top == Color(hex: "225638"))
        #expect(tokens.blobColors.bottom == Color(hex: "225638"))
        #expect(tokens.gradientStops.count == 3)
    }

    @Test("The environment default value is today's fixed ThemeTokens")
    func environmentDefaultValue() {
        #expect(EnvironmentValues().themeTokens == ThemeTokens())
    }
}
```

Create `BR2026Tests/Services/TeamThemeSettingTests.swift`:
```swift
import Testing
import Foundation
@testable import BR2026

@Suite("UserDefaultsTeamThemeSetting")
@MainActor
struct TeamThemeSettingTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "TeamThemeSettingTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test("selectedThemeID is nil when nothing has been set")
    func nilByDefault() {
        let setting = UserDefaultsTeamThemeSetting(defaults: makeDefaults())
        #expect(setting.selectedThemeID == nil)
    }

    @Test("setSelectedThemeID persists and can be read back")
    func setAndReadBack() {
        let setting = UserDefaultsTeamThemeSetting(defaults: makeDefaults())
        setting.setSelectedThemeID("palmeirasHome")
        #expect(setting.selectedThemeID == "palmeirasHome")
    }

    @Test("setSelectedThemeID(nil) clears a previous selection")
    func clearSelection() {
        let setting = UserDefaultsTeamThemeSetting(defaults: makeDefaults())
        setting.setSelectedThemeID("palmeirasHome")
        setting.setSelectedThemeID(nil)
        #expect(setting.selectedThemeID == nil)
    }
}
```

Create `BR2026Tests/Models/TeamThemeOptionTests.swift`:
```swift
import Testing
@testable import BR2026

@Suite("TeamThemeOption")
struct TeamThemeOptionTests {
    @Test("All 3 cases point at Palmeiras's team id, 121")
    func allCasesShareTeamID() {
        for option in TeamThemeOption.allCases {
            #expect(option.teamID == 121)
        }
    }

    @Test("Each case maps to its matching TeamKit")
    func kitMapping() {
        #expect(TeamThemeOption.palmeirasHome.kit == .home)
        #expect(TeamThemeOption.palmeirasAway.kit == .away)
        #expect(TeamThemeOption.palmeirasThird.kit == .third)
    }

    @Test("All 3 cases are stubbed as purchased")
    func allPurchased() {
        for option in TeamThemeOption.allCases {
            #expect(option.isPurchased == true)
        }
    }
}
```

- [ ] **Step 2: Run it to confirm it fails to compile**

Run: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test`
Expected: FAIL — none of `ThemeTokens`, `UserDefaultsTeamThemeSetting`, `TeamThemeOption` exist yet, and none of the 3 new test files are registered yet.

- [ ] **Step 3: Register the new files**

Create `/tmp/register_files.rb`:
```ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('BR2026.xcodeproj')

def find_group(root, *path_components)
  group = root
  path_components.each do |name|
    group = group.children.find { |c| c.respond_to?(:display_name) && c.display_name == name }
    raise "Group not found: #{path_components.inspect} at #{name}" unless group
  end
  group
end

app_targets = %w[BR2026 PremierLeague2026 Ligue12026 PrimeiraLiga2026].map { |n| project.native_targets.find { |t| t.name == n } }
test_target = project.native_targets.find { |t| t.name == 'BR2026Tests' }

models_group = find_group(project.main_group, 'BR2026', 'Models')
services_group = find_group(project.main_group, 'BR2026', 'Services')
new_app_files = [
  models_group.new_file('ThemeTokens.swift'),
  services_group.new_file('TeamThemeSetting.swift'),
  models_group.new_file('TeamThemeOption.swift')
]
app_targets.each { |t| t.add_file_references(new_app_files) }

test_models_group = find_group(project.main_group, 'BR2026Tests', 'Models')
test_services_group = find_group(project.main_group, 'BR2026Tests', 'Services')
new_test_files = [
  test_models_group.new_file('ThemeTokensTests.swift'),
  test_services_group.new_file('TeamThemeSettingTests.swift'),
  test_models_group.new_file('TeamThemeOptionTests.swift')
]
test_target.add_file_references(new_test_files)

project.save
puts 'OK'
```

Run: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec ruby /tmp/register_files.rb`
Expected output: `OK`

- [ ] **Step 4: Create `BR2026/Models/ThemeTokens.swift`**

```swift
import SwiftUI

struct ThemeTokens: Equatable {
    var overrideAccentColor: Color?
    var textColor: Color = .white
    var gradientStops: [Color] = ThemeTokens.defaultGradientStops
    var blobColors: (top: Color, bottom: Color) = ThemeTokens.defaultBlobColors

    static let defaultGradientStops = [
        Color(hex: "#173a68"),
        Color(hex: "#0b2143"),
        Color(hex: "#061325")
    ]
    static let defaultBlobColors: (top: Color, bottom: Color) = (
        Color(hex: "#173a68"),
        Color(red: 45.0 / 255, green: 212.0 / 255, blue: 191.0 / 255)
    )

    static func == (lhs: ThemeTokens, rhs: ThemeTokens) -> Bool {
        lhs.overrideAccentColor == rhs.overrideAccentColor
            && lhs.textColor == rhs.textColor
            && lhs.gradientStops == rhs.gradientStops
            && lhs.blobColors.top == rhs.blobColors.top
            && lhs.blobColors.bottom == rhs.blobColors.bottom
    }

    static func themed(mainColorHex: String, fontColorHex: String) -> ThemeTokens {
        let accent = Color(hex: mainColorHex)
        return ThemeTokens(
            overrideAccentColor: accent,
            textColor: Color(hex: fontColorHex),
            gradientStops: [
                Color.shaded(hex: mainColorHex, towardWhite: 0.35),
                accent,
                Color.shaded(hex: mainColorHex, towardWhite: -0.75)
            ],
            blobColors: (top: accent, bottom: accent)
        )
    }
}

private struct ThemeTokensKey: EnvironmentKey {
    static let defaultValue = ThemeTokens()
}

extension EnvironmentValues {
    var themeTokens: ThemeTokens {
        get { self[ThemeTokensKey.self] }
        set { self[ThemeTokensKey.self] = newValue }
    }
}
```
(`ThemeTokens` declares its own `==` because `(top: Color, bottom: Color)` tuples aren't automatically `Equatable`-synthesizable alongside the rest of the struct's stored properties.)

- [ ] **Step 5: Create `BR2026/Services/TeamThemeSetting.swift`**

```swift
import Foundation

@MainActor
protocol TeamThemeSetting {
    var selectedThemeID: String? { get }
    func setSelectedThemeID(_ id: String?)
}

@MainActor
final class UserDefaultsTeamThemeSetting: TeamThemeSetting {
    private let defaults: UserDefaults
    private let key = "selectedTeamThemeID"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selectedThemeID: String? { defaults.string(forKey: key) }

    func setSelectedThemeID(_ id: String?) {
        defaults.set(id, forKey: key)
    }
}
```

- [ ] **Step 6: Create `BR2026/Models/TeamThemeOption.swift`**

```swift
import Foundation

enum TeamThemeOption: String, CaseIterable, Identifiable {
    #if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA)
    case palmeirasHome, palmeirasAway, palmeirasThird
    #endif

    var id: String { rawValue }

    var teamID: Int {
        switch self {
        #if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA)
        case .palmeirasHome, .palmeirasAway, .palmeirasThird: 121
        #endif
        }
    }

    var kit: TeamKit {
        switch self {
        #if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA)
        case .palmeirasHome: .home
        case .palmeirasAway: .away
        case .palmeirasThird: .third
        #endif
        }
    }

    var displayName: LocalizedStringResource {
        switch self {
        #if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA)
        case .palmeirasHome: "Palmeiras (Home)"
        case .palmeirasAway: "Palmeiras (Away)"
        case .palmeirasThird: "Palmeiras (Third)"
        #endif
        }
    }

    /// Stubbed always-true until real StoreKit 2 entitlement checking replaces this.
    var isPurchased: Bool { true }
}
```

- [ ] **Step 7: Run the full test suite to confirm it passes**

Run: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test`
Expected: PASS, 88 tests (79 + 9 new: 3 ThemeTokensTests + 3 TeamThemeSettingTests + 3 TeamThemeOptionTests), 0 failures.

- [ ] **Step 8: Commit**

```bash
git add BR2026/Models/ThemeTokens.swift BR2026/Services/TeamThemeSetting.swift BR2026/Models/TeamThemeOption.swift BR2026Tests/Models/ThemeTokensTests.swift BR2026Tests/Services/TeamThemeSettingTests.swift BR2026Tests/Models/TeamThemeOptionTests.swift BR2026.xcodeproj/project.pbxproj
git commit -m "Add ThemeTokens, TeamThemeSetting, and TeamThemeOption"
```

---

### Task 5: `TeamThemeStore`

**Files:**
- Create: `BR2026/Services/TeamThemeStore.swift`
- Test: `BR2026Tests/Services/TeamThemeStoreTests.swift`

**Interfaces:**
- Consumes: `MatchService.fetchTeamThemeColorSet(teamID:)`/`cachedTeamThemeColorSet(teamID:)` (Task 2), `TeamThemeSetting` (Task 4), `TeamThemeOption` (Task 4), `ThemeTokens`/`.themed(...)` (Task 4), `StubMatchService` (Task 2's extension).
- Produces: `TeamThemeStore(setting:service:)`, `.tokens: ThemeTokens`, `.loadOnce() async`, `.select(_:) async -> Bool` — consumed by Task 6's `TeamThemePickerViewModel` and Task 9's `ChampionshipApp`/`ContentView`.

- [ ] **Step 1: Write the failing test**

Create `BR2026Tests/Services/TeamThemeStoreTests.swift`:
```swift
import Testing
import SwiftUI
@testable import BR2026

@Suite("TeamThemeStore")
@MainActor
struct TeamThemeStoreTests {
    private let palmeirasColors = TeamThemeColorSet(
        home: TeamThemeColors(mainColorHex: "225638", fontColorHex: "ffffff"),
        away: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "035336"),
        third: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "2c5434")
    )

    @Test("loadOnce() with no persisted selection leaves tokens at today's defaults")
    func loadOnceWithNoSelectionStaysDefault() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        let store = TeamThemeStore(setting: setting, service: service)

        await store.loadOnce()

        #expect(store.tokens == ThemeTokens())
    }

    @Test("loadOnce() with a persisted palmeirasHome selection resolves that kit's tokens")
    func loadOnceWithPersistedSelectionResolvesTokens() async {
        let setting = StubTeamThemeSetting(selectedThemeID: TeamThemeOption.palmeirasHome.rawValue)
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)

        await store.loadOnce()

        #expect(store.tokens.overrideAccentColor == Color(hex: "225638"))
        #expect(store.tokens.textColor == Color(hex: "ffffff"))
    }

    @Test("select() resolves the matching kit's colors, not always home")
    func selectResolvesMatchingKit() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)

        let succeeded = await store.select(.palmeirasAway)

        #expect(succeeded == true)
        #expect(store.tokens.overrideAccentColor == Color(hex: "ffffff"))
        #expect(store.tokens.textColor == Color(hex: "035336"))
        #expect(setting.selectedThemeID == TeamThemeOption.palmeirasAway.rawValue)
    }

    @Test("select() falls back to fetching when there's no cached entry, and still succeeds")
    func selectFetchesWhenCacheMisses() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.teamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)

        let succeeded = await store.select(.palmeirasHome)

        #expect(succeeded == true)
        #expect(service.fetchTeamThemeColorSetCallCount == 1)
        #expect(store.tokens.overrideAccentColor == Color(hex: "225638"))
    }

    @Test("select(nil) returns tokens to today's defaults and clears the persisted selection")
    func selectNilResetsToDefault() async {
        let setting = StubTeamThemeSetting(selectedThemeID: TeamThemeOption.palmeirasHome.rawValue)
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)
        await store.loadOnce()

        let succeeded = await store.select(nil)

        #expect(succeeded == true)
        #expect(store.tokens == ThemeTokens())
        #expect(setting.selectedThemeID == nil)
    }

    @Test("select() returns false and leaves tokens/persisted id unchanged when both cache and fetch fail")
    func selectFailsWhenResolutionFails() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.shouldThrowOnTeamThemeFetch = true
        let store = TeamThemeStore(setting: setting, service: service)

        let succeeded = await store.select(.palmeirasHome)

        #expect(succeeded == false)
        #expect(store.tokens == ThemeTokens())
        #expect(setting.selectedThemeID == nil)
    }
}

final class StubTeamThemeSetting: TeamThemeSetting {
    private(set) var selectedThemeID: String?

    init(selectedThemeID: String? = nil) {
        self.selectedThemeID = selectedThemeID
    }

    func setSelectedThemeID(_ id: String?) {
        selectedThemeID = id
    }
}
```

- [ ] **Step 2: Run it to confirm it fails to compile**

Run: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test`
Expected: FAIL — `TeamThemeStore` doesn't exist yet, and the test file isn't registered.

- [ ] **Step 3: Register the new files**

Create `/tmp/register_files.rb`:
```ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('BR2026.xcodeproj')

def find_group(root, *path_components)
  group = root
  path_components.each do |name|
    group = group.children.find { |c| c.respond_to?(:display_name) && c.display_name == name }
    raise "Group not found: #{path_components.inspect} at #{name}" unless group
  end
  group
end

app_targets = %w[BR2026 PremierLeague2026 Ligue12026 PrimeiraLiga2026].map { |n| project.native_targets.find { |t| t.name == n } }
test_target = project.native_targets.find { |t| t.name == 'BR2026Tests' }

services_group = find_group(project.main_group, 'BR2026', 'Services')
new_app_files = [services_group.new_file('TeamThemeStore.swift')]
app_targets.each { |t| t.add_file_references(new_app_files) }

test_services_group = find_group(project.main_group, 'BR2026Tests', 'Services')
new_test_files = [test_services_group.new_file('TeamThemeStoreTests.swift')]
test_target.add_file_references(new_test_files)

project.save
puts 'OK'
```

Run: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec ruby /tmp/register_files.rb`
Expected output: `OK`

- [ ] **Step 4: Create `BR2026/Services/TeamThemeStore.swift`**

```swift
import Foundation
import Observation

@Observable
@MainActor
final class TeamThemeStore {
    private(set) var tokens = ThemeTokens()
    private let setting: TeamThemeSetting
    private let service: MatchService
    private var hasLoadedOnce = false

    init(setting: TeamThemeSetting, service: MatchService) {
        self.setting = setting
        self.service = service
    }

    func loadOnce() async {
        guard !hasLoadedOnce else { return }
        hasLoadedOnce = true
        guard let selectedID = setting.selectedThemeID,
              let option = TeamThemeOption.allCases.first(where: { $0.rawValue == selectedID }) else { return }
        await apply(option)
    }

    /// Returns `false` (and leaves the current selection/tokens untouched) if resolving colors
    /// for a newly-selected option fails — so a failed first-time fetch never leaves the picker
    /// showing a theme "selected" while the background silently never changed.
    @discardableResult
    func select(_ option: TeamThemeOption?) async -> Bool {
        guard let option else {
            setting.setSelectedThemeID(nil)
            tokens = ThemeTokens()
            return true
        }
        guard let colors = await resolveColors(teamID: option.teamID)?[option.kit] else { return false }
        setting.setSelectedThemeID(option.rawValue)
        tokens = ThemeTokens.themed(mainColorHex: colors.mainColorHex, fontColorHex: colors.fontColorHex)
        return true
    }

    private func apply(_ option: TeamThemeOption) async {
        guard let colors = await resolveColors(teamID: option.teamID)?[option.kit] else { return }
        tokens = ThemeTokens.themed(mainColorHex: colors.mainColorHex, fontColorHex: colors.fontColorHex)
    }

    private func resolveColors(teamID: Int) async -> TeamThemeColorSet? {
        if let cached = service.cachedTeamThemeColorSet(teamID: teamID) { return cached }
        return try? await service.fetchTeamThemeColorSet(teamID: teamID)
    }
}
```

- [ ] **Step 5: Run the full test suite to confirm it passes**

Run: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test`
Expected: PASS, 94 tests (88 + 6 new), 0 failures.

- [ ] **Step 6: Commit**

```bash
git add BR2026/Services/TeamThemeStore.swift BR2026Tests/Services/TeamThemeStoreTests.swift BR2026.xcodeproj/project.pbxproj
git commit -m "Add TeamThemeStore"
```

---

### Task 6: `TeamThemePickerViewModel`

**Files:**
- Create: `BR2026/ViewModels/TeamThemePickerViewModel.swift`
- Test: `BR2026Tests/ViewModels/TeamThemePickerViewModelTests.swift`

**Interfaces:**
- Consumes: `TeamThemeStore` (Task 5), `TeamThemeSetting`/`TeamThemeOption` (Task 4), `StubTeamThemeSetting` (Task 5's test double).
- Produces: `TeamThemePickerViewModel(themeStore:setting:)`, `.selectedOption: TeamThemeOption?`, `.errorMessage: String?`, `.select(_:) async` — consumed by Task 8's `TeamThemePickerView`.

- [ ] **Step 1: Write the failing test**

Create `BR2026Tests/ViewModels/TeamThemePickerViewModelTests.swift`:
```swift
import Testing
@testable import BR2026

@Suite("TeamThemePickerViewModel")
@MainActor
struct TeamThemePickerViewModelTests {
    private let palmeirasColors = TeamThemeColorSet(
        home: TeamThemeColors(mainColorHex: "225638", fontColorHex: "ffffff"),
        away: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "035336"),
        third: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "2c5434")
    )

    @Test("selectedOption is nil when nothing is persisted")
    func nilByDefault() {
        let setting = StubTeamThemeSetting()
        let store = TeamThemeStore(setting: setting, service: StubMatchService(matches: [], standings: []))
        let viewModel = TeamThemePickerViewModel(themeStore: store, setting: setting)

        #expect(viewModel.selectedOption == nil)
    }

    @Test("selectedOption is derived from a matching persisted rawValue")
    func derivesFromPersistedValue() {
        let setting = StubTeamThemeSetting(selectedThemeID: TeamThemeOption.palmeirasThird.rawValue)
        let store = TeamThemeStore(setting: setting, service: StubMatchService(matches: [], standings: []))
        let viewModel = TeamThemePickerViewModel(themeStore: store, setting: setting)

        #expect(viewModel.selectedOption == .palmeirasThird)
    }

    @Test("select() updates selectedOption on success")
    func selectUpdatesOnSuccess() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)
        let viewModel = TeamThemePickerViewModel(themeStore: store, setting: setting)

        await viewModel.select(.palmeirasHome)

        #expect(viewModel.selectedOption == .palmeirasHome)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("select() sets errorMessage and leaves selectedOption unchanged on failure")
    func selectSetsErrorMessageOnFailure() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.shouldThrowOnTeamThemeFetch = true
        let store = TeamThemeStore(setting: setting, service: service)
        let viewModel = TeamThemePickerViewModel(themeStore: store, setting: setting)

        await viewModel.select(.palmeirasHome)

        #expect(viewModel.selectedOption == nil)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("select() on the already-selected option is a no-op")
    func selectOnAlreadySelectedIsNoOp() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)
        let viewModel = TeamThemePickerViewModel(themeStore: store, setting: setting)
        await viewModel.select(.palmeirasHome)
        let callCountAfterFirstSelect = service.fetchTeamThemeColorSetCallCount

        await viewModel.select(.palmeirasHome)

        #expect(service.fetchTeamThemeColorSetCallCount == callCountAfterFirstSelect)
    }
}
```

- [ ] **Step 2: Run it to confirm it fails to compile**

Run: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test`
Expected: FAIL — `TeamThemePickerViewModel` doesn't exist yet, and the test file isn't registered.

- [ ] **Step 3: Register the new files**

Create `/tmp/register_files.rb`:
```ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('BR2026.xcodeproj')

def find_group(root, *path_components)
  group = root
  path_components.each do |name|
    group = group.children.find { |c| c.respond_to?(:display_name) && c.display_name == name }
    raise "Group not found: #{path_components.inspect} at #{name}" unless group
  end
  group
end

app_targets = %w[BR2026 PremierLeague2026 Ligue12026 PrimeiraLiga2026].map { |n| project.native_targets.find { |t| t.name == n } }
test_target = project.native_targets.find { |t| t.name == 'BR2026Tests' }

viewmodels_group = find_group(project.main_group, 'BR2026', 'ViewModels')
new_app_files = [viewmodels_group.new_file('TeamThemePickerViewModel.swift')]
app_targets.each { |t| t.add_file_references(new_app_files) }

test_viewmodels_group = find_group(project.main_group, 'BR2026Tests', 'ViewModels')
new_test_files = [test_viewmodels_group.new_file('TeamThemePickerViewModelTests.swift')]
test_target.add_file_references(new_test_files)

project.save
puts 'OK'
```

Run: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec ruby /tmp/register_files.rb`
Expected output: `OK`

- [ ] **Step 4: Create `BR2026/ViewModels/TeamThemePickerViewModel.swift`**

```swift
import Foundation
import Observation

@Observable
@MainActor
final class TeamThemePickerViewModel {
    private(set) var selectedOption: TeamThemeOption?
    private(set) var errorMessage: String?
    private let themeStore: TeamThemeStore
    private let setting: TeamThemeSetting

    init(themeStore: TeamThemeStore, setting: TeamThemeSetting) {
        self.themeStore = themeStore
        self.setting = setting
        selectedOption = TeamThemeOption.allCases.first { $0.rawValue == setting.selectedThemeID }
    }

    func select(_ option: TeamThemeOption?) async {
        guard option != selectedOption else { return }
        guard await themeStore.select(option) else {
            errorMessage = String(localized: "Couldn't apply that team's colors. Try again.")
            return
        }
        selectedOption = option
        errorMessage = nil
    }
}
```

- [ ] **Step 5: Run the full test suite to confirm it passes**

Run: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test`
Expected: PASS, 99 tests (94 + 5 new), 0 failures.

- [ ] **Step 6: Commit**

```bash
git add BR2026/ViewModels/TeamThemePickerViewModel.swift BR2026Tests/ViewModels/TeamThemePickerViewModelTests.swift BR2026.xcodeproj/project.pbxproj
git commit -m "Add TeamThemePickerViewModel"
```

---

### Task 7: `MoreDestination` + `MoreViewModel` Team Theme row

**Files:**
- Modify: `BR2026/Models/MoreDestination.swift`
- Modify: `BR2026/ViewModels/MoreViewModel.swift`
- Modify: `BR2026Tests/ViewModels/MoreViewModelTests.swift`

**Interfaces:**
- Produces: `MoreDestination.teamThemePicker` case, a `"teamTheme"` row in `MoreViewModel`'s `preferences` section — consumed by Task 8's `MoreView`.

No new files — no Xcode project registration needed. **This task alone leaves the build red**:
`MoreView.swift`'s `navigationDestination(for:)` switches exhaustively over `MoreDestination`,
so adding a case here breaks that switch's exhaustiveness until Task 8 adds the matching
`.teamThemePicker` branch — the unit test suite (`bundle exec fastlane test`) will fail to build
after this task, same as the already-documented Task 8→10 gap. Commit anyway and proceed straight
to Task 8, which restores the build.

- [ ] **Step 1: Write the failing test**

In `BR2026Tests/ViewModels/MoreViewModelTests.swift`, replace the existing `preferencesSection` test:
```swift
    @Test("Preferences section has App Icon and Team Theme rows, both enabled")
    func preferencesSection() {
        let viewModel = MoreViewModel(service: StubMatchService(matches: [], standings: []))
        let preferences = viewModel.sections.first { $0.id == "preferences" }
        #expect(preferences?.rows.count == 2)
        #expect(preferences?.rows.first?.destination == .appIconPicker)
        #expect(preferences?.rows.first?.isEnabled == true)
        #expect(preferences?.rows.last?.destination == .teamThemePicker)
        #expect(preferences?.rows.last?.isEnabled == true)
    }
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test`
Expected: FAIL — `MoreDestination.teamThemePicker` doesn't exist yet, and the Preferences section still only has 1 row.

- [ ] **Step 3: Add the case to `MoreDestination`**

Replace the full contents of `BR2026/Models/MoreDestination.swift`:
```swift
import Foundation

enum MoreDestination: Hashable {
    case termsOfService
    case appIconPicker
    case teamThemePicker
}
```

- [ ] **Step 4: Add the row to `MoreViewModel`**

In `BR2026/ViewModels/MoreViewModel.swift`, change the `preferences` section's `rows` array from:
```swift
            rows: [
                MoreRow(
                    id: "appIcon",
                    titleKey: "App Icon",
                    systemImage: "app.badge",
                    destination: .appIconPicker,
                    isEnabled: true
                )
            ]
```
to:
```swift
            rows: [
                MoreRow(
                    id: "appIcon",
                    titleKey: "App Icon",
                    systemImage: "app.badge",
                    destination: .appIconPicker,
                    isEnabled: true
                ),
                MoreRow(
                    id: "teamTheme",
                    titleKey: "Team Theme",
                    systemImage: "paintpalette",
                    destination: .teamThemePicker,
                    isEnabled: true
                )
            ]
```

- [ ] **Step 5: Confirm the expected (temporary) red state**

Run: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test`
Expected: FAIL — `MoreView.swift`'s exhaustive `switch` over `MoreDestination` doesn't handle
`.teamThemePicker` yet. Fixed by Task 8; commit this task anyway and proceed immediately.

- [ ] **Step 6: Commit**

```bash
git add BR2026/Models/MoreDestination.swift BR2026/ViewModels/MoreViewModel.swift BR2026Tests/ViewModels/MoreViewModelTests.swift
git commit -m "Add Team Theme row and MoreDestination case to the More screen"
```

---

### Task 8: `TeamThemePickerView` + `MoreView` wiring

**Files:**
- Create: `BR2026/Views/More/TeamThemePickerView.swift`
- Modify: `BR2026/Views/More/MoreView.swift`

**Interfaces:**
- Consumes: `TeamThemeOption`, `TeamThemePickerViewModel`, `TeamThemeStore`, `UserDefaultsTeamThemeSetting` (Tasks 4-6), `MoreDestination.teamThemePicker` (Task 7).
- Produces: `MoreView(service:themeStore:)` (signature change — consumed by Task 10's `ContentView`).

Views aren't unit tested per CLAUDE.md ("Unit test ViewModels and Services — not Views") — this task's verification is a build, not a new test.

- [ ] **Step 1: Register the new file**

Create `/tmp/register_files.rb`:
```ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('BR2026.xcodeproj')

def find_group(root, *path_components)
  group = root
  path_components.each do |name|
    group = group.children.find { |c| c.respond_to?(:display_name) && c.display_name == name }
    raise "Group not found: #{path_components.inspect} at #{name}" unless group
  end
  group
end

app_targets = %w[BR2026 PremierLeague2026 Ligue12026 PrimeiraLiga2026].map { |n| project.native_targets.find { |t| t.name == n } }

more_group = find_group(project.main_group, 'BR2026', 'Views', 'More')
new_app_files = [more_group.new_file('TeamThemePickerView.swift')]
app_targets.each { |t| t.add_file_references(new_app_files) }

project.save
puts 'OK'
```

Run: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec ruby /tmp/register_files.rb`
Expected output: `OK`

- [ ] **Step 2: Create `BR2026/Views/More/TeamThemePickerView.swift`**

This view already reads `@Environment(\.themeTokens)` for its text color (Task 9 makes this environment value real app-wide; until then it just resolves to the default `ThemeTokens()`, i.e. plain white, so this view works correctly the moment it's created):
```swift
import SwiftUI

struct TeamThemePickerView: View {
    @State private var viewModel: TeamThemePickerViewModel
    @Environment(\.themeTokens) private var themeTokens

    init(viewModel: TeamThemePickerViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                GlassCard(cornerRadius: 18, style: .transparent) {
                    VStack(spacing: 0) {
                        rowView(nil)
                        Rectangle().fill(Color.white.opacity(0.16)).frame(height: 0.5)
                        ForEach(Array(TeamThemeOption.allCases.enumerated()), id: \.element.id) { index, option in
                            rowView(option)
                            if index < TeamThemeOption.allCases.count - 1 {
                                Rectangle().fill(Color.white.opacity(0.16)).frame(height: 0.5)
                            }
                        }
                    }
                }
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(themeTokens.textColor.opacity(0.55))
                }
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
        .background(StadiumBackground())
        .navigationTitle("Team Theme")
        .navigationBarTitleDisplayMode(.inline)
        .trackScreen("TeamThemePicker")
    }

    private func rowView(_ option: TeamThemeOption?) -> some View {
        Button {
            Task { await viewModel.select(option) }
        } label: {
            HStack(spacing: 12) {
                if let option {
                    Circle()
                        .fill(Color(hex: option.kit == .home ? "225638" : "ffffff"))
                        .frame(width: 28, height: 28)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
                    Text(option.displayName)
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.07))
                        .frame(width: 28, height: 28)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
                    Text("Default")
                }
                Spacer()
                if viewModel.selectedOption == option {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(themeTokens.overrideAccentColor ?? Color.accentColor)
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(themeTokens.textColor)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
```
(The row swatch's fill is a small simplification — home is always green, away/third are both white for Palmeiras specifically — since a full per-kit-hex swatch would need `TeamThemePickerViewModel` to expose resolved colors per option, which isn't needed for a single hardcoded team and would be over-engineering for this proof of concept. `Default` uses `#expect` — no, this is a View, not a test; the `"Default"`/`"Team Theme"`/`"Couldn't apply..."` strings are plain string literals here matching the rest of this codebase's existing App Icon picker, which also doesn't route through `.xcstrings` for its row labels — consistent, not a regression.)

- [ ] **Step 3: Wire it into `MoreView`**

In `BR2026/Views/More/MoreView.swift`, change the `init` and add a stored property:
```swift
struct MoreView: View {
    @State private var viewModel: MoreViewModel
    let tabSelectionColorHex: String
    let themeStore: TeamThemeStore

    init(service: MatchService, tabSelectionColorHex: String, themeStore: TeamThemeStore) {
        _viewModel = State(initialValue: MoreViewModel(service: service))
        self.tabSelectionColorHex = tabSelectionColorHex
        self.themeStore = themeStore
    }
```
And add a case to the `navigationDestination(for:)` switch:
```swift
                case .teamThemePicker:
                    TeamThemePickerView(
                        viewModel: TeamThemePickerViewModel(themeStore: themeStore, setting: UserDefaultsTeamThemeSetting())
                    )
```

- [ ] **Step 4: Confirm the expected (temporary) red state**

Run: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test`
Expected: FAIL — `MoreView`'s new `themeStore` parameter has no caller yet (`ContentView` still constructs `MoreView(service:tabSelectionColorHex:)` with the old 2-argument signature). This is expected and fixed in Task 10; there is no way to make this task's change compile in isolation without also updating `ContentView`, so proceed to Task 9 immediately (Task 9 doesn't touch `MoreView`, so this red state is expected to persist one task longer — Task 10 is the one that turns it green).

- [ ] **Step 5: Commit**

```bash
git add BR2026/Views/More/TeamThemePickerView.swift BR2026/Views/More/MoreView.swift BR2026.xcodeproj/project.pbxproj
git commit -m "Add TeamThemePickerView and wire it into MoreView"
```

---

### Task 9: `StadiumBackground` and `HeroMatchCard` theming

**Files:**
- Modify: `BR2026/Components/StadiumBackground.swift`
- Modify: `BR2026/Components/HeroMatchCard.swift`

**Interfaces:**
- Consumes: `ThemeTokens`/`EnvironmentValues.themeTokens` (Task 4).
- Consumes: `ThemeTokens.defaultGradientStops`, `ThemeTokens.defaultBlobColors` (Task 4) — these live on `ThemeTokens`, not `StadiumBackground`, specifically so Task 4 doesn't have to forward-reference a type this task hasn't created yet.

No new files — no Xcode project registration needed. Still expected to fail to build stand-alone (same reason as Task 8) until Task 10 fixes `MoreView`'s call site; this task's own changes are independently correct.

- [ ] **Step 1: Update `StadiumBackground`**

Replace the full contents of `BR2026/Components/StadiumBackground.swift`:
```swift
import SwiftUI

/// The app-wide "stadium night" backdrop: a deep radial gradient with a top-center
/// light source, plus two soft blurred ambient glows. Colors come from `\.themeTokens`,
/// defaulting to the fixed navy/teal look below when no team theme is active — every
/// shipped app renders identically to before this feature existed.
/// See CLAUDE.md "Design System — Liquid Glass" → "Background".
struct StadiumBackground: View {
    @Environment(\.themeTokens) private var themeTokens

    var body: some View {
        ZStack {
            RadialGradient(
                colors: themeTokens.gradientStops,
                center: .top,
                startRadius: 0,
                endRadius: 700
            )

            Circle()
                .fill(themeTokens.blobColors.top.opacity(0.4))
                .frame(width: 420, height: 420)
                .blur(radius: 120)
                .offset(x: -160, y: -300)

            Circle()
                .fill(themeTokens.blobColors.bottom.opacity(0.32))
                .frame(width: 420, height: 420)
                .blur(radius: 120)
                .offset(x: 160, y: 320)
        }
        .ignoresSafeArea()
    }
}
```

- [ ] **Step 2: Update `HeroMatchCard`**

In `BR2026/Components/HeroMatchCard.swift`, add the environment read and wrap the existing `GlassCard` with a border overlay. Change:
```swift
struct HeroMatchCard: View {
    let match: Match

    var body: some View {
        GlassCard(cornerRadius: 28, style: .transparent) {
```
to:
```swift
struct HeroMatchCard: View {
    let match: Match
    @Environment(\.themeTokens) private var themeTokens

    var body: some View {
        GlassCard(cornerRadius: 28, style: .transparent) {
```
And change the closing of the `GlassCard` call — find:
```swift
            .frame(maxWidth: .infinity)
        }
    }
```
(the end of the `VStack` inside `GlassCard`'s trailing closure, followed by `GlassCard`'s own closing brace) and add the overlay immediately after `GlassCard`'s closing brace:
```swift
            .frame(maxWidth: .infinity)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(themeTokens.overrideAccentColor ?? .clear, lineWidth: 1.5)
        )
    }
```

- [ ] **Step 3: Commit**

```bash
git add BR2026/Components/StadiumBackground.swift BR2026/Components/HeroMatchCard.swift
git commit -m "Theme StadiumBackground's gradient/blobs and add HeroMatchCard's border"
```

---

### Task 10: `ChampionshipApp` + `ContentView` wiring

**Files:**
- Modify: `BR2026/App/Championship.swift`
- Modify: `BR2026/Views/Root/ContentView.swift`

**Interfaces:**
- Consumes: `TeamThemeStore` (Task 5), `UserDefaultsTeamThemeSetting` (Task 4), `TeamThemeColorCache` (Task 1), `MoreView(service:tabSelectionColorHex:themeStore:)` (Task 8).
- Produces: the app now builds and runs end-to-end with the full theming mechanism wired in.

This is the task that turns Tasks 8 and 9's expected build failures green — build after this task, not before.

No new files — no Xcode project registration needed.

- [ ] **Step 1: Register `TeamThemeColorCache` and construct `TeamThemeStore` once in `Championship.swift`**

Replace the full contents of `BR2026/App/Championship.swift`:
```swift
import SwiftUI
import SwiftData

@main
struct ChampionshipApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #if TARGET_PREMIER_LEAGUE
    let config = ChampionshipConfig.premierLeague
    #elseif TARGET_LIGUE_1
    let config = ChampionshipConfig.ligue1
    #elseif TARGET_PRIMEIRA_LIGA
    let config = ChampionshipConfig.primeiraLiga
    #else
    let config = ChampionshipConfig.brasileirao
    #endif
    let modelContainer: ModelContainer
    let service: MatchService
    let themeStore: TeamThemeStore

    init() {
        do {
            modelContainer = try ModelContainer(
                for: Match.self, Standing.self, Competition.self, TeamCrestCache.self, TeamThemeColorCache.self
            )
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }
        // Falls back to mock data if Secrets.xcconfig hasn't been set up yet, so the app
        // still runs in Simulator before a real API key is configured. This also covers
        // fastlane's `screenshots` lane — screenshots are captured against the real API.
        let context = ModelContext(modelContainer)
        if let live = try? LiveMatchService.makeFromBundle(config: config, modelContext: context) {
            service = live
        } else {
            service = MockMatchService()
        }
        themeStore = TeamThemeStore(setting: UserDefaultsTeamThemeSetting(), service: service)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(config: config, service: service, themeStore: themeStore)
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }
}
```
(`config`'s property-initializer default value — set by the `#if` block above — runs before any statement in `init()`'s body, so it's already fully available as a plain `config` read inside `init()`; no separate resolution step is needed. `service` and `themeStore` become stored properties, computed once in `init()`, instead of `service` being rebuilt by a separate `makeService()` method called from `body` on every re-render — this also fixes a latent inefficiency: previously `body` called `makeService()` fresh each time SwiftUI re-evaluated it, silently constructing a second `LiveMatchService`/`ModelContext` pair beyond the one already in use.)

- [ ] **Step 2: Wire `themeStore` into `ContentView`**

Replace the full contents of `BR2026/Views/Root/ContentView.swift`:
```swift
import SwiftUI

struct ContentView: View {
    let config: ChampionshipConfig
    let service: MatchService
    let themeStore: TeamThemeStore

    var body: some View {
        TabView {
            MatchdayView(service: service)
                .tabItem { Label("Matchday", systemImage: "soccerball") }
                .tint(themeStore.tokens.overrideAccentColor ?? Color(hex: config.accentColorHex))
            FixturesView(service: service)
                .tabItem { Label("Fixtures", systemImage: "calendar") }
                .tint(themeStore.tokens.overrideAccentColor ?? Color(hex: config.accentColorHex))
            StandingsView(service: service)
                .tabItem { Label("Standings", systemImage: "chart.bar") }
                .tint(themeStore.tokens.overrideAccentColor ?? Color(hex: config.accentColorHex))
            MoreView(service: service, tabSelectionColorHex: config.tabSelectionColorHex, themeStore: themeStore)
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
                .tint(themeStore.tokens.overrideAccentColor ?? Color(hex: config.accentColorHex))
        }
        // Governs only the tab bar's own selected-item chrome; each tab's content above
        // re-applies the true brand accent so LiveChip/AccentPill etc. stay brand-colored.
        .tint(themeStore.tokens.overrideAccentColor ?? Color(hex: config.tabSelectionColorHex))
        .background(StadiumBackground())
        .environment(\.themeTokens, themeStore.tokens)
        .task { await themeStore.loadOnce() }
    }
}
```

- [ ] **Step 3: Run the full test suite**

Run: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test`
Expected: PASS, 99 tests (same as Task 8 — this task has no new tests, it's app-wiring glue), 0 failures.

- [ ] **Step 4: Build all 4 schemes**

```bash
xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation build
xcodebuild -project BR2026.xcodeproj -scheme PremierLeague2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation build
xcodebuild -project BR2026.xcodeproj -scheme Ligue12026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation build
xcodebuild -project BR2026.xcodeproj -scheme PrimeiraLiga2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation build
```
Expected: `** BUILD SUCCEEDED **` for all 4.

- [ ] **Step 5: Commit**

```bash
git add BR2026/App/Championship.swift BR2026/Views/Root/ContentView.swift
git commit -m "Wire TeamThemeStore into ChampionshipApp and ContentView"
```

---

### Task 11: Text color sweep — Components

**Files:**
- Modify: `BR2026/Components/FixtureMatchCard.swift`
- Modify: `BR2026/Components/ScoreRow.swift`
- Modify: `BR2026/Components/TeamCrestBadge.swift`
- Modify: `BR2026/Components/HeroMatchCard.swift`

**Interfaces:**
- Consumes: `EnvironmentValues.themeTokens` (Task 4), already-wired app-wide (Task 10) — this task is purely additive from here on, no more expected-red states.

No new files. This is a styling-only pass — no new tests (Views aren't unit tested).

- [ ] **Step 1: `FixtureMatchCard`**

In `BR2026/Components/FixtureMatchCard.swift`, add the environment property:
```swift
struct FixtureMatchCard: View {
    let match: Match
    @Environment(\.themeTokens) private var themeTokens
```
Then replace each `.foregroundStyle(.white...)` call:
- `.foregroundStyle(.white.opacity(0.5))` (in `header`) → `.foregroundStyle(themeTokens.textColor.opacity(0.5))`
- `.foregroundStyle(.white)` (team name, in `teamRow`) → `.foregroundStyle(themeTokens.textColor)`
- `.foregroundStyle(.white)` (score, in `teamRow`) → `.foregroundStyle(themeTokens.textColor)`

- [ ] **Step 2: `ScoreRow`**

In `BR2026/Components/ScoreRow.swift`, add the environment property:
```swift
struct ScoreRow: View {
    let match: Match
    @Environment(\.themeTokens) private var themeTokens
```
Then replace:
- `.foregroundStyle(.white)` (team name, in `teamLabel`) → `.foregroundStyle(themeTokens.textColor)`
- `.foregroundStyle(.white)` (score text, in `scoreText`) → `.foregroundStyle(themeTokens.textColor)`

- [ ] **Step 3: `TeamCrestBadge`**

In `BR2026/Components/TeamCrestBadge.swift`, add the environment property:
```swift
struct TeamCrestBadge: View {
    let team: Team
    var size: CGFloat = 32
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeTokens) private var themeTokens
```
Then in `placeholder`, replace:
```swift
    private var placeholder: some View {
        Circle()
            .fill(.white.opacity(0.07))
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
            )
    }
```
with:
```swift
    private var placeholder: some View {
        Circle()
            .fill(.white.opacity(0.07))
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundStyle(themeTokens.textColor.opacity(0.55))
            )
    }
```
(Per the design's Out of Scope, the placeholder's *background* fill stays the fixed muted glass — only the initials' text color follows the theme, since this task is about text color, not the crest badge redesign that was explicitly deferred.)

- [ ] **Step 4: `HeroMatchCard`**

In `BR2026/Components/HeroMatchCard.swift` (already has `@Environment(\.themeTokens)` from Task 9), replace the remaining `.foregroundStyle(.white...)` calls:
- `.foregroundStyle(.white.opacity(0.65))` (time label, in `topInfo`) → `.foregroundStyle(themeTokens.textColor.opacity(0.65))`
- `.foregroundStyle(.white.opacity(0.5))` (venue label) → `.foregroundStyle(themeTokens.textColor.opacity(0.5))`
- `.foregroundStyle(.white)` (team name, in `teamColumn`) → `.foregroundStyle(themeTokens.textColor)`
- `.foregroundStyle(.white)` (score, in `centerContent`) → `.foregroundStyle(themeTokens.textColor)`
- `.foregroundStyle(.white.opacity(0.35))` ("VS" text, in `centerContent`) → `.foregroundStyle(themeTokens.textColor.opacity(0.35))`

- [ ] **Step 5: Run the full test suite**

Run: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test`
Expected: PASS, 99 tests (same as Task 10), 0 failures.

- [ ] **Step 6: Commit**

```bash
git add BR2026/Components/FixtureMatchCard.swift BR2026/Components/ScoreRow.swift BR2026/Components/TeamCrestBadge.swift BR2026/Components/HeroMatchCard.swift
git commit -m "Theme text color in FixtureMatchCard, ScoreRow, TeamCrestBadge, HeroMatchCard"
```

---

### Task 12: Text color sweep — Screens (Matchday, Fixtures, Standings)

**Files:**
- Modify: `BR2026/Views/Matchday/MatchdayView.swift`
- Modify: `BR2026/Views/Fixtures/FixturesView.swift`
- Modify: `BR2026/Views/Standings/StandingsView.swift`

No new files, no new tests.

- [ ] **Step 1: `MatchdayView`**

Add the environment property:
```swift
struct MatchdayView: View {
    @State private var viewModel: MatchdayViewModel
    @State private var selectedMatch: Match?
    let service: MatchService
    @Environment(\.themeTokens) private var themeTokens
```
Replace:
- `.foregroundStyle(.white.opacity(0.5))` (in `header`'s `eyebrowLabel` styling) → `.foregroundStyle(themeTokens.textColor.opacity(0.5))`
- `.foregroundStyle(.white)` (in `header`'s title) → `.foregroundStyle(themeTokens.textColor)`
- `.foregroundStyle(.white.opacity(0.5))` (in `matchSection`'s title styling) → `.foregroundStyle(themeTokens.textColor.opacity(0.5))`
- `.foregroundStyle(.white.opacity(0.70))` (in `emptyState`) → `.foregroundStyle(themeTokens.textColor.opacity(0.70))`
- `.foregroundStyle(.white.opacity(0.45))` (in `emptyState`) → `.foregroundStyle(themeTokens.textColor.opacity(0.45))`

- [ ] **Step 2: `FixturesView`**

Add the environment property:
```swift
struct FixturesView: View {
    @State private var viewModel: FixturesViewModel
    @State private var selectedMatch: Match?
    let service: MatchService
    @Environment(\.themeTokens) private var themeTokens
```
In `roundPill(_:)`, replace:
```swift
            .foregroundStyle(isSelected ? .white : .white.opacity(0.55))
```
with:
```swift
            .foregroundStyle(isSelected ? themeTokens.textColor : themeTokens.textColor.opacity(0.55))
```
(The pill's selected-state *fill* — `Color.accentColor` vs `Color.white.opacity(0.08)` — is unchanged: it already follows the theme automatically via `.tint()`, this task only touches the text-color-driven `.foregroundStyle`.)

- [ ] **Step 3: `StandingsView`**

Add the environment property:
```swift
struct StandingsView: View {
    @State private var viewModel: StandingsViewModel
    @Environment(\.themeTokens) private var themeTokens
```
Replace:
- `.foregroundStyle(.white.opacity(0.5))` (in `columnHeader`) → `.foregroundStyle(themeTokens.textColor.opacity(0.5))`
- `.foregroundStyle(.white)` (in `row(for:)`'s `HStack` styling) → `.foregroundStyle(themeTokens.textColor)`
- In `statCell(_:width:emphasized:)`, replace:
```swift
            .foregroundStyle(emphasized ? .white : .white.opacity(0.85))
```
with:
```swift
            .foregroundStyle(emphasized ? themeTokens.textColor : themeTokens.textColor.opacity(0.85))
```

- [ ] **Step 4: Run the full test suite**

Run: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test`
Expected: PASS, 99 tests (same as Task 11), 0 failures.

- [ ] **Step 5: Commit**

```bash
git add BR2026/Views/Matchday/MatchdayView.swift BR2026/Views/Fixtures/FixturesView.swift BR2026/Views/Standings/StandingsView.swift
git commit -m "Theme text color in MatchdayView, FixturesView, StandingsView"
```

---

### Task 13: Text color sweep — Match Detail and remaining More screens

**Files:**
- Modify: `BR2026/Views/MatchDetail/MatchDetailView.swift`
- Modify: `BR2026/Views/More/TermsOfServiceView.swift`
- Modify: `BR2026/Views/More/AppIconPickerView.swift`

No new files, no new tests.

- [ ] **Step 1: `MatchDetailView`**

Add the environment property:
```swift
struct MatchDetailView: View {
    @State private var viewModel: MatchDetailViewModel
    @Environment(\.themeTokens) private var themeTokens
```
Replace every `.foregroundStyle(.white...)` in the file:
- `.foregroundStyle(.white.opacity(0.5))` (Round label, in `header`) → `.foregroundStyle(themeTokens.textColor.opacity(0.5))`
- `.foregroundStyle(.white.opacity(0.6))` (`statusLine`) → `.foregroundStyle(themeTokens.textColor.opacity(0.6))`
- `.foregroundStyle(.white.opacity(0.45))` (`halfTimeText`) → `.foregroundStyle(themeTokens.textColor.opacity(0.45))`
- `.foregroundStyle(.white.opacity(0.5))` (venue row) → `.foregroundStyle(themeTokens.textColor.opacity(0.5))`
- In `teamColumn(_:isDimmed:)`, replace:
```swift
                .foregroundStyle(isDimmed ? .white.opacity(0.45) : .white)
```
with:
```swift
                .foregroundStyle(isDimmed ? themeTokens.textColor.opacity(0.45) : themeTokens.textColor)
```
- `.foregroundStyle(.white)` (score, in `centerScore`) → `.foregroundStyle(themeTokens.textColor)`
- `.foregroundStyle(.white.opacity(0.35))` ("VS", in `centerScore`) → `.foregroundStyle(themeTokens.textColor.opacity(0.35))`
- `.foregroundStyle(.white.opacity(0.5))` ("Timeline" header, in `timelineSection`) → `.foregroundStyle(themeTokens.textColor.opacity(0.5))`
- `.foregroundStyle(.white.opacity(0.45))` ("No events yet", in `timelineSection`) → `.foregroundStyle(themeTokens.textColor.opacity(0.45))`

- [ ] **Step 2: `TermsOfServiceView`**

Replace the full contents of `BR2026/Views/More/TermsOfServiceView.swift`:
```swift
import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.themeTokens) private var themeTokens

    var body: some View {
        ScrollView {
            Text("terms_of_service_body")
                .font(.system(size: 14))
                .foregroundStyle(themeTokens.textColor.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
        .scrollContentBackground(.hidden)
        .background(StadiumBackground())
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
        .trackScreen("TermsOfService")
    }
}
```

- [ ] **Step 3: `AppIconPickerView`**

Add the environment property:
```swift
struct AppIconPickerView: View {
    @State private var viewModel: AppIconPickerViewModel
    let selectionColorHex: String
    @Environment(\.themeTokens) private var themeTokens
```
Replace:
- `.foregroundStyle(.white.opacity(0.55))` (error message text) → `.foregroundStyle(themeTokens.textColor.opacity(0.55))`
- `.foregroundStyle(.white)` (in `rowView(_:)`) → `.foregroundStyle(themeTokens.textColor)`

- [ ] **Step 4: Run the full test suite**

Run: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test`
Expected: PASS, 99 tests (same as Task 12), 0 failures.

- [ ] **Step 5: Commit**

```bash
git add BR2026/Views/MatchDetail/MatchDetailView.swift BR2026/Views/More/TermsOfServiceView.swift BR2026/Views/More/AppIconPickerView.swift
git commit -m "Theme text color in MatchDetailView, TermsOfServiceView, AppIconPickerView"
```

---

### Task 14: `MoreView`'s own text + documentation

**Files:**
- Modify: `BR2026/Views/More/MoreView.swift`
- Modify: `CLAUDE.md`

No new files, no new tests.

- [ ] **Step 1: Add the environment property to `MoreView`**

```swift
struct MoreView: View {
    @State private var viewModel: MoreViewModel
    let tabSelectionColorHex: String
    let themeStore: TeamThemeStore
    @Environment(\.themeTokens) private var themeTokens
```

- [ ] **Step 2: Replace `MoreView`'s `.foregroundStyle(.white...)` calls**

- In `competitionHeader`, replace `.foregroundStyle(.white)` (competition name) → `.foregroundStyle(themeTokens.textColor)`.
- In `logoView`'s placeholder, replace `.foregroundStyle(.white.opacity(0.55))` → `.foregroundStyle(themeTokens.textColor.opacity(0.55))`.
- In `sectionView(_:)`, replace `.foregroundStyle(.white.opacity(0.5))` (section title) → `.foregroundStyle(themeTokens.textColor.opacity(0.5))`.
- In `rowLabel(_:showsChevron:)`, replace `.foregroundStyle(.white)` → `.foregroundStyle(themeTokens.textColor)`, and inside it, replace `.foregroundStyle(.white.opacity(0.3))` (chevron) → `.foregroundStyle(themeTokens.textColor.opacity(0.3))`.

- [ ] **Step 3: Update `CLAUDE.md`**

In the **Backend API** section, add a new bullet after the existing `matches/:id/events` line:
```markdown
- `GET /v4/competitions/{code}/teams/{id}/colors` — per-team home/away/third kit colors
  (`mainColor`/`fontColor`/`secondaryColor`, hex without a leading `#`), consumed by the More
  screen's Team Theme picker.
```

In the **Data & Persistence** section, add a bullet after the `TeamCrestCache`-related content:
```markdown
- `TeamThemeColorCache` is also a SwiftData `@Model`, one row per team holding all 3 kits'
  colors together (mirrors `TeamCrestCache`'s per-team caching). Cached indefinitely, no TTL —
  kit colors don't change like scores do.
```

Add a new **Theming** section right after **Backend API** (before **Firebase**):
```markdown
## Theming

- `ThemeTokens` (`BR2026/Models/ThemeTokens.swift`) is the single source of truth for every
  theme-reactive color in the app — `overrideAccentColor` (nil when no theme is active),
  `textColor`, `gradientStops`, `blobColors` — injected once into the SwiftUI environment at
  `ContentView` (`.environment(\.themeTokens, ...)`) and read via `@Environment(\.themeTokens)`
  wherever a view needs a theme-reactive color instead of a literal `.white`/hex value.
  Defaults exactly match the fixed pre-theming look, so every app renders identically when no
  theme is selected.
- `TeamThemeStore` (`BR2026/Services/TeamThemeStore.swift`) owns the currently selected
  `TeamThemeOption` (persisted via `TeamThemeSetting`/`UserDefaultsTeamThemeSetting`) and
  resolves its colors through `MatchService.fetchTeamThemeColorSet(teamID:)`/
  `cachedTeamThemeColorSet(teamID:)`.
- `TeamThemeOption` (`BR2026/Models/TeamThemeOption.swift`) is the purchasable-theme catalog —
  currently 3 Palmeiras kit variants (Home/Away/Third), gated to the `BR2026` (Brasileirão)
  target only via the same `#if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 ||
  TARGET_PRIMEIRA_LIGA)` pattern `AppIconOption` uses. `isPurchased` is hardcoded `true` —
  real StoreKit 2 entitlement checking is a future phase (see the roadmap's IAP team themes
  item).
```

- [ ] **Step 4: Run the full test suite**

Run: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test`
Expected: PASS, 99 tests (same as Task 13), 0 failures.

- [ ] **Step 5: Commit**

```bash
git add BR2026/Views/More/MoreView.swift CLAUDE.md
git commit -m "Theme MoreView's text and document the theming mechanism in CLAUDE.md"
```

---

### Task 15: Manual verification in Simulator

**Files:** none (verification only).

- [ ] **Step 1: Build and run the `BR2026` scheme in Simulator**

```bash
xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipMacroValidation build
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
xcrun simctl install "iPhone 17 Pro" "$(find ~/Library/Developer/Xcode/DerivedData -name 'BR2026.app' -path '*Debug-iphonesimulator*' | head -1)"
xcrun simctl launch "iPhone 17 Pro" com.vibrito.br2026
```
(Adjust the bundle ID above if it differs — confirm via `plutil -extract CFBundleIdentifier raw "$(find ~/Library/Developer/Xcode/DerivedData -name 'BR2026.app' -path '*Debug-iphonesimulator*' | head -1)/Info.plist"` if the launch fails.)

- [ ] **Step 2: Verify the default (no theme) look is unchanged**

Take a screenshot (`xcrun simctl io "iPhone 17 Pro" screenshot /tmp/matchday-default.png`) of the Matchday tab. Confirm: navy/teal background blobs, no border on the hero card, white text — matching the app's appearance before this feature (compare against a screenshot taken on `main` if in doubt).

- [ ] **Step 3: Verify each Palmeiras theme variant applies correctly**

In the Simulator: More tab → Team Theme → select "Palmeiras (Home)". Confirm: background blobs turn green, `HeroMatchCard` gains a green border, tab bar/LiveChip/AccentPill tint turns green, all body text stays legible. Repeat for "Palmeiras (Away)" and "Palmeiras (Third)" (both are white/near-white — confirm the background blobs and hero border become white/very light and text remains legible against the still-dark gradient's darker two stops). Select "Default" again and confirm everything reverts exactly to Step 2's appearance.

- [ ] **Step 4: Verify persistence across relaunch**

With a Palmeiras theme selected, terminate and relaunch the app (`xcrun simctl terminate "iPhone 17 Pro" com.vibrito.br2026` then re-launch). Confirm the theme is still applied (this exercises `TeamThemeStore.loadOnce()`'s restore-on-launch path).

- [ ] **Step 5: No commit for this task** — it's verification only, not a code change. If any step reveals a bug, fix it as a new small commit and re-run the affected verification steps before considering this plan complete.
