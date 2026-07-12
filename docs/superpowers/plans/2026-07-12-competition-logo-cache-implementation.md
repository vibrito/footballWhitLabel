# Competition Logo Caching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist the competition record (name + logo image bytes) via a new `Competition`
SwiftData model so the More screen's header loads instantly from cache after the first
successful fetch, refreshing at most once a week instead of on every launch, per
`docs/superpowers/specs/2026-07-12-competition-logo-cache-design.md`.

**Architecture:** Split `Competition` into a `CompetitionDTO` (wire-format `Decodable`) and
a `Competition` SwiftData `@Model` (adds `logoData: Data?`, `cachedAt: Date`), mirroring the
existing `Match`/`MatchDTO` and `Standing`/`StandingDTO` split. `LiveMatchService` downloads
and persists the logo bytes alongside the metadata. `MoreViewModel` gains the same
`load()`/`loadOnce()` split as the other three ViewModels, but `load()` skips the network
entirely when a cache under 7 days old exists — a "fetch once, refresh occasionally" shape
distinct from Matchday/Fixtures/Standings, which always background-refresh.

**Tech Stack:** Swift 6, SwiftData, Swift Testing (`@Test`, `@Suite`), SwiftUI.

## Global Constraints

- The refresh threshold is exactly 7 days (`7 * 24 * 60 * 60` seconds), per the spec.
- `Competition(code:name:season:logoURL:)` must keep working as a 4-argument call (via
  default values for `logoData`/`cachedAt`) — existing test call sites in
  `MatchdayViewModelTests.swift` and `MoreViewModelTests.swift` construct it that way and
  must not need to change.
- Image download failure in `LiveMatchService.fetchCompetition()` must be non-fatal — the
  name/code/logoURL still get cached with `logoData = nil` rather than the whole fetch
  throwing.
- No `RefreshPulseDot` added to `MoreView` — the spec explicitly keeps this out of scope.
- No pull-to-refresh added to `MoreView` — the weekly throttle is the only refresh trigger.
- Every new pbxproj entry follows this project's established wiring recipe: a
  `PBXBuildFile`, a `PBXFileReference`, a `PBXGroup` children entry, and a
  `PBXSourcesBuildPhase` files-array entry. Generate UUIDs via
  `python3 -c "import secrets; print(secrets.token_hex(12).upper())"` and verify uniqueness
  with `grep -c <UUID> BR2026.xcodeproj/project.pbxproj` (must print `0` before use).

---

### Task 1: Split `Competition` into `CompetitionDTO` + SwiftData model, update the protocol and `MockMatchService`

**Files:**
- Create: `BR2026/Models/CompetitionDTO.swift`
- Modify: `BR2026/Models/Competition.swift`
- Modify: `BR2026/App/Championship.swift`
- Modify: `BR2026/Services/MatchService.swift`
- Modify: `BR2026/Services/MockMatchService.swift`
- Modify: `BR2026Tests/ViewModels/MatchdayViewModelTests.swift` (minimal
  `StubMatchService` conformance only — full test coverage comes in Task 3)
- Modify: `BR2026.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces: `CompetitionDTO` (Decodable struct), `Competition` (SwiftData `@Model`, with
  `convenience init(dto: CompetitionDTO, logoData: Data? = nil)`), `MatchService.cachedCompetition() -> Competition?`.
- Consumes: none (this is the base data-layer task).

- [ ] **Step 1: Create `BR2026/Models/CompetitionDTO.swift`** with the current
  `Competition.swift` content, renamed:

```swift
import Foundation

