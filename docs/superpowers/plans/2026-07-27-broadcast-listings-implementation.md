# Broadcast Listings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show each match's broadcast listings as chips on the match cards in BR2026 and Fixture 2026, filterable to one country from a Settings picker that only appears once listings exist.

**Architecture:** A `Broadcast` value type decodes from the backend's `?include=broadcasts` payload, defensively — an unknown type degrades to `.other`, a malformed country drops the listing, and a missing key yields an empty array. Listings ride on the existing `Match` (a SwiftData `@Model` in BR2026, a plain struct in Fixture 2026) and render through a `BroadcastChips` view appended to the match cards. A `BroadcastCountryStore` owns the user's country selection and a discovered set of available countries, persisted in `UserDefaults` and unioned from every match load.

**Tech Stack:** SwiftUI (iOS 26), SwiftData, Swift Testing, Swift Concurrency. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-07-27-broadcast-listings-design.md` (this repo). Read it before Task 1 — it records the coverage measurements that justify several decisions below.

## Global Constraints

- Two repos. Tasks 1–6 are in `/Users/mlbbr-mac-vinicius/projects/footballWhiteLabel` (BR2026). Tasks 7–12 are in `/Users/mlbbr-mac-vinicius/projects/worldcup` (Fixture 2026). Never mix a commit across them.
- **Never run `git checkout`, `git restore`, `git stash`, or `git add -A` in either repo.** Both contain untracked credential files, and `Localizable.xcstrings`/`Localizable.strings` have been destroyed this way before. Stage named paths only.
- Sort order is always `freeTV → payTV → streaming → ppv → other`, then by name. This mirrors `BROADCAST_TYPE_ORDER` in `worldcupWeb/fixture-live/assets/data.js`.
- `country` is valid only as exactly two ASCII letters; store it uppercased. Invalid → drop the listing.
- `logo` is never decoded. It is null on every listing the API returns.
- Free-to-air tint is `Color(hex: "2dd4bf")` applied as fill @ 0.18, border @ 0.45, label at full opacity.
- Every font and icon size goes through `@ScaledMetric`. Dynamic Type is capped app-wide at `.accessibility1`; do not add another cap.
- SF Symbols only — no emoji in the chips row.
- No View tests. Unit-test models, services, stores and ViewModels only.
- No force-unwraps outside tests.
- Localized strings: BR2026 uses `String(localized:)` with the English text as the key; Fixture 2026 uses short dotted keys (`settings.broadcast`). Keep each app's convention. Interpolated strings use `%@`, never `%lld` — a `%lld`/`%@` mismatch has silently broken this catalog before.
- Settings row label is **"TV & Streaming"**, not "Where to Watch".
- When a match has no listings for the current selection, render **nothing** — no row, no placeholder text.

**Test commands** (the human partner prefers to be asked before these are run — check in rather than running them unprompted):

```bash
# BR2026
cd /Users/mlbbr-mac-vinicius/projects/footballWhiteLabel
xcodebuild test -project BR2026.xcodeproj -scheme BR2026 \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'

# Fixture 2026
cd /Users/mlbbr-mac-vinicius/projects/worldcup
xcodebuild test -project Fixture2026.xcodeproj -scheme Fixture2026 \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'
```

iPhone 16 simulators do not exist on this machine. If a build reports success for code referencing a symbol that does not exist, it is a stale incremental build — `touch` the changed files and rebuild.

## File Structure

**BR2026 (`footballWhiteLabel`)**

| File | Responsibility |
|---|---|
| `BR2026/Models/Broadcast.swift` | `Broadcast`, `BroadcastType`, sort rank. No UI, no networking. |
| `BR2026/Models/BroadcastDTO.swift` | Wire shape + the validating `Broadcast.init?(dto:)` and `Broadcast.list(from:)`. |
| `BR2026/Models/Match.swift` | Gains `broadcasts` storage and `broadcasts(for:)`. |
| `BR2026/Models/MatchDTO.swift` | Gains the optional wire field. |
| `BR2026/Services/LiveMatchService.swift` | Adds `?include=broadcasts`. |
| `BR2026/Services/BroadcastCountrySetting.swift` | `UserDefaults` persistence, protocol-fronted for tests. |
| `BR2026/Services/BroadcastCountryStore.swift` | Selection + discovered-country union. |
| `BR2026/Components/BroadcastChips.swift` | The chips row and its VoiceOver phrase. |
| `BR2026/Views/More/BroadcastCountryPickerView.swift` | The picker screen. |

**Fixture 2026 (`worldcup`)** mirrors the above at `Fixture2026App/Models/Broadcast.swift`, `Fixture2026App/Services/DTOs/APIBroadcast.swift`, `Fixture2026App/Services/BroadcastCountrySetting.swift`, `Fixture2026App/Services/BroadcastCountryStore.swift`, `Fixture2026App/Components/BroadcastChips.swift`, `Fixture2026App/Views/Settings/BroadcastCountryPickerView.swift`.

These are **not** added to `scripts/sync-crests.sh`. Cross-app parity here is a values copy, not a synced file — the two apps' `Match` types, theming and localization conventions differ. `CrestSyncTests` must keep passing untouched.

---

# Part 1 — BR2026 (`/Users/mlbbr-mac-vinicius/projects/footballWhiteLabel`)

## Task 1: The `Broadcast` model and its decoding

**Files:**
- Create: `BR2026/Models/Broadcast.swift`
- Create: `BR2026/Models/BroadcastDTO.swift`
- Test: `BR2026Tests/Models/BroadcastTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `struct Broadcast: Codable, Sendable, Hashable` with `name: String`, `type: BroadcastType`, `country: String`, `url: URL?`; `enum BroadcastType: String, Codable, Sendable, CaseIterable` with cases `freeTV, payTV, streaming, ppv, other` and `var sortRank: Int`; `init?(apiType:)`-free `BroadcastType.init(apiValue: String?)`; `struct BroadcastDTO: Decodable`; `Broadcast.init?(dto: BroadcastDTO)`; `static func list(from: [BroadcastDTO]?) -> [Broadcast]`.

- [ ] **Step 1: Write the failing tests**

Create `BR2026Tests/Models/BroadcastTests.swift`:

```swift
import Testing
import Foundation
@testable import BR2026

@Suite("Broadcast")
struct BroadcastTests {
    private func decode(_ json: String) -> [Broadcast] {
        let dtos = try? JSONDecoder().decode([BroadcastDTO].self, from: Data(json.utf8))
        return Broadcast.list(from: dtos)
    }

    @Test("Known API types map to their cases")
    func knownTypes() {
        #expect(BroadcastType(apiValue: "FREE_TV") == .freeTV)
        #expect(BroadcastType(apiValue: "PAY_TV") == .payTV)
        #expect(BroadcastType(apiValue: "STREAMING") == .streaming)
        #expect(BroadcastType(apiValue: "PPV") == .ppv)
    }

    @Test("An unrecognised or absent type degrades to .other instead of throwing")
    func unknownTypeDegrades() {
        #expect(BroadcastType(apiValue: "RADIO") == .other)
        #expect(BroadcastType(apiValue: nil) == .other)
    }

    @Test("Listings sort free-to-air first and PPV last, then by name")
    func sortOrder() {
        let listings = decode("""
        [{"name":"Premiere","type":"PPV","country":"BR"},
         {"name":"GE TV","type":"STREAMING","country":"BR"},
         {"name":"Globo","type":"FREE_TV","country":"BR"},
         {"name":"SporTV","type":"PAY_TV","country":"BR"}]
        """)
        #expect(listings.map(\.name) == ["Globo", "SporTV", "GE TV", "Premiere"])
    }

    @Test("Two listings of the same type order by name")
    func sameTypeOrdersByName() {
        let listings = decode("""
        [{"name":"Premiere 5","type":"PPV","country":"BR"},
         {"name":"Premiere 4","type":"PPV","country":"BR"}]
        """)
        #expect(listings.map(\.name) == ["Premiere 4", "Premiere 5"])
    }

    @Test("A country code that is not two ASCII letters drops the listing")
    func invalidCountryDropped() {
        let listings = decode("""
        [{"name":"Globo","type":"FREE_TV","country":"BRA"},
         {"name":"Record","type":"FREE_TV","country":"B"},
         {"name":"CazéTV","type":"STREAMING","country":"7 "},
         {"name":"Premiere","type":"PPV","country":"BR"}]
        """)
        #expect(listings.map(\.name) == ["Premiere"])
    }

    @Test("A lowercase country code is uppercased rather than dropped")
    func lowercaseCountryUppercased() {
        let listings = decode("""
        [{"name":"Canal 11","type":"PAY_TV","country":"pt"}]
        """)
        #expect(listings.first?.country == "PT")
    }

    @Test("A missing country drops the listing")
    func missingCountryDropped() {
        let listings = decode("""
        [{"name":"Globo","type":"FREE_TV"}]
        """)
        #expect(listings.isEmpty)
    }

    @Test("A missing or empty name drops the listing rather than rendering a blank chip")
    func missingNameDropped() {
        let listings = decode("""
        [{"type":"FREE_TV","country":"BR"},
         {"name":"","type":"PPV","country":"BR"}]
        """)
        #expect(listings.isEmpty)
    }

    @Test("A null logo is ignored and never surfaces as a property")
    func nullLogoIgnored() {
        let listings = decode("""
        [{"name":"Globo","type":"FREE_TV","country":"BR","logo":null}]
        """)
        #expect(listings.count == 1)
        #expect(listings.first?.name == "Globo")
    }

    @Test("url is captured when present and nil when absent")
    func urlOptional() {
        let listings = decode("""
        [{"name":"Betclic","type":"STREAMING","country":"PT","url":"https://betclic.pt"},
         {"name":"Prime Video","type":"STREAMING","country":"BR"}]
        """)
        #expect(listings.first(where: { $0.name == "Betclic" })?.url?.absoluteString == "https://betclic.pt")
        #expect(listings.first(where: { $0.name == "Prime Video" })?.url == nil)
    }

    @Test("A nil DTO array yields no listings rather than throwing")
    func nilArrayYieldsEmpty() {
        #expect(Broadcast.list(from: nil).isEmpty)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the BR2026 test command from Global Constraints.
Expected: compile failure — `cannot find 'Broadcast' in scope`.

- [ ] **Step 3: Write `Broadcast.swift`**

```swift
import Foundation

/// One way to watch a match, from the backend's `?include=broadcasts` payload.
///
/// `logo` is deliberately absent: the API has only ever returned null for it, and a
/// property that is always nil reads to callers as "still loading" rather than
/// "never provided".
struct Broadcast: Codable, Sendable, Hashable {
    let name: String
    /// ISO-3166-1 alpha-2, uppercased. Guaranteed two ASCII letters — see `init?(dto:)`.
    let country: String
    let type: BroadcastType
    /// Populated for some listings only (the Portuguese ones, at time of writing).
    /// Captured but not yet used; chips are not tappable.
    let url: URL?
}

enum BroadcastType: String, Codable, Sendable, CaseIterable {
    case freeTV
    case payTV
    case streaming
    case ppv
    /// Any value the API sends that we do not recognise. Deliberately unlabelled in the
    /// UI — there is no honest name for a category we cannot identify.
    case other

    /// Cheapest way to watch first. Same order as `BROADCAST_TYPE_ORDER` in
    /// `fixture-live/assets/data.js`, so a match reads the same in the app and on the web.
    var sortRank: Int {
        switch self {
        case .freeTV: return 0
        case .payTV: return 1
        case .streaming: return 2
        case .ppv: return 3
        case .other: return 4
        }
    }

    /// Never fails. The `MatchStatus` decoder that recognised only the values known at
    /// the time broke live scores in every shipped app; this one degrades instead.
    init(apiValue: String?) {
        switch apiValue {
        case "FREE_TV": self = .freeTV
        case "PAY_TV": self = .payTV
        case "STREAMING": self = .streaming
        case "PPV": self = .ppv
        default: self = .other
        }
    }
}
```

- [ ] **Step 4: Write `BroadcastDTO.swift`**

```swift
import Foundation

