# More Screen: Competition Header + App Icon Switcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a competition header (logo + name, from the now-live `GET /v4/competitions/{code}`)
above the More screen's sections list, and turn the disabled "Settings" row into a working "App
Icon" picker with three options (Light, Brasil, Stadium), per
`docs/superpowers/specs/2026-07-12-more-screen-logo-and-icon-picker-design.md`.

**Architecture:** `MoreViewModel` gains a `MatchService` dependency (a deliberate departure from
its prior static-content design) to fetch `Competition`. The icon picker is a separate,
self-contained feature behind a small `AppIconSetting` protocol abstracting
`UIApplication.setAlternateIconName(_:)`, with three new App Icon Sets wired in via a build
setting — no `project.pbxproj` editing needed for the assets themselves.

**Tech Stack:** SwiftUI (iOS 26+), Swift Testing, `@Observable`, UIKit (`UIApplication`, the
one documented exception in CLAUDE.md for functionality with no SwiftUI equivalent).

## Global Constraints

- No force-unwraps (`!`) outside tests. (CLAUDE.md Coding Guidelines)
- `@Observable` over `ObservableObject`; `@MainActor` on ViewModels with UI-facing async work,
  matching `MatchdayViewModel`/`FixturesViewModel`/`StandingsViewModel`'s existing shape.
  (CLAUDE.md Coding Guidelines)
- All user-facing UI strings go through `Localizable.xcstrings`, `en`-only entries (existing
  More-screen convention — row/section titles are not translated). (CLAUDE.md Localization)
- `Competition` has no separate DTO: unlike `Team`, it is never embedded in a SwiftData
  `@Model`, so a custom `CodingKeys` mapping is safe. (Design spec)
- No SwiftData persistence for `Competition` — plain fetch-on-appear, matching `MatchEvent`'s
  no-persistence precedent, not `Match`/`Standing`'s. (Design spec)
- App Icon Set assets must be fully opaque (no alpha channel) — both provided PNGs are already
  100% opaque despite reporting `hasAlpha: yes` (a PNG color-mode detail, not real
  transparency — verified: alpha range is `(255, 255)` across every pixel in both files), so
  converting to RGB (dropping the alpha channel) is lossless. (Design spec, Icon Assets)
- `Assets.xcassets` is tracked in `project.pbxproj` as a single `folder.assetcatalog` reference
  — new App Icon Sets / Image Sets inside it need zero `project.pbxproj` changes, only the
  `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` build setting. (Design spec, Icon Assets)

---

## Task 1: Competition model and service layer

**Files:**
- Create: `BR2026/Models/Competition.swift`
- Modify: `BR2026/MockData/MockDataProvider.swift`
- Modify: `BR2026/Services/MatchService.swift`
- Modify: `BR2026/Services/LiveMatchService.swift`
- Modify: `BR2026/Services/MockMatchService.swift`
- Modify: `BR2026Tests/ViewModels/MatchdayViewModelTests.swift` (the `StubMatchService` test
  double at the bottom of this file)
- Modify: `BR2026Tests/Services/MockMatchServiceTests.swift`

**Interfaces:**
- Produces: `Competition` (`Decodable` struct: `code: String`, `name: String`, `season: Int`,
  `logoURL: URL`), `MatchService.fetchCompetition() async throws -> Competition` — consumed by
  Task 2's `MoreViewModel` and Task 5's `MoreViewModelTests`.

- [ ] **Step 1: Create `BR2026/Models/Competition.swift`**

```swift
import Foundation

struct Competition: Decodable {
    let code: String
    let name: String
    let season: Int
    let logoURL: URL

    private enum CodingKeys: String, CodingKey {
        case code, name, season
        case logoURL = "logo"
    }
}
```

- [ ] **Step 2: Add a mock fixture to `BR2026/MockData/MockDataProvider.swift`**