struct CompetitionDTO: Decodable {
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

- [ ] **Step 2: Rewrite `BR2026/Models/Competition.swift`** as a SwiftData model:

```swift
import Foundation
import SwiftData

@Model
final class Competition {
    @Attribute(.unique) var code: String
    var name: String
    var season: Int
    var logoURL: URL
    var logoData: Data?
    var cachedAt: Date

    init(
        code: String,
        name: String,
        season: Int,
        logoURL: URL,
        logoData: Data? = nil,
        cachedAt: Date = Date()
    ) {
        self.code = code
        self.name = name
        self.season = season
        self.logoURL = logoURL
        self.logoData = logoData
        self.cachedAt = cachedAt
    }

    convenience init(dto: CompetitionDTO, logoData: Data? = nil) {
        self.init(
            code: dto.code,
            name: dto.name,
            season: dto.season,
            logoURL: dto.logoURL,
            logoData: logoData
        )
    }
}
```

- [ ] **Step 3: Register `Competition` in the `ModelContainer`**

In `BR2026/App/Championship.swift`, change:
```swift
modelContainer = try ModelContainer(for: Match.self, Standing.self)
```
to:
```swift
modelContainer = try ModelContainer(for: Match.self, Standing.self, Competition.self)
```

- [ ] **Step 4: Add `cachedCompetition()` to the `MatchService` protocol**

In `BR2026/Services/MatchService.swift`, add after `func cachedStandings() -> [Standing]`:
```swift
    func cachedCompetition() -> Competition?
```

- [ ] **Step 5: Update `MockMatchService` to decode `CompetitionDTO` and wrap it**

In `BR2026/Services/MockMatchService.swift`, change:
```swift
        self.competition = try? decoder.decode(Competition.self, from: competitionData)
```
to:
```swift
        let competitionDTO = try? decoder.decode(CompetitionDTO.self, from: competitionData)
        self.competition = competitionDTO.map { Competition(dto: $0) }
```

Add after `func cachedStandings() -> [Standing] { standings }`:
```swift
    func cachedCompetition() -> Competition? { competition }
```

- [ ] **Step 6: Add minimal `cachedCompetition()` conformance to `StubMatchService`**

In `BR2026Tests/ViewModels/MatchdayViewModelTests.swift`, add a property after
`var cachedStandingsOverride: [Standing]?`:
```swift
    var cachedCompetitionOverride: Competition?
```
Add a method after `func cachedStandings() -> [Standing] { cachedStandingsOverride ?? standings }`:
```swift
    func cachedCompetition() -> Competition? { cachedCompetitionOverride }
```
(Task 3 adds `fetchCompetitionCallCount` tracking to this same file — this step only
restores protocol conformance so everything compiles.)

- [ ] **Step 7: Wire `CompetitionDTO.swift` into the project**

Generate two UUIDs (`FILEREF_UUID`, `BUILDFILE_UUID`), verifying each with
`grep -c <UUID> BR2026.xcodeproj/project.pbxproj` first (must be `0`).

Add to `/* Begin PBXFileReference section */`, near the existing `Competition.swift` entry
(`30741DC2065FBFD04140A95C`):
```
		FILEREF_UUID /* CompetitionDTO.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = CompetitionDTO.swift; sourceTree = "<group>"; };
```

Add to the `Models` group's children (`03B57D264A672EBFC9A9A17D`, which currently lists
`Match.swift`, `MatchDTO.swift`, `Competition.swift`, `AppIconOption.swift`,
`MatchEvent.swift`, `MatchStatus.swift`, `Standing.swift`, `StandingDTO.swift`, `Team.swift`,
`MoreDestination.swift`, `MoreRow.swift`, `MoreSection.swift`) — insert right after
`Competition.swift`:
```
				FILEREF_UUID /* CompetitionDTO.swift */,
```

Add to `/* Begin PBXBuildFile section */`:
```
		BUILDFILE_UUID /* CompetitionDTO.swift in Sources */ = {isa = PBXBuildFile; fileRef = FILEREF_UUID /* CompetitionDTO.swift */; };
```

Add to the `BR2026` app target's Sources build phase (`4A4FA446D5F73EAE1C9245D1`):
```
				BUILDFILE_UUID /* CompetitionDTO.swift in Sources */,
```

**Also add `CompetitionDTO.swift` to the `BR2026Tests` target's Sources build phase**
(`67D574F10675E1E66C7D40B3` — confirm this UUID via
`grep -n "isa = PBXNativeTarget" -A6 BR2026.xcodeproj/project.pbxproj` under
`78C6B9E9B67D1498742D6B7C /* BR2026Tests */`), since `MockMatchServiceTests.swift` and
`MoreViewModelTests.swift` both run under `@testable import BR2026` from the app target, not
a separate compile — **skip this addition**: `BR2026Tests` links against the `BR2026` app
module via `@testable import`, it does not recompile app sources separately. Only the app
target's Sources phase needs the new file.