/// The wire shape. Every field is optional because the endpoint is undocumented and
/// unvalidated upstream — `include=bogus` returns 200 with the key simply absent — so a
/// surprise here must cost one listing, never the whole match.
struct BroadcastDTO: Decodable {
    let name: String?
    let type: String?
    let country: String?
    let url: String?
}

extension Broadcast {
    /// Returns nil for a listing we cannot render honestly: no name, or a country that
    /// is not an ISO-3166-1 alpha-2 code. Mirrors `COUNTRY_CODE_RE` in
    /// `fixture-live/assets/data.js`, which validates the same field for the same reason.
    init?(dto: BroadcastDTO) {
        guard let name = dto.name, !name.isEmpty else { return nil }
        guard let country = dto.country,
              country.count == 2,
              country.allSatisfy({ $0.isASCII && $0.isLetter })
        else { return nil }

        self.init(
            name: name,
            country: country.uppercased(),
            type: BroadcastType(apiValue: dto.type),
            url: dto.url.flatMap(URL.init(string:))
        )
    }

    /// Decodes and sorts in one step, so every consumer sees listings in the same order
    /// and no caller has to remember to sort.
    static func list(from dtos: [BroadcastDTO]?) -> [Broadcast] {
        (dtos ?? [])
            .compactMap(Broadcast.init(dto:))
            .sorted { ($0.type.sortRank, $0.name) < ($1.type.sortRank, $1.name) }
    }
}
```

- [ ] **Step 5: Add both files to the Xcode target**

Both files must be members of the `BR2026` target. If added outside Xcode, verify with:

```bash
cd /Users/mlbbr-mac-vinicius/projects/footballWhiteLabel
grep -c "Broadcast.swift\|BroadcastDTO.swift" BR2026.xcodeproj/project.pbxproj
```

Expected: a non-zero count. A file on disk but absent from `project.pbxproj` compiles nowhere and fails with "cannot find in scope".

- [ ] **Step 6: Run the tests to verify they pass**

Run the BR2026 test command. Expected: all 11 `Broadcast` tests PASS, no other suite regresses.

- [ ] **Step 7: Commit**

```bash
cd /Users/mlbbr-mac-vinicius/projects/footballWhiteLabel
git add BR2026/Models/Broadcast.swift BR2026/Models/BroadcastDTO.swift \
        BR2026Tests/Models/BroadcastTests.swift BR2026.xcodeproj/project.pbxproj
git commit -m "Add Broadcast model with defensive decoding"
```

---

## Task 2: Carry broadcasts on `Match` and request them from the API

**Files:**
- Modify: `BR2026/Models/MatchDTO.swift:3-14`
- Modify: `BR2026/Models/Match.swift:6-19` (property), `:53-70` (`init(dto:)`), `:72-81` (`update(from:)`)
- Modify: `BR2026/Services/LiveMatchService.swift:42`
- Modify: `BR2026/MockData/MockDataProvider.swift`
- Test: `BR2026Tests/Models/MatchBroadcastTests.swift`

**Interfaces:**
- Consumes: `Broadcast`, `BroadcastDTO`, `Broadcast.list(from:)` (Task 1).
- Produces: `Match.broadcasts: [Broadcast]` (stored, defaults to `[]`) and `Match.broadcasts(for country: String?) -> [Broadcast]`.

- [ ] **Step 1: Write the failing tests**

Create `BR2026Tests/Models/MatchBroadcastTests.swift`:

```swift
import Testing
import Foundation
@testable import BR2026