Insert this between the existing `eventsJSON` and `standingsJSON` static properties (i.e. right
after `eventsJSON`'s closing `"""` line, before `static let standingsJSON = """`):

```swift
    static let competitionJSON = """
    {
        "code": "BSA",
        "name": "Campeonato Brasileiro Série A",
        "season": 2026,
        "logo": "https://media.api-sports.io/football/leagues/71.png"
    }
    """

```

- [ ] **Step 3: Add `fetchCompetition()` to the `MatchService` protocol**

In `BR2026/Services/MatchService.swift`, add one line to the protocol (keep everything else
unchanged):

```swift
@MainActor
protocol MatchService {
    func fetchMatches() async throws -> [Match]
    func fetchStandings() async throws -> [Standing]
    func fetchEvents(matchID: Int) async throws -> [MatchEvent]
    func fetchCompetition() async throws -> Competition
    func cachedMatches() -> [Match]
    func cachedStandings() -> [Standing]
}
```

- [ ] **Step 4: Implement it on `LiveMatchService`**

Add this method to `BR2026/Services/LiveMatchService.swift`, next to the existing
`fetchEvents(matchID:)` method:

```swift
    func fetchCompetition() async throws -> Competition {
        let url = config.apiBaseURL.appendingPathComponent("v4/competitions/\(config.competitionCode)")
        return try await get(url)
    }
```

- [ ] **Step 5: Implement it on `MockMatchService`**

Replace the whole file `BR2026/Services/MockMatchService.swift`:

```swift
import Foundation

struct MatchesResponse: Decodable {
    let matches: [MatchDTO]
}

struct StandingsResponse: Decodable {
    let standings: [StandingDTO]
}

final class MockMatchService: MatchService {
    private let matches: [Match]
    private let standings: [Standing]
    private let events: [MatchEvent]
    private let competition: Competition?

    init() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let matchesData = Data(MockDataProvider.matchesJSON.utf8)
        let standingsData = Data(MockDataProvider.standingsJSON.utf8)
        let eventsData = Data(MockDataProvider.eventsJSON.utf8)
        let competitionData = Data(MockDataProvider.competitionJSON.utf8)
        let matchResponse = try? decoder.decode(MatchesResponse.self, from: matchesData)
        let standingsResponse = try? decoder.decode(StandingsResponse.self, from: standingsData)
        let eventsResponse = try? decoder.decode(MatchEventsResponse.self, from: eventsData)
        self.matches = (matchResponse?.matches ?? []).map(Match.init(dto:))
        self.standings = (standingsResponse?.standings ?? []).map(Standing.init(dto:))
        self.events = eventsResponse?.events ?? []
        self.competition = try? decoder.decode(Competition.self, from: competitionData)
    }

    func fetchMatches() async throws -> [Match] { matches }
    func fetchStandings() async throws -> [Standing] { standings }
    func fetchEvents(matchID: Int) async throws -> [MatchEvent] { events }

    func fetchCompetition() async throws -> Competition {
        guard let competition else { throw MatchServiceError.invalidResponse }
        return competition
    }

    func cachedMatches() -> [Match] { matches }
    func cachedStandings() -> [Standing] { standings }
}
```

- [ ] **Step 6: Extend the shared `StubMatchService` test double**

In `BR2026Tests/ViewModels/MatchdayViewModelTests.swift`, replace the whole `StubMatchService`
class (keep the `StubServiceError` enum below it unchanged):

```swift
final class StubMatchService: MatchService {
    let matches: [Match]
    let standings: [Standing]
    let events: [MatchEvent]
    let competition: Competition
    var cachedMatchesOverride: [Match]?
    var cachedStandingsOverride: [Standing]?
    var shouldThrowOnFetch = false
    private(set) var fetchMatchesCallCount = 0
    private(set) var fetchStandingsCallCount = 0

    init(
        matches: [Match],
        standings: [Standing],
        events: [MatchEvent] = [],
        competition: Competition = Competition(
            code: "BSA", name: "Campeonato Brasileiro Série A", season: 2026,
            logoURL: URL(string: "https://example.com/logo.png")!
        )
    ) {
        self.matches = matches
        self.standings = standings
        self.events = events
        self.competition = competition
    }

    func fetchMatches() async throws -> [Match] {
        fetchMatchesCallCount += 1
        if shouldThrowOnFetch { throw StubServiceError.simulatedFailure }
        return matches
    }

    func fetchStandings() async throws -> [Standing] {
        fetchStandingsCallCount += 1
        if shouldThrowOnFetch { throw StubServiceError.simulatedFailure }
        return standings
    }

    func fetchEvents(matchID: Int) async throws -> [MatchEvent] { events }

    func fetchCompetition() async throws -> Competition {
        if shouldThrowOnFetch { throw StubServiceError.simulatedFailure }
        return competition
    }

    func cachedMatches() -> [Match] { cachedMatchesOverride ?? matches }
    func cachedStandings() -> [Standing] { cachedStandingsOverride ?? standings }
}
```

- [ ] **Step 7: Add a test to `BR2026Tests/Services/MockMatchServiceTests.swift`**

Add inside the `@Suite` struct:

```swift
    @Test("Returns the Campeonato Brasileiro Série A competition with its logo URL")
    func returnsCompetition() async throws {
        let service = MockMatchService()
        let competition = try await service.fetchCompetition()
        #expect(competition.code == "BSA")
        #expect(competition.name == "Campeonato Brasileiro Série A")
        #expect(competition.logoURL == URL(string: "https://media.api-sports.io/football/leagues/71.png"))
    }
```

- [ ] **Step 8: Run the full test suite**

```bash
export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test
```

Expected: PASS, 52 tests (51 baseline + 1 new).

- [ ] **Step 9: Commit**

```bash
git add BR2026/Models/Competition.swift BR2026/MockData/MockDataProvider.swift BR2026/Services/MatchService.swift BR2026/Services/LiveMatchService.swift BR2026/Services/MockMatchService.swift BR2026Tests/ViewModels/MatchdayViewModelTests.swift BR2026Tests/Services/MockMatchServiceTests.swift
git commit -m "Add Competition model and fetchCompetition() to MatchService"
```

---

## Task 2: Competition header on the More screen

**Files:**
- Modify: `BR2026/ViewModels/MoreViewModel.swift`
- Modify: `BR2026/Views/More/MoreView.swift`
- Modify: `BR2026/Views/Root/ContentView.swift`
- Modify: `BR2026Tests/ViewModels/MoreViewModelTests.swift`

**Interfaces:**
- Consumes: `MatchService.fetchCompetition()` (Task 1).
- Produces: `MoreViewModel.competitionName: String?`, `MoreViewModel.competitionLogoURL: URL?`,
  `MoreViewModel.loadCompetition() async`, `MoreViewModel(service:)` initializer (breaking
  change from the previous no-argument `MoreViewModel()`) — consumed by Task 5.

- [ ] **Step 1: Replace `BR2026/ViewModels/MoreViewModel.swift` in full**

```swift
import Foundation
import Observation

@Observable
@MainActor
final class MoreViewModel {
    private(set) var competitionName: String?
    private(set) var competitionLogoURL: URL?
    let sections: [MoreSection] = [
        MoreSection(
            id: "legal",
            titleKey: "Legal",
            rows: [
                MoreRow(
                    id: "termsOfService",
                    titleKey: "Terms of Service",
                    systemImage: "doc.text",
                    destination: .termsOfService,
                    isEnabled: true
                )
            ]
        ),
        MoreSection(
            id: "preferences",
            titleKey: "Preferences",
            rows: [
                MoreRow(
                    id: "settings",
                    titleKey: "Settings",
                    systemImage: "gearshape",
                    destination: nil,
                    isEnabled: false
                )
            ]
        )
    ]
    private nonisolated(unsafe) let service: MatchService

    init(service: MatchService) {
        self.service = service
    }

    func loadCompetition() async {
        guard let competition = try? await service.fetchCompetition() else { return }
        competitionName = competition.name
        competitionLogoURL = competition.logoURL
    }
}
```

(The Preferences row stays disabled/"Settings" here — Task 5 changes it. Keeping this task
scoped to the competition header only.)

- [ ] **Step 2: Replace `BR2026/Views/More/MoreView.swift` in full**

```swift
import SwiftUI

struct MoreView: View {
    @State private var viewModel: MoreViewModel

    init(service: MatchService) {
        _viewModel = State(initialValue: MoreViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    competitionHeader
                    ForEach(viewModel.sections) { section in
                        sectionView(section)
                    }
                }
                .padding(16)
            }
            .scrollContentBackground(.hidden)
            .background(StadiumBackground())
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: MoreDestination.self) { destination in
                switch destination {
                case .termsOfService:
                    TermsOfServiceView()
                }
            }
            .task { await viewModel.loadCompetition() }
        }
    }

    private var competitionHeader: some View {
        VStack(spacing: 8) {
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
                                .foregroundStyle(.white.opacity(0.55))
                        )
                }
            }
            .frame(width: 64, height: 64)
            if let name = viewModel.competitionName {
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }

    private func sectionView(_ section: MoreSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.titleKey)
                .font(.system(size: 13, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
            GlassCard(cornerRadius: 18, style: .transparent) {
                VStack(spacing: 0) {
                    ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                        rowView(row)
                        if index < section.rows.count - 1 {
                            Rectangle()
                                .fill(Color.white.opacity(0.16))
                                .frame(height: 0.5)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func rowView(_ row: MoreRow) -> some View {
        if row.isEnabled, let destination = row.destination {
            NavigationLink(value: destination) {
                rowLabel(row, showsChevron: true)
            }
            .buttonStyle(.plain)
        } else {
            rowLabel(row, showsChevron: false)
                .opacity(0.3)
        }
    }

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
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .foregroundStyle(.white)
        .padding(.vertical, 10)
        // Without this, the row's tappable area stops at the last piece of drawn
        // content (the icon/title on the left, or the chevron on the right) — the
        // `Spacer()` in between has nothing to hit-test against, so tapping the empty
        // middle of the row does nothing.
        .contentShape(Rectangle())
    }
}
```

- [ ] **Step 3: Update the call site in `BR2026/Views/Root/ContentView.swift`**

Change:
```swift
            MoreView()
```
to:
```swift
            MoreView(service: service)
```

- [ ] **Step 4: Replace `BR2026Tests/ViewModels/MoreViewModelTests.swift` in full**

```swift
import Testing
import Foundation
@testable import BR2026

@Suite("MoreViewModel")
@MainActor
struct MoreViewModelTests {
    @Test("Legal section has one enabled Terms of Service row")
    func legalSection() {
        let viewModel = MoreViewModel(service: StubMatchService(matches: [], standings: []))
        let legal = viewModel.sections.first { $0.id == "legal" }
        #expect(legal?.rows.count == 1)
        #expect(legal?.rows.first?.destination == .termsOfService)
        #expect(legal?.rows.first?.isEnabled == true)
    }

    @Test("Preferences section has one disabled, destination-less row")
    func preferencesSection() {
        let viewModel = MoreViewModel(service: StubMatchService(matches: [], standings: []))
        let preferences = viewModel.sections.first { $0.id == "preferences" }
        #expect(preferences?.rows.count == 1)
        #expect(preferences?.rows.allSatisfy { $0.destination == nil && !$0.isEnabled } == true)
    }

    @Test("loadCompetition() populates the competition name and logo URL")
    func loadCompetitionPopulatesNameAndLogo() async {
        let competition = Competition(
            code: "BSA", name: "Campeonato Brasileiro Série A", season: 2026,
            logoURL: URL(string: "https://media.api-sports.io/football/leagues/71.png")!
        )
        let service = StubMatchService(matches: [], standings: [], competition: competition)
        let viewModel = MoreViewModel(service: service)

        await viewModel.loadCompetition()

        #expect(viewModel.competitionName == "Campeonato Brasileiro Série A")
        #expect(viewModel.competitionLogoURL == competition.logoURL)
    }
}
```

(`preferencesSection()` still asserts the disabled/"Settings" shape here — Task 5 updates this
same test once the row actually changes.)

- [ ] **Step 5: Run the full test suite**

```bash
export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test
```

Expected: PASS, 53 tests (52 from Task 1 + 1 new).

- [ ] **Step 6: Commit**

```bash
git add BR2026/ViewModels/MoreViewModel.swift BR2026/Views/More/MoreView.swift BR2026/Views/Root/ContentView.swift BR2026Tests/ViewModels/MoreViewModelTests.swift
git commit -m "Show the competition logo and name on the More screen"
```

---

## Task 3: App icon assets

**Files:**
- Create: `BR2026/Resources/Assets.xcassets/AppIcon-Brasil.appiconset/Contents.json`
- Create: `BR2026/Resources/Assets.xcassets/AppIcon-Brasil.appiconset/AppIcon-Brasil-1024.png`
- Create: `BR2026/Resources/Assets.xcassets/AppIcon-Stadium.appiconset/Contents.json`
- Create: `BR2026/Resources/Assets.xcassets/AppIcon-Stadium.appiconset/AppIcon-Stadium-1024.png`
- Create: `BR2026/Resources/Assets.xcassets/AppIconPreview-Light.imageset/Contents.json`
- Create: `BR2026/Resources/Assets.xcassets/AppIconPreview-Light.imageset/AppIconPreview-Light.png`
- Create: `BR2026/Resources/Assets.xcassets/AppIconPreview-Brasil.imageset/Contents.json`
- Create: `BR2026/Resources/Assets.xcassets/AppIconPreview-Brasil.imageset/AppIconPreview-Brasil.png`
- Create: `BR2026/Resources/Assets.xcassets/AppIconPreview-Stadium.imageset/Contents.json`
- Create: `BR2026/Resources/Assets.xcassets/AppIconPreview-Stadium.imageset/AppIconPreview-Stadium.png`
- Modify: `BR2026.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces: App Icon Set names `AppIcon-Brasil`, `AppIcon-Stadium` (for
  `UIApplication.setAlternateIconName(_:)`) and Image Set names `AppIconPreview-Light`,
  `AppIconPreview-Brasil`, `AppIconPreview-Stadium` (for SwiftUI `Image(_:)` thumbnails) —
  consumed by Task 4's `AppIconOption`.

- [ ] **Step 1: Flatten the two source PNGs to opaque RGB**

```bash
python3 -c "
from PIL import Image
Image.open('prints/icons/AppIcon-1c-1024.png').convert('RGB').save('/tmp/AppIcon-Brasil-1024.png')
Image.open('prints/icons/AppIcon-1e-1024.png').convert('RGB').save('/tmp/AppIcon-Stadium-1024.png')
"
```

Expected: two new files at `/tmp/AppIcon-Brasil-1024.png` and `/tmp/AppIcon-Stadium-1024.png`,
1024×1024, no alpha channel. Verify with:
```bash
sips -g hasAlpha /tmp/AppIcon-Brasil-1024.png /tmp/AppIcon-Stadium-1024.png
```
Expected: `hasAlpha: no` for both.

- [ ] **Step 2: Create the `AppIcon-Brasil` App Icon Set**

```bash
mkdir -p "BR2026/Resources/Assets.xcassets/AppIcon-Brasil.appiconset"
cp /tmp/AppIcon-Brasil-1024.png "BR2026/Resources/Assets.xcassets/AppIcon-Brasil.appiconset/AppIcon-Brasil-1024.png"
```

Write `BR2026/Resources/Assets.xcassets/AppIcon-Brasil.appiconset/Contents.json`:
```json
{
  "images" : [
    {
      "filename" : "AppIcon-Brasil-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 3: Create the `AppIcon-Stadium` App Icon Set**

```bash
mkdir -p "BR2026/Resources/Assets.xcassets/AppIcon-Stadium.appiconset"
cp /tmp/AppIcon-Stadium-1024.png "BR2026/Resources/Assets.xcassets/AppIcon-Stadium.appiconset/AppIcon-Stadium-1024.png"
```

Write `BR2026/Resources/Assets.xcassets/AppIcon-Stadium.appiconset/Contents.json`:
```json
{
  "images" : [
    {
      "filename" : "AppIcon-Stadium-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 4: Create the three preview Image Sets**

```bash
mkdir -p "BR2026/Resources/Assets.xcassets/AppIconPreview-Light.imageset"
mkdir -p "BR2026/Resources/Assets.xcassets/AppIconPreview-Brasil.imageset"
mkdir -p "BR2026/Resources/Assets.xcassets/AppIconPreview-Stadium.imageset"
cp "BR2026/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" "BR2026/Resources/Assets.xcassets/AppIconPreview-Light.imageset/AppIconPreview-Light.png"
cp /tmp/AppIcon-Brasil-1024.png "BR2026/Resources/Assets.xcassets/AppIconPreview-Brasil.imageset/AppIconPreview-Brasil.png"
cp /tmp/AppIcon-Stadium-1024.png "BR2026/Resources/Assets.xcassets/AppIconPreview-Stadium.imageset/AppIconPreview-Stadium.png"
```

Write `BR2026/Resources/Assets.xcassets/AppIconPreview-Light.imageset/Contents.json`:
```json
{
  "images" : [
    {
      "filename" : "AppIconPreview-Light.png",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

Write `BR2026/Resources/Assets.xcassets/AppIconPreview-Brasil.imageset/Contents.json`:
```json
{
  "images" : [
    {
      "filename" : "AppIconPreview-Brasil.png",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

Write `BR2026/Resources/Assets.xcassets/AppIconPreview-Stadium.imageset/Contents.json`:
```json
{
  "images" : [
    {
      "filename" : "AppIconPreview-Stadium.png",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 5: Validate every new `Contents.json`**

```bash
for f in "BR2026/Resources/Assets.xcassets/AppIcon-Brasil.appiconset/Contents.json" \
         "BR2026/Resources/Assets.xcassets/AppIcon-Stadium.appiconset/Contents.json" \
         "BR2026/Resources/Assets.xcassets/AppIconPreview-Light.imageset/Contents.json" \
         "BR2026/Resources/Assets.xcassets/AppIconPreview-Brasil.imageset/Contents.json" \
         "BR2026/Resources/Assets.xcassets/AppIconPreview-Stadium.imageset/Contents.json"; do
  plutil -lint "$f"
done
```

Expected: `OK` for each file.

- [ ] **Step 6: Add the alternate-icons build setting**

In `BR2026.xcodeproj/project.pbxproj`, there are two `ASSETCATALOG_COMPILER_APPICON_NAME =
AppIcon;` lines (one in the Debug config, one in the Release config, both inside the app
target's build settings — not the test targets). Add a new line immediately after **each** of
them:

```
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = "AppIcon-Brasil AppIcon-Stadium";
```

- [ ] **Step 7: Build to confirm the asset catalog and build setting are valid**

```bash
export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test
```

Expected: PASS, same 53 tests as Task 2 (no test changes in this task — pure asset/build-config
work). A malformed `Contents.json` or bad build setting would fail the build here.

- [ ] **Step 8: Commit**

```bash
git add BR2026/Resources/Assets.xcassets BR2026.xcodeproj/project.pbxproj
git commit -m "Add Brasil and Stadium alternate app icons"
```

---

## Task 4: App icon picker model, service abstraction, and ViewModel

**Files:**
- Create: `BR2026/Models/AppIconOption.swift`
- Create: `BR2026/Services/AppIconSetting.swift`
- Create: `BR2026/ViewModels/AppIconPickerViewModel.swift`
- Test: `BR2026Tests/ViewModels/AppIconPickerViewModelTests.swift`

**Interfaces:**
- Produces: `AppIconOption` (enum: `.light`, `.brasil`, `.stadium`; `displayName:
  LocalizedStringResource`, `iconAssetName: String?`, `previewImageName: String`),
  `AppIconSetting` protocol, `UIKitAppIconSetting` (production impl),
  `AppIconPickerViewModel(iconSetting:)`, `.selectedIcon`, `.errorMessage`, `.select(_:) async`
  — consumed by Task 5's `AppIconPickerView`.

This task follows TDD: write the test file first (referencing not-yet-existing types), confirm
it fails to compile (RED), then implement, then confirm it passes (GREEN).

- [ ] **Step 1: Write the failing test file**

Create `BR2026Tests/ViewModels/AppIconPickerViewModelTests.swift`:

```swift
import Testing
@testable import BR2026

@Suite("AppIconPickerViewModel")
@MainActor
struct AppIconPickerViewModelTests {
    @Test("Defaults to .light when there's no current alternate icon name")
    func defaultsToLightWhenNoAlternateIcon() {
        let setting = StubAppIconSetting(currentIconName: nil)
        let viewModel = AppIconPickerViewModel(iconSetting: setting)

        #expect(viewModel.selectedIcon == .light)
    }

    @Test("Derives the selected icon from a matching current icon name")
    func derivesSelectedIconFromCurrentName() {
        let setting = StubAppIconSetting(currentIconName: "AppIcon-Stadium")
        let viewModel = AppIconPickerViewModel(iconSetting: setting)

        #expect(viewModel.selectedIcon == .stadium)
    }

    @Test("select() updates selectedIcon and calls setIconName on success")
    func selectUpdatesSelectedIconOnSuccess() async {
        let setting = StubAppIconSetting(currentIconName: nil)
        let viewModel = AppIconPickerViewModel(iconSetting: setting)

        await viewModel.select(.brasil)

        #expect(viewModel.selectedIcon == .brasil)
        #expect(setting.setIconNameCalls == ["AppIcon-Brasil"])
        #expect(viewModel.errorMessage == nil)
    }

    @Test("select() sets errorMessage and keeps the prior selection when setIconName throws")
    func selectSetsErrorMessageOnFailure() async {
        let setting = StubAppIconSetting(currentIconName: nil)
        setting.shouldThrow = true
        let viewModel = AppIconPickerViewModel(iconSetting: setting)

        await viewModel.select(.brasil)

        #expect(viewModel.selectedIcon == .light)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("select() on the already-selected option does not call setIconName again")
    func selectOnAlreadySelectedIsNoOp() async {
        let setting = StubAppIconSetting(currentIconName: nil)
        let viewModel = AppIconPickerViewModel(iconSetting: setting)

        await viewModel.select(.light)

        #expect(setting.setIconNameCalls.isEmpty)
    }
}

final class StubAppIconSetting: AppIconSetting {
    let currentIconName: String?
    var shouldThrow = false
    private(set) var setIconNameCalls: [String?] = []

    init(currentIconName: String?) {
        self.currentIconName = currentIconName
    }

    func setIconName(_ name: String?) async throws {
        setIconNameCalls.append(name)
        if shouldThrow { throw StubServiceError.simulatedFailure }
    }
}
```

(`StubServiceError` is the enum already defined in `MatchdayViewModelTests.swift` — same test
target, no import needed.)

- [ ] **Step 2: Run it to confirm it fails to compile**

```bash
export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test
```

Expected: FAIL — `AppIconOption`, `AppIconSetting`, and `AppIconPickerViewModel` don't exist yet.

- [ ] **Step 3: Create `BR2026/Models/AppIconOption.swift`**

```swift
import Foundation

enum AppIconOption: String, CaseIterable, Identifiable {
    case light
    case brasil
    case stadium

    var id: String { rawValue }

    var displayName: LocalizedStringResource {
        switch self {
        case .light: "Light"
        case .brasil: "Brasil"
        case .stadium: "Stadium"
        }
    }

    /// The App Icon Set name for `UIApplication.setAlternateIconName(_:)`. `nil` means the
    /// primary icon — that's the API's own convention for "reset to default", not a gap here.
    var iconAssetName: String? {
        switch self {
        case .light: nil
        case .brasil: "AppIcon-Brasil"
        case .stadium: "AppIcon-Stadium"
        }
    }

    /// The plain Image Set used for this option's preview thumbnail in the picker (distinct
    /// from `iconAssetName`, which names an App Icon Set — App Icon Set assets aren't reliably
    /// loadable via plain SwiftUI `Image(_:)` across iOS versions).
    var previewImageName: String {
        switch self {
        case .light: "AppIconPreview-Light"
        case .brasil: "AppIconPreview-Brasil"
        case .stadium: "AppIconPreview-Stadium"
        }
    }
}
```

- [ ] **Step 4: Create `BR2026/Services/AppIconSetting.swift`**

```swift
import UIKit

@MainActor
protocol AppIconSetting {
    var currentIconName: String? { get }
    func setIconName(_ name: String?) async throws
}

@MainActor
final class UIKitAppIconSetting: AppIconSetting {
    var currentIconName: String? { UIApplication.shared.alternateIconName }

    func setIconName(_ name: String?) async throws {
        try await UIApplication.shared.setAlternateIconName(name)
    }
}
```

- [ ] **Step 5: Create `BR2026/ViewModels/AppIconPickerViewModel.swift`**

```swift
import Foundation
import Observation

@Observable
@MainActor
final class AppIconPickerViewModel {
    private(set) var selectedIcon: AppIconOption
    private(set) var errorMessage: String?
    private let iconSetting: AppIconSetting

    init(iconSetting: AppIconSetting) {
        self.iconSetting = iconSetting
        let currentName = iconSetting.currentIconName
        selectedIcon = AppIconOption.allCases.first { $0.iconAssetName == currentName } ?? .light
    }

    func select(_ option: AppIconOption) async {
        guard option != selectedIcon else { return }
        do {
            try await iconSetting.setIconName(option.iconAssetName)
            selectedIcon = option
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Couldn't change the app icon. Try again.")
        }
    }
}
```

- [ ] **Step 6: Run the full test suite to confirm it passes**

```bash
export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test
```

Expected: PASS, 58 tests (53 from Task 3 + 5 new).

- [ ] **Step 7: Commit**

```bash
git add BR2026/Models/AppIconOption.swift BR2026/Services/AppIconSetting.swift BR2026/ViewModels/AppIconPickerViewModel.swift BR2026Tests/ViewModels/AppIconPickerViewModelTests.swift
git commit -m "Add AppIconOption, AppIconSetting, and AppIconPickerViewModel"
```

---

## Task 5: App icon picker screen and final wiring

**Files:**
- Create: `BR2026/Views/More/AppIconPickerView.swift`
- Modify: `BR2026/Models/MoreDestination.swift`
- Modify: `BR2026/ViewModels/MoreViewModel.swift`
- Modify: `BR2026/Views/More/MoreView.swift`
- Modify: `BR2026/Resources/Localizable.xcstrings`
- Modify: `BR2026Tests/ViewModels/MoreViewModelTests.swift`
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: `AppIconOption`, `AppIconPickerViewModel`, `UIKitAppIconSetting` (Task 4).

- [ ] **Step 1: Create `BR2026/Views/More/AppIconPickerView.swift`**

```swift
import SwiftUI

struct AppIconPickerView: View {
    @State private var viewModel: AppIconPickerViewModel

    init(viewModel: AppIconPickerViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                GlassCard(cornerRadius: 18, style: .transparent) {
                    VStack(spacing: 0) {
                        ForEach(Array(AppIconOption.allCases.enumerated()), id: \.element.id) { index, option in
                            rowView(option)
                            if index < AppIconOption.allCases.count - 1 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.16))
                                    .frame(height: 0.5)
                            }
                        }
                    }
                }
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
        .background(StadiumBackground())
        .navigationTitle("App Icon")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func rowView(_ option: AppIconOption) -> some View {
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
                if viewModel.selectedIcon == option {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .foregroundStyle(.white)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Add the destination case to `BR2026/Models/MoreDestination.swift`**

```swift
import Foundation

enum MoreDestination: Hashable {
    case termsOfService
    case appIconPicker
}
```

- [ ] **Step 3: Update the Preferences row in `BR2026/ViewModels/MoreViewModel.swift`**

Change:
```swift
        MoreSection(
            id: "preferences",
            titleKey: "Preferences",
            rows: [
                MoreRow(
                    id: "settings",
                    titleKey: "Settings",
                    systemImage: "gearshape",
                    destination: nil,
                    isEnabled: false
                )
            ]
        )
```
to:
```swift
        MoreSection(
            id: "preferences",
            titleKey: "Preferences",
            rows: [
                MoreRow(
                    id: "appIcon",
                    titleKey: "App Icon",
                    systemImage: "app.badge",
                    destination: .appIconPicker,
                    isEnabled: true
                )
            ]
        )
```

- [ ] **Step 4: Add the destination case to `BR2026/Views/More/MoreView.swift`**

Change:
```swift
            .navigationDestination(for: MoreDestination.self) { destination in
                switch destination {
                case .termsOfService:
                    TermsOfServiceView()
                }
            }
```
to:
```swift
            .navigationDestination(for: MoreDestination.self) { destination in
                switch destination {
                case .termsOfService:
                    TermsOfServiceView()
                case .appIconPicker:
                    AppIconPickerView(viewModel: AppIconPickerViewModel(iconSetting: UIKitAppIconSetting()))
                }
            }
```

- [ ] **Step 5: Update `BR2026/Resources/Localizable.xcstrings`**

Find this entry (search for `"Settings"`):
```json
    "Settings" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Settings"
          }
        }
      }
    },
```

Replace it with these five entries (removes the now-unused `"Settings"` key, adds the four new
ones — verified `git grep '"Settings"'` shows `MoreViewModel.swift` as the only other reference,
which Step 3 already changed):
```json
    "App Icon" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "App Icon"
          }
        }
      }
    },
    "Brasil" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Brasil"
          }
        }
      }
    },
    "Couldn't change the app icon. Try again." : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Couldn't change the app icon. Try again."
          }
        }
      }
    },
    "Light" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Light"
          }
        }
      }
    },
    "Stadium" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Stadium"
          }
        }
      }
    },