Verify: `grep -c "FILEREF_UUID" BR2026.xcodeproj/project.pbxproj` → `3`;
`grep -c "BUILDFILE_UUID" BR2026.xcodeproj/project.pbxproj` → `2`.

- [ ] **Step 8: Build and run tests**

Run: `xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation build`
Expected: `** BUILD SUCCEEDED **`.

Run: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test`
Expected: all existing tests still pass, including `MockMatchServiceTests`'s
`"Returns the Campeonato Brasileiro Série A competition with its logo URL"` test (unaffected
by the DTO rename since `MockMatchService.fetchCompetition()`'s return type is still
`Competition`, now constructed via `Competition(dto:)`).

- [ ] **Step 9: Commit**

```bash
git add BR2026/Models/CompetitionDTO.swift BR2026/Models/Competition.swift BR2026/App/Championship.swift BR2026/Services/MatchService.swift BR2026/Services/MockMatchService.swift BR2026Tests/ViewModels/MatchdayViewModelTests.swift BR2026.xcodeproj/project.pbxproj
git commit -m "Split Competition into CompetitionDTO + SwiftData model, add cachedCompetition()"
```

---

### Task 2: `LiveMatchService` downloads and persists the logo, adds `cachedCompetition()`

**Files:**
- Modify: `BR2026/Services/LiveMatchService.swift`

**Interfaces:**
- Consumes: `Competition(dto:logoData:)` and `CompetitionDTO` from Task 1.
- Produces: `LiveMatchService.cachedCompetition() -> Competition?`, used by Task 3's
  `MoreViewModel`.

- [ ] **Step 1: Change `fetchCompetition()` to decode the DTO, download the logo, and
  persist**

In `BR2026/Services/LiveMatchService.swift`, replace:
```swift
    func fetchCompetition() async throws -> Competition {
        let url = config.apiBaseURL.appendingPathComponent("v4/competitions/\(config.competitionCode)")
        return try await get(url)
    }
```
with:
```swift
    func fetchCompetition() async throws -> Competition {
        let url = config.apiBaseURL.appendingPathComponent("v4/competitions/\(config.competitionCode)")
        let dto: CompetitionDTO = try await get(url)
        let logoData = try? await downloadData(dto.logoURL)
        try modelContext.delete(model: Competition.self)
        let competition = Competition(dto: dto, logoData: logoData)
        modelContext.insert(competition)
        try modelContext.save()
        return competition
    }
```

- [ ] **Step 2: Add `cachedCompetition()`**

Add after `func cachedStandings() -> [Standing] { ... }`:
```swift
    func cachedCompetition() -> Competition? {
        (try? modelContext.fetch(FetchDescriptor<Competition>()))?.first
    }
```

- [ ] **Step 3: Add the `downloadData` helper**

Add after the existing `private func get<T: Decodable>(_ url: URL) async throws -> T { ... }`
method:
```swift
    private func downloadData(_ url: URL) async throws -> Data {
        let (data, response) = try await urlSession.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MatchServiceError.invalidResponse
        }
        return data
    }
```
(Deliberately not routed through `get<T: Decodable>` — that helper sets the
`X-Auth-Token` header, which belongs to the sports API, not the third-party image host
`logoURL` points at.)

- [ ] **Step 4: Build**

Run: `xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation build`
Expected: `** BUILD SUCCEEDED **`. (No new automated test for this — `LiveMatchService`
talks to the real live API and isn't unit-tested today, consistent with existing coverage;
`MockMatchService` is what every automated test exercises.)

- [ ] **Step 5: Commit**

```bash
git add BR2026/Services/LiveMatchService.swift
git commit -m "LiveMatchService: download and persist the competition logo, add cachedCompetition()"
```

---

### Task 3: `MoreViewModel` — cache-once, refresh-weekly

**Files:**
- Modify: `BR2026/ViewModels/MoreViewModel.swift`
- Modify: `BR2026Tests/ViewModels/MoreViewModelTests.swift`
- Modify: `BR2026Tests/ViewModels/MatchdayViewModelTests.swift` (add
  `fetchCompetitionCallCount` to `StubMatchService`)

**Interfaces:**
- Consumes: `MatchService.cachedCompetition()` (Task 1), `MatchService.fetchCompetition()`
  (existing).
- Produces: `MoreViewModel.loadOnce()`, `MoreViewModel.load()`,
  `MoreViewModel.competitionLogoData: Data?` — consumed by Task 4's `MoreView`.

- [ ] **Step 1: Add `fetchCompetitionCallCount` to `StubMatchService`**

In `BR2026Tests/ViewModels/MatchdayViewModelTests.swift`, add a property after
`private(set) var fetchStandingsCallCount = 0`:
```swift
    private(set) var fetchCompetitionCallCount = 0