@Suite("Match broadcasts")
struct MatchBroadcastTests {
    private func match(withBroadcastsJSON json: String) -> Match? {
        let matchJSON = """
        {"id": 1, "utcDate": "2026-07-27T20:00:00Z", "status": "SCHEDULED",
         "matchday": 1, "stage": "REGULAR_SEASON",
         "homeTeam": {"id": 10, "name": "Bahia", "shortName": "Bahia", "tla": "BAH", "crest": null},
         "awayTeam": {"id": 11, "name": "Corinthians", "shortName": "Corinthians", "tla": "COR", "crest": null},
         "score": {"winner": null, "fullTime": {"home": null, "away": null},
                   "halfTime": {"home": null, "away": null}},
         "venue": "Arena Fonte Nova", "minute": null\(json)}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let dto = try? decoder.decode(MatchDTO.self, from: Data(matchJSON.utf8)) else { return nil }
        return Match(dto: dto)
    }

    @Test("A match with no broadcasts key decodes with an empty list, not a failure")
    func absentKeyDecodes() {
        let decoded = match(withBroadcastsJSON: "")
        #expect(decoded != nil)
        #expect(decoded?.broadcasts.isEmpty == true)
    }

    @Test("Broadcasts decode onto the match, sorted")
    func broadcastsDecode() {
        let decoded = match(withBroadcastsJSON: """
        , "broadcasts": [{"name":"Premiere","type":"PPV","country":"BR"},
                         {"name":"Globo","type":"FREE_TV","country":"BR"}]
        """)
        #expect(decoded?.broadcasts.map(\.name) == ["Globo", "Premiere"])
    }

    @Test("broadcasts(for: nil) returns every listing regardless of country")
    func allCountriesReturnsEverything() {
        let decoded = match(withBroadcastsJSON: """
        , "broadcasts": [{"name":"Globo","type":"FREE_TV","country":"BR"},
                         {"name":"Canal 11","type":"PAY_TV","country":"PT"}]
        """)
        #expect(decoded?.broadcasts(for: nil).map(\.name) == ["Globo", "Canal 11"])
    }

    @Test("broadcasts(for:) filters strictly to the selected country")
    func selectedCountryFiltersStrictly() {
        let decoded = match(withBroadcastsJSON: """
        , "broadcasts": [{"name":"Globo","type":"FREE_TV","country":"BR"},
                         {"name":"Canal 11","type":"PAY_TV","country":"PT"},
                         {"name":"Betclic","type":"STREAMING","country":"PT"}]
        """)
        #expect(decoded?.broadcasts(for: "PT").map(\.name) == ["Canal 11", "Betclic"])
    }

    @Test("A country with no listing on this match returns empty — it does not fall back")
    func unmatchedCountryReturnsEmpty() {
        let decoded = match(withBroadcastsJSON: """
        , "broadcasts": [{"name":"Globo","type":"FREE_TV","country":"BR"}]
        """)
        #expect(decoded?.broadcasts(for: "PT").isEmpty == true)
    }

    @Test("update(from:) refreshes listings so a match that gains one mid-season picks it up")
    func updateRefreshesBroadcasts() throws {
        let before = try #require(match(withBroadcastsJSON: ""))
        #expect(before.broadcasts.isEmpty)

        let laterJSON = """
        {"id": 1, "utcDate": "2026-07-27T20:00:00Z", "status": "SCHEDULED",
         "matchday": 1, "stage": "REGULAR_SEASON",
         "homeTeam": {"id": 10, "name": "Bahia", "shortName": "Bahia", "tla": "BAH", "crest": null},
         "awayTeam": {"id": 11, "name": "Corinthians", "shortName": "Corinthians", "tla": "COR", "crest": null},
         "score": {"winner": null, "fullTime": {"home": null, "away": null},
                   "halfTime": {"home": null, "away": null}},
         "venue": "Arena Fonte Nova", "minute": null,
         "broadcasts": [{"name":"Globo","type":"FREE_TV","country":"BR"}]}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let laterDTO = try decoder.decode(MatchDTO.self, from: Data(laterJSON.utf8))

        before.update(from: laterDTO)

        #expect(before.broadcasts.map(\.name) == ["Globo"])
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the BR2026 test command. Expected: FAIL — `value of type 'Match' has no member 'broadcasts'`.

- [ ] **Step 3: Add the wire field to `MatchDTO`**

In `BR2026/Models/MatchDTO.swift`, add one line to `struct MatchDTO` after `minute`:

```swift
    let broadcasts: [BroadcastDTO]?
```

It is optional because `?include=broadcasts` is unvalidated upstream: a typo returns 200 with the key absent, and that must not fail the whole match list.

- [ ] **Step 4: Store and expose broadcasts on `Match`**

In `BR2026/Models/Match.swift`, add the stored property after `var minute: Int?`:

```swift
    /// SwiftData persists a Codable value type as an opaque blob. The default makes this
    /// a lightweight migration, so shipped installs open their existing store unchanged
    /// and backfill on the next refresh. Never usable in a `#Predicate`.
    var broadcasts: [Broadcast] = []
```

Add `broadcasts: [Broadcast] = []` as the last parameter of the designated `init`, and `self.broadcasts = broadcasts` as the last assignment in its body.

In `convenience init(dto:)`, add as the last argument:

```swift
            broadcasts: Broadcast.list(from: dto.broadcasts)
```

In `update(from dto: MatchDTO)`, add as the last statement:

```swift
        broadcasts = Broadcast.list(from: dto.broadcasts)
```

Then add this extension at the end of the file, outside the class:

```swift
extension Match {
    /// Listings for the user's selected country, or every listing when none is selected.
    /// Strict: a match with nothing in the selected country returns empty rather than
    /// falling back, so the chips never advertise a channel the user cannot get.
    /// Already sorted — `Broadcast.list(from:)` sorts at decode time.
    func broadcasts(for country: String?) -> [Broadcast] {
        guard let country else { return broadcasts }
        return broadcasts.filter { $0.country == country }
    }
}
```

- [ ] **Step 5: Request the field from the API**

In `BR2026/Services/LiveMatchService.swift`, replace line 42:

```swift
        let url = config.apiBaseURL.appendingPathComponent("v4/competitions/\(config.competitionCode)/matches")
```

with:

```swift
        // `include=broadcasts` is undocumented and unvalidated upstream — a typo returns
        // 200 with the key simply absent, so a mistake here goes silently dead rather
        // than erroring. It is the only way the matches payload carries listings.
        var components = URLComponents(
            url: config.apiBaseURL.appendingPathComponent("v4/competitions/\(config.competitionCode)/matches"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "include", value: "broadcasts")]
        guard let url = components?.url else { throw MatchServiceError.invalidResponse }
```

- [ ] **Step 6: Add broadcast fixtures to the mock data**

In `BR2026/MockData/MockDataProvider.swift`, find `matchesJSON` and add a `broadcasts` array to exactly three matches, leaving every other match's key absent (the absent case is the common one and must stay covered):

- one match with a single free-to-air listing:
  `"broadcasts": [{"name":"Globo","type":"FREE_TV","country":"BR","logo":null}]`
- one match with BR and PT listings together:
  `"broadcasts": [{"name":"Prime Video","type":"STREAMING","country":"BR","logo":null},{"name":"Canal 11","type":"PAY_TV","country":"PT","url":"https://canal11.pt","logo":null},{"name":"Betclic","type":"STREAMING","country":"PT","url":"https://betclic.pt","logo":null}]`
- one match with an unrecognised type:
  `"broadcasts": [{"name":"Rádio Globo","type":"RADIO","country":"BR","logo":null}]`

Insert each as a new key inside the match object, before its closing brace. Edit the string surgically — do not round-trip this file through a JSON formatter, which reflows thousands of unrelated lines.

- [ ] **Step 7: Run the tests to verify they pass**

Run the BR2026 test command. Expected: the 6 `Match broadcasts` tests PASS. `MatchSwiftDataTests` and `MockMatchServiceTests` must still pass — if `MockMatchServiceTests` asserts a match count or shape, the fixture edits above must not have changed either.

- [ ] **Step 8: Commit**

```bash
cd /Users/mlbbr-mac-vinicius/projects/footballWhiteLabel
git add BR2026/Models/Match.swift BR2026/Models/MatchDTO.swift \
        BR2026/Services/LiveMatchService.swift BR2026/MockData/MockDataProvider.swift \
        BR2026Tests/Models/MatchBroadcastTests.swift
git commit -m "Carry broadcast listings on Match and request them from the API"
```

---

## Task 3: The country setting and store

**Files:**
- Create: `BR2026/Services/BroadcastCountrySetting.swift`
- Create: `BR2026/Services/BroadcastCountryStore.swift`
- Test: `BR2026Tests/Services/BroadcastCountryStoreTests.swift`

**Interfaces:**
- Consumes: `Match.broadcasts` (Task 2).
- Produces: `protocol BroadcastCountrySetting` (`var selectedCountry: String? { get }`, `func setSelectedCountry(_:)`, `var knownCountries: [String] { get }`, `func setKnownCountries(_:)`); `final class BroadcastCountryStore` with `private(set) var selectedCountry: String?`, `private(set) var knownCountries: [String]`, `var isAvailable: Bool`, `func select(_ code: String?)`, `func noteAvailability(in matches: [Match])`.

- [ ] **Step 1: Write the failing tests**

Create `BR2026Tests/Services/BroadcastCountryStoreTests.swift`:

```swift
import Testing
import Foundation
@testable import BR2026

/// Deliberately not `private` — Task 5's `MoreViewModelTests` and Task 6's ViewModel
/// tests use this same stub.
@MainActor
final class StubBroadcastCountrySetting: BroadcastCountrySetting {
    var selectedCountry: String?
    var knownCountries: [String]

    init(selectedCountry: String? = nil, knownCountries: [String] = []) {
        self.selectedCountry = selectedCountry
        self.knownCountries = knownCountries
    }

    func setSelectedCountry(_ code: String?) { selectedCountry = code }
    func setKnownCountries(_ codes: [String]) { knownCountries = codes }
}

@Suite("BroadcastCountryStore")
@MainActor
struct BroadcastCountryStoreTests {
    private func match(id: Int, broadcasts: [Broadcast]) -> Match {
        Match(
            id: id,
            utcDate: Date(timeIntervalSince1970: 0),
            status: .scheduled,
            matchday: 1,
            stage: "REGULAR_SEASON",
            homeTeam: Team(id: 10, name: "Bahia", shortName: "Bahia", crestURL: nil),
            awayTeam: Team(id: 11, name: "Corinthians", shortName: "Corinthians", crestURL: nil),
            homeScore: nil,
            awayScore: nil,
            winner: nil,
            venue: nil,
            minute: nil,
            broadcasts: broadcasts
        )
    }

    private func listing(_ name: String, _ country: String) -> Broadcast {
        Broadcast(name: name, country: country, type: .freeTV, url: nil)
    }

    @Test("A fresh store has no known countries, so the settings row stays hidden")
    func freshStoreIsUnavailable() {
        let store = BroadcastCountryStore(setting: StubBroadcastCountrySetting())
        #expect(store.knownCountries.isEmpty)
        #expect(store.isAvailable == false)
        #expect(store.selectedCountry == nil)
    }

    @Test("noteAvailability records every country seen, sorted, and reveals the row")
    func noteAvailabilityRecordsCountries() {
        let store = BroadcastCountryStore(setting: StubBroadcastCountrySetting())

        store.noteAvailability(in: [
            match(id: 1, broadcasts: [listing("Canal 11", "PT")]),
            match(id: 2, broadcasts: [listing("Globo", "BR")]),
            match(id: 3, broadcasts: [])
        ])

        #expect(store.knownCountries == ["BR", "PT"])
        #expect(store.isAvailable)
    }

    @Test("noteAvailability unions rather than replaces, so a BR-only round keeps PT selectable")
    func noteAvailabilityUnions() {
        let store = BroadcastCountryStore(setting: StubBroadcastCountrySetting())
        store.noteAvailability(in: [match(id: 1, broadcasts: [listing("Canal 11", "PT")])])

        store.noteAvailability(in: [match(id: 2, broadcasts: [listing("Globo", "BR")])])

        #expect(store.knownCountries == ["BR", "PT"])
    }

    @Test("noteAvailability with no listings anywhere leaves the row hidden")
    func noteAvailabilityWithNoListingsStaysHidden() {
        let store = BroadcastCountryStore(setting: StubBroadcastCountrySetting())

        store.noteAvailability(in: [match(id: 1, broadcasts: []), match(id: 2, broadcasts: [])])

        #expect(store.knownCountries.isEmpty)
        #expect(store.isAvailable == false)
    }

    @Test("Known countries persist to the setting and are restored on the next launch")
    func knownCountriesPersist() {
        let setting = StubBroadcastCountrySetting()
        let first = BroadcastCountryStore(setting: setting)
        first.noteAvailability(in: [match(id: 1, broadcasts: [listing("Globo", "BR")])])
        #expect(setting.knownCountries == ["BR"])

        let relaunched = BroadcastCountryStore(setting: setting)

        #expect(relaunched.knownCountries == ["BR"])
        #expect(relaunched.isAvailable)
    }

    @Test("Selecting a country persists it; clearing returns to All countries")
    func selectionRoundTrips() {
        let setting = StubBroadcastCountrySetting()
        let store = BroadcastCountryStore(setting: setting)

        store.select("BR")
        #expect(store.selectedCountry == "BR")
        #expect(setting.selectedCountry == "BR")

        store.select(nil)
        #expect(store.selectedCountry == nil)
        #expect(setting.selectedCountry == nil)
    }

    @Test("A persisted selection is restored on launch")
    func persistedSelectionRestored() {
        let setting = StubBroadcastCountrySetting(selectedCountry: "PT", knownCountries: ["BR", "PT"])

        let store = BroadcastCountryStore(setting: setting)

        #expect(store.selectedCountry == "PT")
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the BR2026 test command. Expected: FAIL — `cannot find 'BroadcastCountryStore' in scope`.

- [ ] **Step 3: Write `BroadcastCountrySetting.swift`**

```swift
import Foundation

/// Persistence for the broadcast country preference, abstracted so
/// `BroadcastCountryStore` can be unit-tested without touching real `UserDefaults`.
/// Same shape as `TeamThemeSetting`.
@MainActor
protocol BroadcastCountrySetting {
    /// nil means "All countries" — the default.
    var selectedCountry: String? { get }
    func setSelectedCountry(_ code: String?)

    /// Every country code seen in match data so far, sorted. Drives whether the
    /// settings row exists at all.
    var knownCountries: [String] { get }
    func setKnownCountries(_ codes: [String])
}

@MainActor
final class UserDefaultsBroadcastCountrySetting: BroadcastCountrySetting {
    private let defaults: UserDefaults
    private let selectedKey = "selectedBroadcastCountry"
    private let knownKey = "knownBroadcastCountries"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selectedCountry: String? { defaults.string(forKey: selectedKey) }

    func setSelectedCountry(_ code: String?) {
        if let code {
            defaults.set(code, forKey: selectedKey)
        } else {
            defaults.removeObject(forKey: selectedKey)
        }
    }

    var knownCountries: [String] { defaults.stringArray(forKey: knownKey) ?? [] }

    func setKnownCountries(_ codes: [String]) {
        defaults.set(codes, forKey: knownKey)
    }
}
```

- [ ] **Step 4: Write `BroadcastCountryStore.swift`**

```swift
import Foundation
import Observation

/// Owns which country's broadcast listings the user wants to see, and which countries
/// there are to choose from.
///
/// The available set is discovered from match data rather than hardcoded: only
/// Brasileirão carries listings today, and the five sibling championship targets would
/// otherwise ship a picker with nothing in it. Discovering it means the row appears by
/// itself the first time a refresh returns a listing for a league — no code change, no
/// release.
///
/// Discovery goes through `UserDefaults` rather than reading `service.cachedMatches()`
/// from the settings screen because Fixture 2026 has no local store to read back, and
/// one mechanism across both apps is worth the extra key.
@Observable
@MainActor
final class BroadcastCountryStore {
    /// nil means "All countries".
    private(set) var selectedCountry: String?
    private(set) var knownCountries: [String]

    private let setting: BroadcastCountrySetting

    init(setting: BroadcastCountrySetting = UserDefaultsBroadcastCountrySetting()) {
        self.setting = setting
        selectedCountry = setting.selectedCountry
        knownCountries = setting.knownCountries
    }

    /// False until match data has produced at least one country. The settings row is
    /// hidden entirely while this is false — a picker offering only "All countries"
    /// reads as broken.
    var isAvailable: Bool { !knownCountries.isEmpty }

    func select(_ code: String?) {
        guard code != selectedCountry else { return }
        selectedCountry = code
        setting.setSelectedCountry(code)
    }

    /// Unions the countries present in `matches` into the known set.
    ///
    /// Union rather than replace: a round where only Brazilian listings were entered
    /// must not make a previously-seen Portugal unselectable, and a user's saved
    /// selection must stay valid. The set therefore only grows within an install, which
    /// is the right failure mode here.
    func noteAvailability(in matches: [Match]) {
        let seen = Set(matches.flatMap(\.broadcasts).map(\.country))
        guard !seen.isEmpty else { return }
        let merged = Set(knownCountries).union(seen).sorted()
        guard merged != knownCountries else { return }
        knownCountries = merged
        setting.setKnownCountries(merged)
    }
}
```

- [ ] **Step 5: Add both files to the `BR2026` target**

Verify:

```bash
cd /Users/mlbbr-mac-vinicius/projects/footballWhiteLabel
grep -c "BroadcastCountrySetting.swift\|BroadcastCountryStore.swift" BR2026.xcodeproj/project.pbxproj
```

Expected: non-zero.

- [ ] **Step 6: Run the tests to verify they pass**

Run the BR2026 test command. Expected: the 7 `BroadcastCountryStore` tests PASS.

If `Match`'s or `Team`'s initializer signature in the test helper does not compile, fix the **test** to match the real initializer — do not change `Match` or `Team` to suit the test.

- [ ] **Step 7: Commit**

```bash
cd /Users/mlbbr-mac-vinicius/projects/footballWhiteLabel
git add BR2026/Services/BroadcastCountrySetting.swift BR2026/Services/BroadcastCountryStore.swift \
        BR2026Tests/Services/BroadcastCountryStoreTests.swift BR2026.xcodeproj/project.pbxproj
git commit -m "Add broadcast country store with discovered availability"
```

---

## Task 4: The chips row on the match cards

**Files:**
- Create: `BR2026/Components/BroadcastChips.swift`
- Modify: `BR2026/Components/FixtureMatchCard.swift:13-27`
- Modify: `BR2026/Components/HeroMatchCard.swift:15-38`
- Modify: `BR2026/App/Championship.swift:22,43`
- Modify: `BR2026/Views/Root/ContentView.swift:6,29`
- Test: `BR2026Tests/Components/BroadcastAccessibilityTests.swift`

**Interfaces:**
- Consumes: `Broadcast`, `BroadcastType` (Task 1); `Match.broadcasts(for:)` (Task 2); `BroadcastCountryStore` (Task 3).
- Produces: `struct BroadcastChips: View` with `init(listings: [Broadcast], showsCountry: Bool)`; `Broadcast.accessibilityPhrase(for listings: [Broadcast]) -> String?`; `Championship.broadcastCountryStore: BroadcastCountryStore`.

- [ ] **Step 1: Write the failing tests**

The chips view itself is not tested (no View tests). Its VoiceOver phrase is pure logic and is. Create `BR2026Tests/Components/BroadcastAccessibilityTests.swift`:

```swift
import Testing
@testable import BR2026

@Suite("Broadcast accessibility phrase")
struct BroadcastAccessibilityTests {
    private func listing(_ name: String, _ type: BroadcastType) -> Broadcast {
        Broadcast(name: name, country: "BR", type: type, url: nil)
    }

    @Test("No listings produces no phrase, so the card's label is unchanged")
    func emptyProducesNil() {
        #expect(Broadcast.accessibilityPhrase(for: []) == nil)
    }

    @Test("Each listing is spoken with its type, so colour never carries the meaning alone")
    func typeIsSpoken() throws {
        let phrase = try #require(Broadcast.accessibilityPhrase(for: [
            listing("Globo", .freeTV),
            listing("Premiere", .ppv)
        ]))
        #expect(phrase.contains("Globo"))
        #expect(phrase.contains("Premiere"))
        #expect(phrase.lowercased().contains("free"))
        #expect(phrase.lowercased().contains("pay per view"))
    }

    @Test("An unrecognised type is spoken as the broadcaster name alone")
    func otherTypeSpokenWithoutLabel() throws {
        let phrase = try #require(Broadcast.accessibilityPhrase(for: [listing("Rádio Globo", .other)]))
        #expect(phrase.contains("Rádio Globo"))
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the BR2026 test command. Expected: FAIL — `type 'Broadcast' has no member 'accessibilityPhrase'`.

- [ ] **Step 3: Write `BroadcastChips.swift`**

```swift
import SwiftUI

/// The "how to watch" row on a match card: one chip per listing, free-to-air first and
/// tinted teal so the cheapest way to watch reads at a glance.
///
/// Renders nothing when there are no listings. At current coverage (45 of 380 matches)
/// an explicit "not confirmed yet" line would appear on 7 cards in 8 and add ~26pt to
/// nearly every card in the app — absence is quieter, and just as honest.
struct BroadcastChips: View {
    let listings: [Broadcast]
    /// True when the user is seeing every country at once, where a bare "Canal 11" is
    /// meaningless to a viewer in Brazil. Redundant under a specific country filter.
    let showsCountry: Bool

    @Environment(\.themeTokens) private var themeTokens
    @ScaledMetric private var iconSize: CGFloat = 11
    @ScaledMetric private var chipFontSize: CGFloat = 11
    @ScaledMetric private var countryFontSize: CGFloat = 9

    private static let freeToAirColor = Color(hex: "2dd4bf")

    var body: some View {
        if !listings.isEmpty {
            HStack(alignment: .center, spacing: 7) {
                Image(systemName: "tv")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(themeTokens.textColor.opacity(0.4))
                chipFlow
                Spacer(minLength: 0)
            }
        }
    }

    /// A wrapping row: four listings with country codes can exceed one line at larger
    /// Dynamic Type sizes.
    private var chipFlow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { chips }
            VStack(alignment: .leading, spacing: 6) { chips }
        }
    }

    @ViewBuilder
    private var chips: some View {
        ForEach(listings, id: \.self) { listing in
            chip(for: listing)
        }
    }

    private func chip(for listing: Broadcast) -> some View {
        let isFree = listing.type == .freeTV
        // The design system's derived-accent recipe (fill 18%, border 45%, label full),
        // applied with the teal "advance" colour rather than the accent — an accent-tinted
        // chip would read as a live indicator.
        let tint = isFree ? Self.freeToAirColor : themeTokens.textColor

        return HStack(spacing: 4) {
            Text(listing.name)
                .font(.system(size: chipFontSize, weight: .bold))
                .lineLimit(1)
            if showsCountry {
                Text(listing.country)
                    .font(.system(size: countryFontSize, weight: .heavy))
                    .tracking(0.6)
                    .opacity(0.6)
            }
        }
        .foregroundStyle(isFree ? tint : tint.opacity(0.82))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(tint.opacity(isFree ? 0.18 : 0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(tint.opacity(isFree ? 0.45 : 0.14), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

extension Broadcast {
    /// The VoiceOver sentence appended to a match card's label, or nil when there is
    /// nothing to say — in which case the card's label stays byte-identical to before
    /// this feature existed.
    ///
    /// Each listing is spoken with its type, so the free-to-air distinction never rests
    /// on colour alone.
    static func accessibilityPhrase(for listings: [Broadcast]) -> String? {
        guard !listings.isEmpty else { return nil }
        let parts = listings.map { listing -> String in
            guard let typeName = listing.type.accessibilityName else { return listing.name }
            return "\(listing.name), \(typeName)"
        }
        return String(
            localized: "Available on \(parts.joined(separator: "; "))",
            comment: "VoiceOver sentence listing where a match can be watched. Argument: a pre-joined list of broadcasters with their type, e.g. 'Globo, free to air; Premiere, pay per view'."
        )
    }
}

extension BroadcastType {
    /// nil for `.other` — there is no honest name for a category we do not recognise, so
    /// the broadcaster is spoken alone.
    var accessibilityName: String? {
        switch self {
        case .freeTV:
            return String(localized: "free to air", comment: "Broadcast type spoken by VoiceOver: a channel available without a subscription.")
        case .payTV:
            return String(localized: "pay TV", comment: "Broadcast type spoken by VoiceOver: a subscription television channel.")
        case .streaming:
            return String(localized: "streaming", comment: "Broadcast type spoken by VoiceOver: an internet streaming service.")
        case .ppv:
            return String(localized: "pay per view", comment: "Broadcast type spoken by VoiceOver: a per-match paid broadcast.")
        case .other:
            return nil
        }
    }
}
```

- [ ] **Step 4: Inject the store app-wide**

In `BR2026/App/Championship.swift`, add a stored property next to `themeStore` (line 22):

```swift
    let broadcastCountryStore: BroadcastCountryStore
```

and initialise it next to `themeStore`'s assignment (line 43):

```swift
        broadcastCountryStore = BroadcastCountryStore()
```

In `BR2026/Views/Root/ContentView.swift`, add a stored property next to `themeStore` (line 6):

```swift
    let broadcastCountryStore: BroadcastCountryStore
```

and add the environment injection next to `.environment(\.themeTokens, ...)` (line 29):

```swift
        .environment(broadcastCountryStore)
```

Update every `ContentView(...)` construction site to pass it. Find them with:

```bash
cd /Users/mlbbr-mac-vinicius/projects/footballWhiteLabel
grep -rn "ContentView(" BR2026 --include='*.swift'
```

Every `#Preview` that constructs `ContentView`, `FixtureMatchCard` or `HeroMatchCard` must also supply `.environment(BroadcastCountryStore(setting: UserDefaultsBroadcastCountrySetting(defaults: UserDefaults(suiteName: "preview") ?? .standard)))` — an `@Environment(BroadcastCountryStore.self)` read with nothing injected traps at runtime, and a crashing preview is easy to miss until someone opens the canvas.

- [ ] **Step 5: Add the chips to `FixtureMatchCard`**

In `BR2026/Components/FixtureMatchCard.swift`, add below the existing `@Environment(\.themeTokens)` line:

```swift
    @Environment(BroadcastCountryStore.self) private var broadcastCountryStore
```

Add these computed properties to the struct:

```swift
    private var listings: [Broadcast] {
        match.broadcasts(for: broadcastCountryStore.selectedCountry)
    }

    /// The card's own label plus the listings, as one combined element — the card is
    /// `.accessibilityElement(children: .combine)`, so the chips must not become a
    /// separate stop in the VoiceOver order.
    private var combinedAccessibilityLabel: String {
        guard let phrase = Broadcast.accessibilityPhrase(for: listings) else {
            return match.accessibilityLabel
        }
        return "\(match.accessibilityLabel). \(phrase)"
    }
```

Change the `body`'s `VStack(spacing: 12)` content so the chips follow the team rows, and swap the accessibility label:

```swift
        GlassCard(cornerRadius: 22, style: .transparent) {
            VStack(spacing: 12) {
                header
                VStack(spacing: 0) {
                    teamRow(match.homeTeam, score: match.homeScore)
                    divider
                    teamRow(match.awayTeam, score: match.awayScore)
                    if !listings.isEmpty {
                        divider
                        BroadcastChips(
                            listings: listings,
                            showsCountry: broadcastCountryStore.selectedCountry == nil
                        )
                        .padding(.top, 10)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(combinedAccessibilityLabel)
        .accessibilityHint(Text("Double tap to view match details", comment: "VoiceOver hint on a match card button."))
```

The chips sit inside the inner `VStack(spacing: 0)` so they share the team rows' divider rhythm rather than the outer 12pt spacing.

- [ ] **Step 6: Add the chips to `HeroMatchCard`**

In `BR2026/Components/HeroMatchCard.swift`, add the same `@Environment(BroadcastCountryStore.self)` property and the same two computed properties (`listings`, `combinedAccessibilityLabel`) — repeated rather than shared, because the two cards' bodies differ and a shared base view would couple them for no gain.

In the `GlassCard`'s `VStack(spacing: 20)`, after the `Text(venueLabel)` block, add:

```swift
                if !listings.isEmpty {
                    BroadcastChips(
                        listings: listings,
                        showsCountry: broadcastCountryStore.selectedCountry == nil
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                }
```

and replace `.accessibilityLabel(match.accessibilityLabel)` with `.accessibilityLabel(combinedAccessibilityLabel)`.

- [ ] **Step 7: Run the tests to verify they pass**

Run the BR2026 test command. Expected: the 3 accessibility-phrase tests PASS and the app compiles. If `AccessibilityAuditUITests` runs in this scheme and reports `.textClipped` on a chip, lower that `Text`'s `minimumScaleFactor` to `0.5` as `FixtureMatchCard`'s venue label already does.

- [ ] **Step 8: Commit**

```bash
cd /Users/mlbbr-mac-vinicius/projects/footballWhiteLabel
git add BR2026/Components/BroadcastChips.swift BR2026/Components/FixtureMatchCard.swift \
        BR2026/Components/HeroMatchCard.swift BR2026/App/Championship.swift \
        BR2026/Views/Root/ContentView.swift \
        BR2026Tests/Components/BroadcastAccessibilityTests.swift BR2026.xcodeproj/project.pbxproj
git commit -m "Show broadcast chips on BR2026 match cards"
```

---

## Task 5: The settings row and picker screen

**Files:**
- Create: `BR2026/Views/More/BroadcastCountryPickerView.swift`
- Modify: `BR2026/Models/MoreDestination.swift:3-7`
- Modify: `BR2026/ViewModels/MoreViewModel.swift:10-14,34-58`
- Modify: `BR2026/Views/More/MoreView.swift:43-55`
- Modify: `BR2026/Resources/Localizable.xcstrings`
- Test: `BR2026Tests/ViewModels/MoreViewModelTests.swift` (extend)

**Interfaces:**
- Consumes: `BroadcastCountryStore` (Task 3).
- Produces: `MoreDestination.broadcastCountryPicker`; `MoreViewModel.init(service:broadcastCountryStore:)`; `struct BroadcastCountryPickerView: View`.

- [ ] **Step 1: Write the failing tests**

Append to `BR2026Tests/ViewModels/MoreViewModelTests.swift` (inside the existing suite — match its existing stub and helper names):

```swift
    @Test("With no broadcast countries known, the TV & Streaming row is absent")
    func broadcastRowHiddenWithoutData() {
        let store = BroadcastCountryStore(setting: StubBroadcastCountrySetting())
        let viewModel = MoreViewModel(service: StubMatchService(matches: [], standings: []), broadcastCountryStore: store)

        let ids = viewModel.sections.flatMap { $0.rows.map(\.id) }

        #expect(ids.contains("broadcastCountry") == false)
    }

    @Test("Once a country has been seen, the TV & Streaming row appears in Preferences")
    func broadcastRowAppearsWithData() {
        let store = BroadcastCountryStore(setting: StubBroadcastCountrySetting(knownCountries: ["BR"]))
        let viewModel = MoreViewModel(service: StubMatchService(matches: [], standings: []), broadcastCountryStore: store)

        let preferences = viewModel.sections.first { $0.id == "preferences" }

        #expect(preferences?.rows.map(\.id).contains("broadcastCountry") == true)
    }
```

`StubBroadcastCountrySetting` is already declared non-`private` in `BroadcastCountryStoreTests.swift` (Task 3), so it needs no change — just use it.

- [ ] **Step 2: Run the tests to verify they fail**

Run the BR2026 test command. Expected: FAIL — `MoreViewModel` has no initializer accepting `broadcastCountryStore`.

- [ ] **Step 3: Add the destination case**

In `BR2026/Models/MoreDestination.swift`:

```swift
enum MoreDestination: Hashable {
    case termsOfService
    case appIconPicker
    case teamThemePicker
    case broadcastCountryPicker
}
```

- [ ] **Step 4: Make the row conditional in `MoreViewModel`**

`sections` is currently a `let` built from a `static var`. The row now depends on instance state, so change `sections` to a computed property and make `preferencesRows` an instance member.

Replace lines 10–29 (`let sections: [MoreSection] = [...]`) with:

```swift
    var sections: [MoreSection] {
        [
            MoreSection(id: "preferences", titleKey: "Preferences", rows: preferencesRows),
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
            )
        ]
    }
```

Change `private static var preferencesRows: [MoreRow]` to `private var preferencesRows: [MoreRow]`, and insert this before `return rows`:

```swift
        // Only rendered once match data has actually produced a country. Five of the six
        // championship targets have no broadcast listings at all, and a picker whose only
        // entry is "All countries" reads as broken. Discovered rather than #if-gated, so
        // the row turns up on its own the first time a league gets listings.
        if broadcastCountryStore.isAvailable {
            rows.append(
                MoreRow(
                    id: "broadcastCountry",
                    titleKey: "TV & Streaming",
                    systemImage: "tv",
                    destination: .broadcastCountryPicker,
                    isEnabled: true
                )
            )
        }
```

Add the stored property and widen the initializer:

```swift
    private let broadcastCountryStore: BroadcastCountryStore

    init(service: MatchService, broadcastCountryStore: BroadcastCountryStore) {
        self.service = service
        self.broadcastCountryStore = broadcastCountryStore
    }
```

- [ ] **Step 5: Write `BroadcastCountryPickerView.swift`**

```swift
import SwiftUI

/// Single-selection list of the countries broadcast data has been seen for, plus an
/// "All countries" row. Follows `AppIconPickerView`'s layout.
struct BroadcastCountryPickerView: View {
    @Environment(BroadcastCountryStore.self) private var store
    @Environment(\.themeTokens) private var themeTokens
    @ScaledMetric private var rowTitleFontSize: CGFloat = 16
    @ScaledMetric private var checkmarkIconSize: CGFloat = 15

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                GlassCard(cornerRadius: 18, style: .transparent) {
                    VStack(spacing: 10) {
                        row(code: nil, title: String(localized: "All countries", comment: "Broadcast country picker option showing listings from every country."))
                        ForEach(sortedCountries, id: \.self) { code in
                            Rectangle()
                                .fill(Color.white.opacity(0.16))
                                .frame(height: 0.5)
                            row(code: code, title: displayName(for: code))
                        }
                    }
                }
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
        .background(StadiumBackground())
        .navigationTitle(Text("TV & Streaming", comment: "Title of the broadcast country picker screen and its row in More."))
        .navigationBarTitleDisplayMode(.inline)
        .trackScreen("BroadcastCountryPicker")
    }

    /// Sorted by the name the user actually reads, not by code — "Brasil" before
    /// "Portugal" in pt-BR, and correctly ordered in every other locale too.
    private var sortedCountries: [String] {
        store.knownCountries.sorted { displayName(for: $0) < displayName(for: $1) }
    }

    /// The system supplies the localized country name, so these need no catalog entries.
    private func displayName(for code: String) -> String {
        Locale.current.localizedString(forRegionCode: code) ?? code
    }

    private func row(code: String?, title: String) -> some View {
        Button {
            store.select(code)
        } label: {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: rowTitleFontSize, weight: .semibold))
                    .foregroundStyle(themeTokens.textColor)
                Spacer()
                if store.selectedCountry == code {
                    Image(systemName: "checkmark")
                        .font(.system(size: checkmarkIconSize, weight: .bold))
                        .foregroundStyle(themeTokens.overrideAccentColor ?? Color(hex: "ff4d5e"))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityAddTraits(store.selectedCountry == code ? [.isButton, .isSelected] : .isButton)
    }
}
```

- [ ] **Step 6: Wire the destination in `MoreView`**

Add to the `switch destination` block in `BR2026/Views/More/MoreView.swift`:

```swift
                case .broadcastCountryPicker:
                    BroadcastCountryPickerView()
```

Update `MoreView`'s construction of `MoreViewModel` to pass the store, reading it from the environment with `@Environment(BroadcastCountryStore.self) private var broadcastCountryStore`.

- [ ] **Step 7: Add the strings to the catalog**

Build once so Xcode extracts the new `String(localized:)` keys into `BR2026/Resources/Localizable.xcstrings`, then fill in every locale (`pt-BR`, `pt-PT`, `fr`, `en-US`, `en-GB`) for: `TV & Streaming`, `All countries`, `Available on %@`, `free to air`, `pay TV`, `streaming`, `pay per view`.

`Available on %@` must use `%@`. A `%lld`/`%@` mismatch between code and catalog silently breaks the string at runtime with no build error — that has happened in this catalog before.

**Never** run `git checkout`, `git restore` or `git stash` on this file. Stage it by exact path only.

- [ ] **Step 8: Run the tests to verify they pass**

Run the BR2026 test command. Expected: the 2 new `MoreViewModel` tests PASS, and the existing `MoreViewModel` tests still pass with the widened initializer.

- [ ] **Step 9: Commit**

```bash
cd /Users/mlbbr-mac-vinicius/projects/footballWhiteLabel
git add BR2026/Views/More/BroadcastCountryPickerView.swift BR2026/Models/MoreDestination.swift \
        BR2026/ViewModels/MoreViewModel.swift BR2026/Views/More/MoreView.swift \
        BR2026/Resources/Localizable.xcstrings BR2026Tests/ViewModels/MoreViewModelTests.swift \
        BR2026Tests/Services/BroadcastCountryStoreTests.swift BR2026.xcodeproj/project.pbxproj
git commit -m "Add the TV & Streaming country picker to More"
```

---

## Task 6: Feed discovered countries from the match loads

**Files:**
- Modify: `BR2026/ViewModels/MatchdayViewModel.swift:104-108`
- Modify: `BR2026/ViewModels/FixturesViewModel.swift:99-104`
- Modify: `BR2026/Views/Matchday/MatchdayView.swift`, `BR2026/Views/Fixtures/FixturesView.swift` (construction sites)
- Test: `BR2026Tests/ViewModels/MatchdayViewModelTests.swift`, `BR2026Tests/ViewModels/FixturesViewModelTests.swift` (extend)

**Interfaces:**
- Consumes: `BroadcastCountryStore.noteAvailability(in:)` (Task 3).
- Produces: both ViewModels accept an optional `broadcastCountryStore: BroadcastCountryStore?` parameter, defaulting to `nil` so existing tests compile unchanged.

- [ ] **Step 1: Write the failing tests**

Append to the existing suite in `BR2026Tests/ViewModels/MatchdayViewModelTests.swift`. `MatchdayViewModel` already requires a `themeStore`, and that file builds one from `StubTeamThemeSetting` — mirror that:

```swift
    @Test("Loading matches records the broadcast countries seen, so the settings row can appear")
    func loadRecordsCountriesFromCache() async {
        let store = BroadcastCountryStore(setting: StubBroadcastCountrySetting())
        let service = StubMatchService(matches: [matchWithBroadcasts(country: "BR")], standings: [])
        let themeStore = TeamThemeStore(setting: StubTeamThemeSetting(), service: service)
        let viewModel = MatchdayViewModel(
            service: service,
            themeStore: themeStore,
            broadcastCountryStore: store
        )

        await viewModel.load()

        #expect(store.knownCountries == ["BR"])
    }
```

Add a helper to that file that builds a `Match` carrying one listing:

```swift
    private func matchWithBroadcasts(country: String) -> Match {
        Match(
            id: 9001,
            utcDate: Date(),
            status: .scheduled,
            matchday: 1,
            stage: "REGULAR_SEASON",
            homeTeam: Team(id: 10, name: "Bahia", shortName: "Bahia", crestURL: nil),
            awayTeam: Team(id: 11, name: "Corinthians", shortName: "Corinthians", crestURL: nil),
            homeScore: nil,
            awayScore: nil,
            winner: nil,
            venue: nil,
            minute: nil,
            broadcasts: [Broadcast(name: "Globo", country: country, type: .freeTV, url: nil)]
        )
    }
```

Add the equivalent test and the same `matchWithBroadcasts` helper to `BR2026Tests/ViewModels/FixturesViewModelTests.swift`. `FixturesViewModel` takes no `themeStore`, so it is just `FixturesViewModel(service: service, broadcastCountryStore: store)`.

- [ ] **Step 2: Run the tests to verify they fail**

Run the BR2026 test command. Expected: FAIL — the ViewModel initializers take no `broadcastCountryStore`.

- [ ] **Step 3: Thread the store into `MatchdayViewModel`**

Add a stored property and widen the initializer:

```swift
    /// Optional so existing call sites and tests that do not care about broadcasts stay
    /// unchanged.
    private let broadcastCountryStore: BroadcastCountryStore?
```

Add `broadcastCountryStore: BroadcastCountryStore? = nil` as the last initializer parameter and assign it.

In `load()`, after **both** the cached read (line 104) and the fresh fetch (line 107), record availability:

```swift
        matches = service.cachedMatches()
        broadcastCountryStore?.noteAvailability(in: matches)
```

```swift
        if let fresh = try? await service.fetchMatches() {
            // ... existing assignment
            broadcastCountryStore?.noteAvailability(in: fresh)
        }
```

Both paths matter: a cold launch on cached data must populate the picker without waiting for the network.

- [ ] **Step 4: Thread the store into `FixturesViewModel`**

Apply the identical change at `BR2026/ViewModels/FixturesViewModel.swift:99` (cached) and `:103` (fresh).

- [ ] **Step 5: Pass the store at the construction sites**

Find them and add the argument:

```bash
cd /Users/mlbbr-mac-vinicius/projects/footballWhiteLabel
grep -rn "MatchdayViewModel(\|FixturesViewModel(" BR2026 --include='*.swift'
```

Each view reads `@Environment(BroadcastCountryStore.self) private var broadcastCountryStore` and passes it through.

- [ ] **Step 6: Run the tests to verify they pass**

Run the BR2026 test command. Expected: the 2 new ViewModel tests PASS and every pre-existing ViewModel test still passes (the new parameter defaults to `nil`).

- [ ] **Step 7: Commit**

```bash
cd /Users/mlbbr-mac-vinicius/projects/footballWhiteLabel
git add BR2026/ViewModels/MatchdayViewModel.swift BR2026/ViewModels/FixturesViewModel.swift \
        BR2026/Views/Matchday/MatchdayView.swift BR2026/Views/Fixtures/FixturesView.swift \
        BR2026Tests/ViewModels/MatchdayViewModelTests.swift BR2026Tests/ViewModels/FixturesViewModelTests.swift
git commit -m "Record broadcast countries from Matchday and Fixtures loads"
```

- [ ] **Step 8: Verify the SwiftData migration on a device or simulator**

BR2026 is live in the App Store with real installs, so the store-upgrade path must be exercised rather than assumed.

1. `git stash` is forbidden here — instead, check out the previous release tag into a **separate** clone or worktree, build it to a simulator, and let it populate its store.
2. Build this branch to the *same* simulator without deleting the app.
3. Confirm it launches, shows the previously cached matches, and does not crash.

Expected: launch succeeds and matches render. A `SwiftData` migration error at launch means the defaulted property was not treated as lightweight and the plan needs revisiting before release.

---

# Part 2 — Fixture 2026 (`/Users/mlbbr-mac-vinicius/projects/worldcup`)

Part 2 mirrors Part 1's behaviour but not its code: Fixture 2026's `Match` is a plain struct with no SwiftData, its localization uses short dotted keys, its cards use literal `.white` rather than theme tokens, and its settings screen is a sheet rather than a `NavigationStack` destination. Do not copy Part 1's files across; write each to this app's conventions.

## Task 7: The `Broadcast` model in Fixture 2026

**Files:**
- Create: `Fixture2026App/Models/Broadcast.swift`
- Create: `Fixture2026App/Services/DTOs/APIBroadcast.swift`
- Test: `Fixture2026AppTests/Models/BroadcastTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `struct Broadcast: Codable, Sendable, Hashable` (`name`, `country`, `type`, `url`); `enum BroadcastType` with `sortRank` and `init(apiValue:)`; `struct APIBroadcast: Codable`; `Broadcast.init?(api:)`; `Broadcast.list(from: [APIBroadcast]?) -> [Broadcast]`.

- [ ] **Step 1: Write the failing tests**

Create `Fixture2026AppTests/Models/BroadcastTests.swift` with the same eleven cases as Task 1 Step 1, changing `@testable import BR2026` to `@testable import Fixture2026`, `BroadcastDTO` to `APIBroadcast`, and the decode helper to:

```swift
    private func decode(_ json: String) -> [Broadcast] {
        let apis = try? JSONDecoder().decode([APIBroadcast].self, from: Data(json.utf8))
        return Broadcast.list(from: apis)
    }
```

Verify the module name first — the test target's existing files use it at the top of `Fixture2026AppTests/WorldCup26Tests.swift`; match whatever that file imports.

- [ ] **Step 2: Run the tests to verify they fail**

Run the Fixture 2026 test command. Expected: `cannot find 'Broadcast' in scope`.

- [ ] **Step 3: Write `Broadcast.swift`**

Identical body to Task 1 Step 3.

- [ ] **Step 4: Write `APIBroadcast.swift`**

Identical to Task 1 Step 4, with the type renamed and `Codable` rather than `Decodable` to match the sibling DTOs in that folder:

```swift
import Foundation

/// The wire shape. Every field is optional because the endpoint is undocumented and
/// unvalidated upstream — a surprise here must cost one listing, never the whole match.
struct APIBroadcast: Codable {
    let name: String?
    let type: String?
    let country: String?
    let url: String?
}

extension Broadcast {
    init?(api: APIBroadcast) {
        guard let name = api.name, !name.isEmpty else { return nil }
        guard let country = api.country,
              country.count == 2,
              country.allSatisfy({ $0.isASCII && $0.isLetter })
        else { return nil }

        self.init(
            name: name,
            country: country.uppercased(),
            type: BroadcastType(apiValue: api.type),
            url: api.url.flatMap(URL.init(string:))
        )
    }

    static func list(from apis: [APIBroadcast]?) -> [Broadcast] {
        (apis ?? [])
            .compactMap(Broadcast.init(api:))
            .sorted { ($0.type.sortRank, $0.name) < ($1.type.sortRank, $1.name) }
    }
}
```

- [ ] **Step 5: Add both files to the `Fixture2026` target**

```bash
cd /Users/mlbbr-mac-vinicius/projects/worldcup
grep -c "Broadcast.swift\|APIBroadcast.swift" Fixture2026.xcodeproj/project.pbxproj
```

Expected: non-zero.

- [ ] **Step 6: Run the tests to verify they pass**

Run the Fixture 2026 test command. Expected: all 11 PASS.

- [ ] **Step 7: Commit**

```bash
cd /Users/mlbbr-mac-vinicius/projects/worldcup
git add Fixture2026App/Models/Broadcast.swift Fixture2026App/Services/DTOs/APIBroadcast.swift \
        Fixture2026AppTests/Models/BroadcastTests.swift Fixture2026.xcodeproj/project.pbxproj
git commit -m "Add Broadcast model with defensive decoding"
```

---

## Task 8: Carry broadcasts on Fixture 2026's `Match`

**Files:**
- Modify: `Fixture2026App/Models/Match.swift:11-22`
- Modify: `Fixture2026App/Services/DTOs/APIMatch.swift:5-17`
- Modify: `Fixture2026App/Services/MatchMapper.swift:93-104` and `:450`
- Modify: `Fixture2026App/Services/LeagueMatchService.swift:18,26,33`
- Test: `Fixture2026AppTests/Services/LeagueMatchMapperTests.swift` (extend)

**Interfaces:**
- Consumes: `Broadcast`, `Broadcast.list(from:)`, `APIBroadcast` (Task 7).
- Produces: `Match.broadcasts: [Broadcast]` (non-optional stored property, explicitly supplied at both construction sites) and `Match.broadcasts(for country: String?) -> [Broadcast]`.

- [ ] **Step 1: Write the failing tests**

Append to `Fixture2026AppTests/Services/LeagueMatchMapperTests.swift`, following that file's existing fixture style:

```swift
    /// `APIScore` has six stored properties, so its memberwise initializer needs all of
    /// them — `duration`, `extraTime` and `penalties` are not optional-with-default.
    private func emptyScore() -> APIScore {
        APIScore(
            winner: nil,
            duration: "REGULAR",
            fullTime: APIGoals(home: nil, away: nil),
            halfTime: APIGoals(home: nil, away: nil),
            extraTime: nil,
            penalties: nil
        )
    }

    private func apiMatch(id: Int, broadcasts: [APIBroadcast]?) -> APIMatch {
        APIMatch(
            id: id,
            utcDate: "2026-07-27T20:00:00Z",
            status: "SCHEDULED",
            matchday: 1,
            stage: "REGULAR_SEASON",
            group: nil,
            homeTeam: APITeam(id: 10, name: "Bahia", shortName: "Bahia", tla: "BAH", crest: nil),
            awayTeam: APITeam(id: 11, name: "Corinthians", shortName: "Corinthians", tla: "COR", crest: nil),
            score: emptyScore(),
            venue: nil,
            minute: nil,
            broadcasts: broadcasts
        )
    }

    @Test("A match with no broadcasts key maps to an empty list")
    func absentBroadcastsMapsEmpty() throws {
        let match = try #require(MatchMapper.map(apiMatch(id: 1, broadcasts: nil), clubTeams: true))

        #expect(match.broadcasts.isEmpty)
    }

    @Test("Broadcasts map onto the match, sorted free-to-air first")
    func broadcastsMapSorted() throws {
        let api = apiMatch(id: 2, broadcasts: [
            APIBroadcast(name: "Premiere", type: "PPV", country: "BR", url: nil),
            APIBroadcast(name: "Globo", type: "FREE_TV", country: "BR", url: nil),
            APIBroadcast(name: "Canal 11", type: "PAY_TV", country: "PT", url: nil)
        ])

        let match = try #require(MatchMapper.map(api, clubTeams: true))

        #expect(match.broadcasts.map(\.name) == ["Globo", "Canal 11", "Premiere"])
        #expect(match.broadcasts(for: "PT").map(\.name) == ["Canal 11"])
        #expect(match.broadcasts(for: nil).count == 3)
        #expect(match.broadcasts(for: "GB").isEmpty)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the Fixture 2026 test command. Expected: FAIL — `APIMatch` has no `broadcasts` parameter.

- [ ] **Step 3: Add the field to `APIMatch`**

In `Fixture2026App/Services/DTOs/APIMatch.swift`, add to `struct APIMatch` after `minute`:

```swift
    let broadcasts: [APIBroadcast]?
```

- [ ] **Step 4: Add the property to `Match` and both construction sites**

In `Fixture2026App/Models/Match.swift`, add to `struct Match` after `venue`:

```swift
    let broadcasts: [Broadcast]
```

No default: the memberwise initializer must force both construction sites to say what they mean, so a future third one cannot silently ship empty.

Add at the end of the file:

```swift
extension Match {
    /// Listings for the user's selected country, or every listing when none is selected.
    /// Strict: a match with nothing in the selected country returns empty rather than
    /// falling back, so the chips never advertise a channel the user cannot get.
    func broadcasts(for country: String?) -> [Broadcast] {
        guard let country else { return broadcasts }
        return broadcasts.filter { $0.country == country }
    }
}
```

In `Fixture2026App/Services/MatchMapper.swift`, add to the `Match(` construction at line 93, after `venue: api.venue`:

```swift
            broadcasts: Broadcast.list(from: api.broadcasts)
```

and to `mapBracketMatch`'s `Match(` construction at line 450:

```swift
            broadcasts: []
```

with the comment `// World Cup knockout fixtures have no listings — that backend does not return them.`

- [ ] **Step 5: Request the field in `LeagueMatchService`**

`fetch(path:query:)` already takes a `[String: String]`. Add `include` to all three `competitions/{code}/matches` calls:

```swift
    func fetchMatches() async throws -> [Match] {
        // `include=broadcasts` is undocumented and unvalidated upstream — a typo returns
        // 200 with the key simply absent, so a mistake here goes silently dead rather
        // than erroring. It is the only way the matches payload carries listings.
        guard let data = try? await fetch(path: "competitions/\(competition.code)/matches",
                                          query: ["include": "broadcasts"]) else { return [] }
        return (try? JSONDecoder().decode(APIMatchesResponse.self, from: data))
            .map { MatchMapper.map($0, clubTeams: true) } ?? []
    }
```

and add `"include": "broadcasts"` to the existing query dictionaries in `fetchLiveMatches()` (`["status": "LIVE", "include": "broadcasts"]`) and `fetchMatches(matchday:)` (`["matchday": String(matchday), "include": "broadcasts"]`).

Do **not** add it to `Fixture2026App/Services/LiveMatchService.swift` — that is the World Cup backend and returns no listings.

- [ ] **Step 6: Run the tests to verify they pass**

Run the Fixture 2026 test command. Expected: the 2 new mapper tests PASS, and every other `Match(...)` construction in the app and tests compiles — the non-defaulted property will surface any that were missed as build errors. Fix each by supplying `broadcasts: []`.

- [ ] **Step 7: Commit**

```bash
cd /Users/mlbbr-mac-vinicius/projects/worldcup
git add Fixture2026App/Models/Match.swift Fixture2026App/Services/DTOs/APIMatch.swift \
        Fixture2026App/Services/MatchMapper.swift Fixture2026App/Services/LeagueMatchService.swift \
        Fixture2026AppTests/Services/LeagueMatchMapperTests.swift
git commit -m "Carry broadcast listings on Match and request them for leagues"
```

---

## Task 9: The country setting and store in Fixture 2026

**Files:**
- Create: `Fixture2026App/Services/BroadcastCountrySetting.swift`
- Create: `Fixture2026App/Services/BroadcastCountryStore.swift`
- Test: `Fixture2026AppTests/Services/BroadcastCountryStoreTests.swift`

**Interfaces:**
- Consumes: `Match.broadcasts` (Task 8).
- Produces: `protocol BroadcastCountrySetting` with `var storedCountry: String? { get set }` and `var knownCountries: [String] { get set }`; `final class BroadcastCountryStore` with `private(set) var selectedCountry: String?`, `private(set) var knownCountries: [String]`, `var isAvailable: Bool`, `func select(_:)`, `func noteAvailability(in matches: [Match])`.

- [ ] **Step 1: Write the failing tests**

Create `Fixture2026AppTests/Services/BroadcastCountryStoreTests.swift` with the same seven cases as Task 3 Step 1, adapted to this app: `@testable import Fixture2026`, and these helpers (note that this app's `Team` takes `countryCode:`/`flagURL:`, not `crestURL:`):

```swift
    private func team(_ id: Int, _ name: String) -> Team {
        Team(id: id, name: name, shortName: name, countryCode: "xx", flagURL: nil)
    }

    private func match(id: Int, broadcasts: [Broadcast]) -> Match {
        Match(id: id, date: Date(timeIntervalSince1970: 0), status: .scheduled,
              stage: .groupStage, group: nil, matchday: 1,
              homeTeam: team(id, "H\(id)"), awayTeam: team(100 + id, "A\(id)"),
              score: Score(winner: nil, fullTime: .init(home: nil, away: nil),
                           halfTime: .init(home: nil, away: nil), penaltyWinner: nil),
              venue: nil, broadcasts: broadcasts)
    }

    private func listing(_ name: String, _ country: String) -> Broadcast {
        Broadcast(name: name, country: country, type: .freeTV, url: nil)
    }
```

The stub is written against this app's `get set` property style. Declare it non-`private` — Task 12's ViewModel test uses it too:

```swift
final class StubBroadcastCountrySetting: BroadcastCountrySetting {
    var storedCountry: String?
    var knownCountries: [String]

    init(storedCountry: String? = nil, knownCountries: [String] = []) {
        self.storedCountry = storedCountry
        self.knownCountries = knownCountries
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the Fixture 2026 test command. Expected: `cannot find 'BroadcastCountryStore' in scope`.

- [ ] **Step 3: Write `BroadcastCountrySetting.swift`**

Following `ThemeSetting`'s house style in this app (`get set` properties with a `nonmutating set`, not setter methods):

```swift
import Foundation

/// Persistence for the broadcast country preference, abstracted so
/// `BroadcastCountryStore` can be unit-tested without touching real `UserDefaults`.
protocol BroadcastCountrySetting {
    /// nil means "All countries" — the default.
    var storedCountry: String? { get set }
    /// Every country code seen in match data so far, sorted.
    var knownCountries: [String] { get set }
}

struct UserDefaultsBroadcastCountrySetting: BroadcastCountrySetting {
    private let countryKey = "selectedBroadcastCountry"
    private let knownKey = "knownBroadcastCountries"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var storedCountry: String? {
        get { defaults.string(forKey: countryKey) }
        nonmutating set {
            if let newValue {
                defaults.set(newValue, forKey: countryKey)
            } else {
                defaults.removeObject(forKey: countryKey)
            }
        }
    }

    var knownCountries: [String] {
        get { defaults.stringArray(forKey: knownKey) ?? [] }
        nonmutating set { defaults.set(newValue, forKey: knownKey) }
    }
}
```

- [ ] **Step 4: Write `BroadcastCountryStore.swift`**

Same behaviour and same doc comments as Task 3 Step 4, written against this app's setting shape:

```swift
import Foundation
import Observation

/// Owns which country's broadcast listings the user wants to see, and which countries
/// there are to choose from.
///
/// The available set is discovered from match data rather than hardcoded: only
/// Brasileirão carries listings today, so a hardcoded picker would be empty in Liga
/// Portugal, the Scottish Premiership and the World Cup. Discovering it means the row
/// appears by itself the first time a refresh returns a listing.
@Observable
@MainActor
final class BroadcastCountryStore {
    /// nil means "All countries".
    private(set) var selectedCountry: String?
    private(set) var knownCountries: [String]

    private var setting: BroadcastCountrySetting

    init(setting: BroadcastCountrySetting = UserDefaultsBroadcastCountrySetting()) {
        self.setting = setting
        selectedCountry = setting.storedCountry
        knownCountries = setting.knownCountries
    }

    /// False until match data has produced at least one country. The settings row is
    /// hidden entirely while this is false — a picker offering only "All countries"
    /// reads as broken.
    var isAvailable: Bool { !knownCountries.isEmpty }

    func select(_ code: String?) {
        guard code != selectedCountry else { return }
        selectedCountry = code
        setting.storedCountry = code
    }

    /// Unions the countries present in `matches` into the known set. Union rather than
    /// replace, so a round with only Brazilian listings cannot make a previously-seen
    /// Portugal unselectable and invalidate a saved choice.
    func noteAvailability(in matches: [Match]) {
        let seen = Set(matches.flatMap(\.broadcasts).map(\.country))
        guard !seen.isEmpty else { return }
        let merged = Set(knownCountries).union(seen).sorted()
        guard merged != knownCountries else { return }
        knownCountries = merged
        setting.knownCountries = merged
    }
}
```

- [ ] **Step 5: Add both files to the `Fixture2026` target**

```bash
cd /Users/mlbbr-mac-vinicius/projects/worldcup
grep -c "BroadcastCountrySetting.swift\|BroadcastCountryStore.swift" Fixture2026.xcodeproj/project.pbxproj
```

Expected: non-zero.

- [ ] **Step 6: Run the tests to verify they pass**

Run the Fixture 2026 test command. Expected: the 7 store tests PASS.

- [ ] **Step 7: Commit**

```bash
cd /Users/mlbbr-mac-vinicius/projects/worldcup
git add Fixture2026App/Services/BroadcastCountrySetting.swift \
        Fixture2026App/Services/BroadcastCountryStore.swift \
        Fixture2026AppTests/Services/BroadcastCountryStoreTests.swift Fixture2026.xcodeproj/project.pbxproj
git commit -m "Add broadcast country store with discovered availability"
```

---

## Task 10: The chips row on Fixture 2026's match cards

**Files:**
- Create: `Fixture2026App/Components/BroadcastChips.swift`
- Modify: `Fixture2026App/Components/MatchCard.swift:13-39`
- Modify: `Fixture2026App/Components/HeroMatchCard.swift`
- Modify: `Fixture2026App/Fixture2026App.swift:9,19`
- Test: `Fixture2026AppTests/Models/AccessibilityLabelTests.swift` (extend)

**Interfaces:**
- Consumes: `Broadcast`, `BroadcastType` (Task 7); `Match.broadcasts(for:)` (Task 8); `BroadcastCountryStore` (Task 9).
- Produces: `struct BroadcastChips: View` with `init(listings:showsCountry:)`; `Broadcast.accessibilityPhrase(for:) -> String?`; `BroadcastType.accessibilityName: String?`.

- [ ] **Step 1: Write the failing tests**

Append the three cases from Task 4 Step 1 to `Fixture2026AppTests/Models/AccessibilityLabelTests.swift`, changing the import to `@testable import Fixture2026` and matching that file's existing suite structure.

- [ ] **Step 2: Run the tests to verify they fail**

Run the Fixture 2026 test command. Expected: `type 'Broadcast' has no member 'accessibilityPhrase'`.

- [ ] **Step 3: Write `BroadcastChips.swift`**

Same structure as Task 4 Step 3, with two differences for this app: colours are literal `.white` rather than `themeTokens.textColor`, and strings use dotted keys.

```swift
import SwiftUI

/// The "how to watch" row on a match card: one chip per listing, free-to-air first and
/// tinted teal so the cheapest way to watch reads at a glance.
///
/// Renders nothing when there are no listings. Coverage is around 12% of matches and
/// hand-entered, so a "not confirmed yet" placeholder would be the loudest thing on the
/// screen — absence is quieter, and just as honest.
struct BroadcastChips: View {
    let listings: [Broadcast]
    /// True when the user is seeing every country at once, where a bare "Canal 11" is
    /// meaningless to a viewer in Brazil.
    let showsCountry: Bool

    @ScaledMetric private var iconSize: CGFloat = 11
    @ScaledMetric private var chipFontSize: CGFloat = 11
    @ScaledMetric private var countryFontSize: CGFloat = 9

    private static let freeToAirColor = Color(hex: "2dd4bf")

    var body: some View {
        if !listings.isEmpty {
            HStack(alignment: .center, spacing: 7) {
                Image(systemName: "tv")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) { chips }
                    VStack(alignment: .leading, spacing: 6) { chips }
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var chips: some View {
        ForEach(listings, id: \.self) { listing in
            chip(for: listing)
        }
    }

    private func chip(for listing: Broadcast) -> some View {
        let isFree = listing.type == .freeTV
        let tint: Color = isFree ? Self.freeToAirColor : .white

        return HStack(spacing: 4) {
            Text(listing.name)
                .font(.system(size: chipFontSize, weight: .bold))
                .lineLimit(1)
            if showsCountry {
                Text(listing.country)
                    .font(.system(size: countryFontSize, weight: .heavy))
                    .kerning(0.6)
                    .opacity(0.6)
            }
        }
        .foregroundStyle(isFree ? tint : tint.opacity(0.82))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(tint.opacity(isFree ? 0.18 : 0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(tint.opacity(isFree ? 0.45 : 0.14), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

extension Broadcast {
    /// The VoiceOver sentence appended to a match card's label, or nil when there is
    /// nothing to say. Each listing is spoken with its type, so the free-to-air
    /// distinction never rests on colour alone.
    static func accessibilityPhrase(for listings: [Broadcast]) -> String? {
        guard !listings.isEmpty else { return nil }
        let parts = listings.map { listing -> String in
            guard let typeName = listing.type.accessibilityName else { return listing.name }
            return "\(listing.name), \(typeName)"
        }
        return String(format: String(localized: "accessibility.broadcast %@"), parts.joined(separator: "; "))
    }
}

extension BroadcastType {
    /// nil for `.other` — there is no honest name for a category we do not recognise.
    var accessibilityName: String? {
        switch self {
        case .freeTV: return String(localized: "broadcast.type.free")
        case .payTV: return String(localized: "broadcast.type.paytv")
        case .streaming: return String(localized: "broadcast.type.streaming")
        case .ppv: return String(localized: "broadcast.type.ppv")
        case .other: return nil
        }
    }
}
```

- [ ] **Step 4: Inject the store app-wide**

In `Fixture2026App/Fixture2026App.swift`, add next to `@State private var themeStore` (line 9):

```swift
    @State private var broadcastCountryStore = BroadcastCountryStore()
```

and next to `.environment(themeStore)` (line 19):

```swift
                .environment(broadcastCountryStore)
```

Every `#Preview` that constructs `MatchCard`, `HeroMatchCard` or a screen containing them must add `.environment(BroadcastCountryStore())` — an `@Environment(BroadcastCountryStore.self)` read with nothing injected traps at runtime.

- [ ] **Step 5: Add the chips to `MatchCard`**

In `Fixture2026App/Components/MatchCard.swift`, add:

```swift
    @Environment(BroadcastCountryStore.self) private var broadcastCountryStore

    private var listings: [Broadcast] {
        match.broadcasts(for: broadcastCountryStore.selectedCountry)
    }

    /// The card's own label plus the listings, as one combined element — the card is
    /// `.accessibilityElement(children: .combine)`, so the chips must not become a
    /// separate stop in the VoiceOver order.
    private var combinedAccessibilityLabel: String {
        guard let phrase = Broadcast.accessibilityPhrase(for: listings) else {
            return match.accessibilityLabel
        }
        return "\(match.accessibilityLabel). \(phrase)"
    }
```

In `body`, after the away `teamRow` and before `.padding(.bottom, 16)`, add:

```swift
            if !listings.isEmpty {
                Rectangle()
                    .fill(.white.opacity(0.10))
                    .frame(height: 0.5)
                BroadcastChips(
                    listings: listings,
                    showsCountry: broadcastCountryStore.selectedCountry == nil
                )
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
```

The `.padding(.horizontal, 16)` matters: this card's rows carry their own horizontal inset rather than inheriting one from a container, and omitting it is exactly the overflow that made Statistics and Lineups render too wide.

Replace `.accessibilityLabel(match.accessibilityLabel)` with `.accessibilityLabel(combinedAccessibilityLabel)`.

- [ ] **Step 6: Add the chips to `HeroMatchCard`**

Add the same three members from Step 5. This card's outer `VStack(spacing: 20)` already carries `.padding(.horizontal, 20)`, so the chips need no inset of their own — adding one would indent them past the venue line.

Insert as the last element of that `VStack`, after the `if let venue = match.venue { ... }` block:

```swift
            if !listings.isEmpty {
                BroadcastChips(
                    listings: listings,
                    showsCountry: broadcastCountryStore.selectedCountry == nil
                )
                .frame(maxWidth: .infinity, alignment: .center)
            }
```

Then swap the card's `.accessibilityLabel(...)` to `combinedAccessibilityLabel`.

- [ ] **Step 7: Run the tests to verify they pass**

Run the Fixture 2026 test command. Expected: the 3 accessibility tests PASS and the app compiles.

- [ ] **Step 8: Commit**

```bash
cd /Users/mlbbr-mac-vinicius/projects/worldcup
git add Fixture2026App/Components/BroadcastChips.swift Fixture2026App/Components/MatchCard.swift \
        Fixture2026App/Components/HeroMatchCard.swift Fixture2026App/Fixture2026App.swift \
        Fixture2026AppTests/Models/AccessibilityLabelTests.swift Fixture2026.xcodeproj/project.pbxproj
git commit -m "Show broadcast chips on Fixture 2026 match cards"
```

---

## Task 11: The settings row and picker in Fixture 2026

**Files:**
- Create: `Fixture2026App/Views/Settings/BroadcastCountryPickerView.swift`
- Modify: `Fixture2026App/Views/Settings/SettingsView.swift:61-71`
- Modify: the app's string catalog (`Fixture2026App/Resources/Localizable.xcstrings` — confirm the path with `find . -name 'Localizable.xcstrings'`)
- Test: none — this task is View-only, and Views are not unit-tested. Its correctness rests on Task 9's store tests.

**Interfaces:**
- Consumes: `BroadcastCountryStore` (Task 9).
- Produces: `struct BroadcastCountryPickerView: View`.

- [ ] **Step 1: Write `BroadcastCountryPickerView.swift`**

```swift
import SwiftUI

/// Single-selection list of the countries broadcast data has been seen for, plus an
/// "All countries" row. Follows `ThemePickerView`'s layout.
struct BroadcastCountryPickerView: View {
    @Environment(BroadcastCountryStore.self) private var store

    @ScaledMetric private var rowTitleSize: CGFloat = 16
    @ScaledMetric private var checkmarkSize: CGFloat = 15

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                row(code: nil, title: String(localized: "broadcast.all"))
                ForEach(sortedCountries, id: \.self) { code in
                    Divider().overlay(.white.opacity(0.16))
                    row(code: code, title: displayName(for: code))
                }
            }
            .background(.white.opacity(0.07))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(.white.opacity(0.16), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .padding(16)
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle(Text("settings.broadcast"))
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }

    /// Sorted by the name the user actually reads, not by code.
    private var sortedCountries: [String] {
        store.knownCountries.sorted { displayName(for: $0) < displayName(for: $1) }
    }

    /// The system supplies the localized country name, so these need no catalog entries.
    private func displayName(for code: String) -> String {
        Locale.current.localizedString(forRegionCode: code) ?? code
    }

    private func row(code: String?, title: String) -> some View {
        Button {
            store.select(code)
        } label: {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: rowTitleSize, weight: .semibold))
                Spacer()
                if store.selectedCountry == code {
                    Image(systemName: "checkmark")
                        .font(.system(size: checkmarkSize, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityAddTraits(store.selectedCountry == code ? [.isButton, .isSelected] : .isButton)
    }
}
```

- [ ] **Step 2: Add the conditional row to `SettingsView`**

Add to `SettingsView`:

```swift
    @Environment(BroadcastCountryStore.self) private var broadcastCountryStore
```

and replace `preferencesSection` with:

```swift
    private var preferencesSection: some View {
        section(titleKey: "settings.preferences") {
            navRow(titleKey: "settings.appicon", systemImage: "app.badge") {
                AppIconPickerView()
            }
            Divider().overlay(.white.opacity(0.16))
            navRow(titleKey: "settings.theme", systemImage: "paintpalette") {
                ThemePickerView()
            }
            // Only rendered once match data has produced a country. Liga Portugal, the
            // Scottish Premiership and the World Cup have no listings at all, and a picker
            // whose only entry is "All countries" reads as broken.
            if broadcastCountryStore.isAvailable {
                Divider().overlay(.white.opacity(0.16))
                navRow(titleKey: "settings.broadcast", systemImage: "tv") {
                    BroadcastCountryPickerView()
                }
            }
        }
    }
```

- [ ] **Step 3: Add the strings to the catalog**

Add these keys, filled for `pt-BR`, `pt-PT`, `fr`, `en-US` and `en-GB`:

| Key | en-US |
|---|---|
| `settings.broadcast` | TV & Streaming |
| `broadcast.all` | All countries |
| `accessibility.broadcast %@` | Available on %@ |
| `broadcast.type.free` | free to air |
| `broadcast.type.paytv` | pay TV |
| `broadcast.type.streaming` | streaming |
| `broadcast.type.ppv` | pay per view |

`accessibility.broadcast %@` must use `%@`, not `%lld` — it is consumed through `String(format:)` with a pre-joined `String`.

**Never** run `git checkout`, `git restore` or `git stash` on this file.

- [ ] **Step 4: Add the picker file to the `Fixture2026` target and build**

```bash
cd /Users/mlbbr-mac-vinicius/projects/worldcup
grep -c "BroadcastCountryPickerView.swift" Fixture2026.xcodeproj/project.pbxproj
```

Expected: non-zero. Then run the Fixture 2026 test command; expected: builds clean, all suites still pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/mlbbr-mac-vinicius/projects/worldcup
git add Fixture2026App/Views/Settings/BroadcastCountryPickerView.swift \
        Fixture2026App/Views/Settings/SettingsView.swift Fixture2026.xcodeproj/project.pbxproj
git add "$(find . -name 'Localizable.xcstrings' -not -path './.git/*' | head -1)"
git commit -m "Add the TV & Streaming country picker to Settings"
```

---

## Task 12: Feed discovered countries from Fixture 2026's match loads

**Files:**
- Modify: `Fixture2026App/ViewModels/LeagueTodayViewModel.swift:46-52`
- Modify: `Fixture2026App/ViewModels/FixturesViewModel.swift:91-115`
- Modify: `Fixture2026App/Views/Today/TodayView.swift:120-122`, `Fixture2026App/Views/Fixtures/FixturesView.swift`
- Test: `Fixture2026AppTests/ViewModels/LeagueTodayViewModelTests.swift` (extend)

**Interfaces:**
- Consumes: `BroadcastCountryStore.noteAvailability(in:)` (Task 9).
- Produces: `LeagueTodayViewModel.load(service:broadcastCountryStore:)` and `FixturesViewModel.load(service:broadcastCountryStore:)`, both with `broadcastCountryStore: BroadcastCountryStore? = nil`.

These ViewModels take the service as a `load(service:)` parameter rather than an initializer dependency, so the store rides along the same way.

- [ ] **Step 1: Write the failing test**

Append to `Fixture2026AppTests/ViewModels/LeagueTodayViewModelTests.swift`, following that file's existing mock-service style:

This file currently tests only static functions and has no stub service, and the app's own `MockMatchService` reads bundled World Cup JSON that carries no listings. So the stub is written here.

`MatchService` is `Sendable`, so use a struct. Append to `Fixture2026AppTests/ViewModels/LeagueTodayViewModelTests.swift`:

```swift
private struct BroadcastStubService: MatchService {
    let matches: [Match]

    func fetchMatches() async throws -> [Match] { matches }
    func fetchMatchesFromAPI() async throws -> [Match] { matches }
    func fetchLiveMatches() async throws -> [Match] { [] }
    func fetchMatches(matchday: Int) async throws -> [Match] { matches }
    func fetchStandings() async throws -> [StandingGroup] { [] }
    func fetchStandingsFromAPI() async throws -> [StandingGroup] { [] }
    func fetchMatch(id: Int) async throws -> Match? { matches.first { $0.id == id } }
    func fetchMatchEvents(id: Int) async throws -> [MatchEvent] { [] }
    func fetchMatchStatistics(id: Int) async throws -> MatchStatistics? { nil }
    func fetchMatchLineups(id: Int) async throws -> MatchLineup? { nil }
    func fetchBracket() async throws -> [Match] { [] }
}
```

and this test inside the existing `LeagueTodayViewModelTests` struct, reusing its `match(_:_:_:)` helper (which now needs `broadcasts:` supplied — see Step 1a):

```swift
    @Test("Loading records the broadcast countries seen, so the settings row can appear")
    func loadRecordsCountries() async {
        let store = BroadcastCountryStore(setting: StubBroadcastCountrySetting())
        let service = BroadcastStubService(matches: [
            match(1, Date(), .scheduled, broadcasts: [
                Broadcast(name: "Globo", country: "BR", type: .freeTV, url: nil)
            ])
        ])
        let viewModel = LeagueTodayViewModel()

        await viewModel.load(service: service, broadcastCountryStore: store)

        #expect(store.knownCountries == ["BR"])
    }
```

- [ ] **Step 1a: Extend that file's `match` helper to take broadcasts**

Task 8 made `Match.broadcasts` non-optional, so this file's existing helper will already be failing to compile. Give it a defaulted parameter so the file's other tests stay unchanged:

```swift
    private func match(
        _ id: Int,
        _ date: Date,
        _ status: MatchStatus,
        broadcasts: [Broadcast] = []
    ) -> Match {
        Match(id: id, date: date, status: status, stage: .groupStage, group: nil, matchday: 1,
              homeTeam: team(id, "H\(id)"), awayTeam: team(100 + id, "A\(id)"),
              score: Score(winner: nil, fullTime: .init(home: nil, away: nil),
                           halfTime: .init(home: nil, away: nil), penaltyWinner: nil),
              venue: nil, broadcasts: broadcasts)
    }
```

`StubBroadcastCountrySetting` is already declared non-`private` in `BroadcastCountryStoreTests.swift` (Task 9), so it needs no change — just use it.

- [ ] **Step 2: Run the test to verify it fails**

Run the Fixture 2026 test command. Expected: FAIL — `load(service:)` takes no `broadcastCountryStore`.

- [ ] **Step 3: Widen `LeagueTodayViewModel.load`**

```swift
    func load(service: any MatchService, broadcastCountryStore: BroadcastCountryStore? = nil) async {
```

and after the `let all = try await service.fetchMatches()` line, add:

```swift
            broadcastCountryStore?.noteAvailability(in: all)
```

- [ ] **Step 4: Widen `FixturesViewModel.load`**

Apply the same change at `Fixture2026App/ViewModels/FixturesViewModel.swift:91`, adding `broadcastCountryStore?.noteAvailability(in: all)` after **both** `fetchMatches()` calls (lines 94 and 112).

- [ ] **Step 5: Pass the store at the call sites**

In `Fixture2026App/Views/Today/TodayView.swift`, `LeagueTodayContent` already has `@Environment(ServiceContainer.self)`. Add:

```swift
    @Environment(BroadcastCountryStore.self) private var broadcastCountryStore
```

and change its `.task`:

```swift
        .task {
            await viewModel.load(service: services.service(for: competition), broadcastCountryStore: broadcastCountryStore)
        }
```

Apply the same in `Fixture2026App/Views/Fixtures/FixturesView.swift`. Find every call site with:

```bash
cd /Users/mlbbr-mac-vinicius/projects/worldcup
grep -rn "viewModel.load(service:" Fixture2026App --include='*.swift'
```

`TournamentTodayContent` uses `FinalViewModel` against the World Cup backend, which has no listings — leave it unchanged.

- [ ] **Step 6: Run the tests to verify they pass**

Run the Fixture 2026 test command. Expected: the new test PASSES and every pre-existing ViewModel test still passes (the new parameter defaults to `nil`).

- [ ] **Step 7: Commit**

```bash
cd /Users/mlbbr-mac-vinicius/projects/worldcup
git add Fixture2026App/ViewModels/LeagueTodayViewModel.swift \
        Fixture2026App/ViewModels/FixturesViewModel.swift \
        Fixture2026App/Views/Today/TodayView.swift Fixture2026App/Views/Fixtures/FixturesView.swift \
        Fixture2026AppTests/ViewModels/LeagueTodayViewModelTests.swift \
        Fixture2026AppTests/Services/BroadcastCountryStoreTests.swift
git commit -m "Record broadcast countries from Fixture 2026 match loads"
```

---

## Final verification

- [ ] **Both suites green.** Run both test commands from Global Constraints. `CrestSyncTests` must pass unchanged in both repos — nothing in this plan touches a synced crest file.

- [ ] **The empty case renders correctly.** Build a sibling target that has no broadcast data — `ScottishPremiership2026` or `PrimeiraLiga2026` — and confirm: no chips on any card, and **no** "TV & Streaming" row in More. This is the launch state for five of six targets and the most likely thing to be wrong.

- [ ] **The populated case renders correctly.** Build `BR2026` against the live API (requires a real key in `Secrets.xcconfig`) and confirm chips appear on the ~45 matches that have listings, free-to-air tinted teal and first, with country codes shown under "All countries" and hidden once a country is picked.

- [ ] **VoiceOver reads the type.** Turn on VoiceOver, focus a card with a free-to-air listing, and confirm the type is spoken — the free-to-air distinction must not rest on colour.

- [ ] **Dynamic Type.** Set the largest supported size (`.accessibility1`) and confirm chips wrap rather than clip or overflow the card on both the list card and the hero.