```

Validate:
```bash
plutil -lint BR2026/Resources/Localizable.xcstrings
```
Expected: `OK`.

- [ ] **Step 6: Update the Preferences test in `BR2026Tests/ViewModels/MoreViewModelTests.swift`**

Change:
```swift
    @Test("Preferences section has one disabled, destination-less row")
    func preferencesSection() {
        let viewModel = MoreViewModel(service: StubMatchService(matches: [], standings: []))
        let preferences = viewModel.sections.first { $0.id == "preferences" }
        #expect(preferences?.rows.count == 1)
        #expect(preferences?.rows.allSatisfy { $0.destination == nil && !$0.isEnabled } == true)
    }
```
to:
```swift
    @Test("Preferences section has one enabled App Icon row")
    func preferencesSection() {
        let viewModel = MoreViewModel(service: StubMatchService(matches: [], standings: []))
        let preferences = viewModel.sections.first { $0.id == "preferences" }
        #expect(preferences?.rows.count == 1)
        #expect(preferences?.rows.first?.destination == .appIconPicker)
        #expect(preferences?.rows.first?.isEnabled == true)
    }
```

- [ ] **Step 7: Update `CLAUDE.md`**

In the Backend API section, add one line after the existing `standings` endpoint line:
```markdown
- `GET /v4/competitions/{code}/standings`
- `GET /v4/competitions/{code}` — competition name and logo, consumed by the More screen's
  competition header.
```

In the Assets section, add a bullet after the existing "Icons" bullet's sub-list:
```markdown
- **Alternate app icons:** Light (default), Brasil, Stadium — switchable from the More screen's
  App Icon row via `UIApplication.setAlternateIconName(_:)`. Each has a matching
  `AppIconPreview-*` plain Image Set for the picker's thumbnail (App Icon Set assets aren't
  reliably loadable via plain SwiftUI `Image(_:)`).
```

- [ ] **Step 8: Run the full test suite**

```bash
export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test
```

Expected: PASS, 58 tests (same count as Task 4 — this task changes one test's assertions rather
than adding a new test, plus View-only/docs changes).

- [ ] **Step 9: Commit**

```bash
git add BR2026/Views/More/AppIconPickerView.swift BR2026/Models/MoreDestination.swift BR2026/ViewModels/MoreViewModel.swift BR2026/Views/More/MoreView.swift BR2026/Resources/Localizable.xcstrings BR2026Tests/ViewModels/MoreViewModelTests.swift CLAUDE.md
git commit -m "Wire up the App Icon picker screen"
```