```
Change:
```swift
    func fetchCompetition() async throws -> Competition {
        if shouldThrowOnFetch { throw StubServiceError.simulatedFailure }
        return competition
    }
```
to:
```swift
    func fetchCompetition() async throws -> Competition {
        fetchCompetitionCallCount += 1
        if shouldThrowOnFetch { throw StubServiceError.simulatedFailure }
        return competition
    }
```

- [ ] **Step 2: Write the three failing tests in `MoreViewModelTests.swift`**

Replace the existing `"loadCompetition() populates the competition name and logo URL"` test
with three new tests (the old test's "network populates state" behavior is now covered by
the "no cache" case below):

```swift
    @Test("load() shows a fresh cached competition immediately, with no network fetch")
    func loadWithFreshCacheSkipsFetch() async {
        let cached = Competition(
            code: "BSA", name: "Cached Name", season: 2026,
            logoURL: URL(string: "https://example.com/cached-logo.png")!,
            logoData: Data([0x01, 0x02]),
            cachedAt: Date()
        )
        let service = StubMatchService(matches: [], standings: [])
        service.cachedCompetitionOverride = cached
        let viewModel = MoreViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.competitionName == "Cached Name")
        #expect(viewModel.competitionLogoData == Data([0x01, 0x02]))
        #expect(service.fetchCompetitionCallCount == 0)
    }

    @Test("load() shows a stale cached competition immediately, then refreshes in the background")
    func loadWithStaleCacheStillFetches() async {
        let eightDaysAgo = Date().addingTimeInterval(-8 * 24 * 60 * 60)
        let cached = Competition(
            code: "BSA", name: "Stale Name", season: 2026,
            logoURL: URL(string: "https://example.com/stale-logo.png")!,
            logoData: Data([0x01]),
            cachedAt: eightDaysAgo
        )
        let freshCompetition = Competition(
            code: "BSA", name: "Fresh Name", season: 2026,
            logoURL: URL(string: "https://example.com/fresh-logo.png")!
        )
        let service = StubMatchService(matches: [], standings: [], competition: freshCompetition)
        service.cachedCompetitionOverride = cached
        let viewModel = MoreViewModel(service: service)

        await viewModel.load()

        #expect(service.fetchCompetitionCallCount == 1)
        #expect(viewModel.competitionName == "Fresh Name")
    }

    @Test("load() fetches immediately when there is no cached competition")
    func loadWithNoCacheFetchesImmediately() async {
        let competition = Competition(
            code: "BSA", name: "Campeonato Brasileiro Série A", season: 2026,
            logoURL: URL(string: "https://media.api-sports.io/football/leagues/71.png")!
        )
        let service = StubMatchService(matches: [], standings: [], competition: competition)
        let viewModel = MoreViewModel(service: service)

        await viewModel.load()

        #expect(service.fetchCompetitionCallCount == 1)
        #expect(viewModel.competitionName == "Campeonato Brasileiro Série A")
        #expect(viewModel.competitionLogoURL == competition.logoURL)
    }
```

- [ ] **Step 3: Run the tests to verify they fail to compile (methods don't exist yet)**

Run: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test`
Expected: build failure — `MoreViewModel` has no member `load()` yet (only
`loadCompetition()` exists).

- [ ] **Step 4: Implement `load()`/`loadOnce()` in `MoreViewModel`**

In `BR2026/ViewModels/MoreViewModel.swift`, replace:
```swift
    func loadCompetition() async {
        guard let competition = try? await service.fetchCompetition() else { return }
        competitionName = competition.name
        competitionLogoURL = competition.logoURL
    }
```
with:
```swift
    private static let refreshInterval: TimeInterval = 7 * 24 * 60 * 60
    private var hasLoadedOnce = false

    func loadOnce() async {
        guard !hasLoadedOnce else { return }
        hasLoadedOnce = true
        await load()
    }

    func load() async {
        if let cached = service.cachedCompetition() {
            apply(cached)
            guard Date().timeIntervalSince(cached.cachedAt) > Self.refreshInterval else { return }
        }
        if let fresh = try? await service.fetchCompetition() {
            apply(fresh)
        }
    }

    private func apply(_ competition: Competition) {
        competitionName = competition.name
        competitionLogoURL = competition.logoURL
        competitionLogoData = competition.logoData
    }
```

Add a new published property. Change:
```swift
    private(set) var competitionName: String?
    private(set) var competitionLogoURL: URL?
```
to:
```swift
    private(set) var competitionName: String?
    private(set) var competitionLogoURL: URL?
    private(set) var competitionLogoData: Data?
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test`
Expected: all tests pass, including the three new `MoreViewModelTests` cases.

- [ ] **Step 6: Commit**

```bash
git add BR2026/ViewModels/MoreViewModel.swift BR2026Tests/ViewModels/MoreViewModelTests.swift BR2026Tests/ViewModels/MatchdayViewModelTests.swift
git commit -m "MoreViewModel: cache competition once, refresh only when older than 7 days"
```

---

### Task 4: `MoreView` renders cached logo bytes directly

**Files:**
- Modify: `BR2026/Views/More/MoreView.swift`

**Interfaces:**
- Consumes: `MoreViewModel.competitionLogoData`, `.loadOnce()` (Task 3).

- [ ] **Step 1: Switch the `.task` call site to `loadOnce()`**

In `BR2026/Views/More/MoreView.swift`, change:
```swift
            .task { await viewModel.loadCompetition() }
```
to:
```swift
            .task { await viewModel.loadOnce() }
```

- [ ] **Step 2: Add the `UIKit` import**

Add near the top of the file, alongside `import SwiftUI`:
```swift
import UIKit
```

- [ ] **Step 3: Replace the unconditional `AsyncImage` with a cached-bytes-first view**

Replace:
```swift
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
```
with:
```swift
            logoView
                .frame(width: 64, height: 64)
```

Add a new computed property near `competitionHeader`:
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
                                .foregroundStyle(.white.opacity(0.55))
                        )
                }
            }
        }
    }
```

- [ ] **Step 4: Build**

Run: `xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation build`
Expected: `** BUILD SUCCEEDED **`. (No new automated test — Views aren't unit-tested per
CLAUDE.md's "unit test ViewModels and Services — not Views.")

- [ ] **Step 5: Manual smoke test**

Run the app in Simulator (fresh install, so there's no prior cache), confirm the More tab
shows the placeholder briefly then the real crest — then force-quit and relaunch, and
confirm the crest now shows instantly with no placeholder flash (second-launch cache hit).

- [ ] **Step 6: Commit**

```bash
git add BR2026/Views/More/MoreView.swift
git commit -m "MoreView: render cached logo bytes directly, fall back to AsyncImage on first fetch"
```

---

### Task 5: `CLAUDE.md` documentation

**Files:**
- Modify: `CLAUDE.md`

**Interfaces:** None — documentation only.

- [ ] **Step 1: Add a note to the Data & Persistence section**

In `CLAUDE.md`, after the existing bullet about `Standing` being a SwiftData `@Model`, add:
```markdown
- `Competition` is also a SwiftData `@Model`, caching the name and logo image bytes
  together. Unlike Matchday/Fixtures/Standings (which always background-refresh),
  `MoreViewModel.load()` skips the network entirely once a cache exists and is under 7 days
  old — competition branding doesn't change the way scores do, so there's nothing to keep
  continuously fresh.
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "Document Competition's fetch-once-refresh-weekly caching in CLAUDE.md"
```

---

## Final Verification

- [ ] Run the full test suite: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test`
  Expected: all tests pass.
- [ ] Full Simulator build: `xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation build`
  Expected: `** BUILD SUCCEEDED **`.
