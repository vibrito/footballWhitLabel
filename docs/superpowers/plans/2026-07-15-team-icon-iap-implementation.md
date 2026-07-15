# Team Icon In-App Purchases Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the 20 team-specific alternate app icons in `design/BR2026/` as purchasable
options in the App Icon picker, each a separate $0.99 non-consumable IAP from that team's
Team Theme purchase.

**Architecture:** Generalize the existing `TeamPurchaseStore` into a reusable
`PurchaseStore<Option: PurchasableCatalogOption>` (the underlying `PurchaseService`/
`LivePurchaseService`/`MockPurchaseService` layer is already generic and needs no changes),
add a new `TeamIconOption` catalog (a structural twin of `TeamThemeOption`), generate the
matching asset-catalog entries from `design/BR2026/`'s source PNGs, and extend
`AppIconPickerViewModel`/`AppIconPickerView` to render Default + Stadium (always free)
followed by the 20 purchasable team icons (purchased-first, then by standings position).

**Tech Stack:** SwiftUI (iOS 26+), StoreKit 2, Swift Testing, SwiftData (unaffected by this
plan — no new persisted models).

## Global Constraints

- Every new non-consumable IAP is $0.99 (Tier 1), product ID scheme
  `com.vibrito.br2026.icon.<rawValue>`.
- Team Icon purchases are entirely separate from Team Theme purchases — no shared
  entitlement, no bundling.
- `TeamIconOption` is always fully declared for every championship target (not per-target
  `#if`-gated) — visibility is gated at the UI layer only, same as `TeamThemeOption`.
- This feature ships in the `BR2026` target only.
- No force-unwraps (`!`) outside of tests. `@Observable`/`@MainActor` for view models and
  stores, matching every existing pattern in this codebase.
- Full test suite (`bundle exec fastlane test`, after
  `export PATH="$(rbenv root)/shims:$PATH"`) must pass at 100% after every task.

---

### Task 1: Generalize `TeamPurchaseStore` into `PurchaseStore<Option>`

**Files:**
- Create: `BR2026/Models/PurchasableCatalogOption.swift`
- Create: `BR2026/Services/PurchaseStore.swift` (replaces `TeamPurchaseStore.swift`)
- Delete: `BR2026/Services/TeamPurchaseStore.swift`
- Modify: `BR2026/Models/TeamThemeOption.swift` (add `PurchasableCatalogOption` conformance)
- Modify: `BR2026/App/Championship.swift`
- Modify: `BR2026/Views/Root/ContentView.swift`
- Modify: `BR2026/Views/More/MoreView.swift`
- Modify: `BR2026/ViewModels/TeamThemePickerViewModel.swift`
- Create: `BR2026Tests/Services/PurchaseStoreTests.swift` (replaces `TeamPurchaseStoreTests.swift`)
- Delete: `BR2026Tests/Services/TeamPurchaseStoreTests.swift`
- Modify: `BR2026Tests/ViewModels/TeamThemePickerViewModelTests.swift`

**Interfaces:**
- Produces: `protocol PurchasableCatalogOption: CaseIterable, Hashable { var rawValue: String { get }; var productID: String { get }; static func rawValue(fromProductID productID: String) -> String? }`
- Produces: `final class PurchaseStore<Option: PurchasableCatalogOption>` with
  `init(service: PurchaseService)`, `func loadOnce() async`,
  `func isPurchased(_ option: Option) -> Bool`, `func price(for option: Option) -> String?`,
  `@discardableResult func purchase(_ option: Option) async -> Bool`,
  `func restorePurchases() async`.
- Consumes: existing `PurchaseService` protocol (`BR2026/Services/PurchaseService.swift`,
  unchanged) and `MockPurchaseService`/`LivePurchaseService` (unchanged).

This is a pure refactor — no new behavior. `PurchaseStore<TeamThemeOption>` must behave
identically to the current `TeamPurchaseStore`.

- [ ] **Step 1: Create the `PurchasableCatalogOption` protocol**

```swift
// BR2026/Models/PurchasableCatalogOption.swift
import Foundation

/// The minimal shape `PurchaseStore` needs from any purchasable catalog of options — both
/// `TeamThemeOption` and `TeamIconOption` conform, letting `PurchaseStore<Option>` serve
/// both catalogs with one implementation instead of two near-identical copies.
/// `RawRepresentable where RawValue == String` already provides `rawValue` on both
/// conforming enums, so their conformance is just `productID`/`rawValue(fromProductID:)`,
/// which both already have (or will have, for `TeamIconOption` — see Task 2).
protocol PurchasableCatalogOption: CaseIterable, Hashable {
    var rawValue: String { get }
    var productID: String { get }
    static func rawValue(fromProductID productID: String) -> String?
}
```

- [ ] **Step 2: Create `PurchaseStore.swift`, generalized from `TeamPurchaseStore`**

```swift
// BR2026/Services/PurchaseStore.swift
import Foundation
import StoreKit
import Observation

/// Owns which options of a purchasable catalog (`TeamThemeOption`, `TeamIconOption`) the
/// user has purchased, sourced from `PurchaseService`. No custom SwiftData cache — StoreKit
/// already persists and syncs entitlements across devices/reinstalls on its own, so
/// re-querying it is enough (unlike match/standings data, which genuinely needs an
/// offline-first cache).
@Observable
@MainActor
final class PurchaseStore<Option: PurchasableCatalogOption> {
    private(set) var purchasedIDs: Set<String> = []
    private var products: [String: Product] = [:]
    private let service: PurchaseService
    private var hasLoadedOnce = false

    init(service: PurchaseService) {
        self.service = service
    }

    func loadOnce() async {
        guard !hasLoadedOnce else { return }
        hasLoadedOnce = true
        let productIDs = Option.allCases.map(\.productID)
        products = (try? await service.fetchProducts(productIDs: productIDs)) ?? [:]
        await refreshPurchasedIDs()
    }

    func isPurchased(_ option: Option) -> Bool {
        purchasedIDs.contains(option.rawValue)
    }

    func price(for option: Option) -> String? {
        products[option.productID]?.displayPrice
    }

    @discardableResult
    func purchase(_ option: Option) async -> Bool {
        guard let succeeded = try? await service.purchase(productID: option.productID), succeeded else {
            return false
        }
        await refreshPurchasedIDs()
        return true
    }

    func restorePurchases() async {
        try? await service.restorePurchases()
        await refreshPurchasedIDs()
    }

    private func refreshPurchasedIDs() async {
        let ids = await service.currentPurchasedProductIDs()
        purchasedIDs = Set(ids.compactMap(Option.rawValue(fromProductID:)))
    }
}
```

- [ ] **Step 3: Delete the old `TeamPurchaseStore.swift`**

```bash
git rm BR2026/Services/TeamPurchaseStore.swift
```

- [ ] **Step 4: Add `PurchasableCatalogOption` conformance to `TeamThemeOption`**

`TeamThemeOption` already has `rawValue` (from `RawRepresentable`), `productID`, and
`rawValue(fromProductID:)` — open `BR2026/Models/TeamThemeOption.swift` and add the
conformance to the existing declaration line:

```swift
enum TeamThemeOption: String, CaseIterable, Identifiable, PurchasableCatalogOption {
```

(This is the only change to this file in this task — everything else stays as-is.)

- [ ] **Step 5: Update `Championship.swift`'s type and variable name**

In `BR2026/App/Championship.swift`, change:

```swift
    let purchaseStore: TeamPurchaseStore
```

to:

```swift
    let themePurchaseStore: PurchaseStore<TeamThemeOption>
```

and change:

```swift
        purchaseStore = TeamPurchaseStore(service: LivePurchaseService())
```

to:

```swift
        themePurchaseStore = PurchaseStore<TeamThemeOption>(service: LivePurchaseService())
```

- [ ] **Step 6: Update `ContentView.swift`**

Change the property declaration:

```swift
    let purchaseStore: TeamPurchaseStore
```

to:

```swift
    let themePurchaseStore: PurchaseStore<TeamThemeOption>
```

Change the `MoreView` construction line:

```swift
            MoreView(service: service, themeStore: themeStore, purchaseStore: purchaseStore)
```

to:

```swift
            MoreView(service: service, themeStore: themeStore, themePurchaseStore: themePurchaseStore)
```

Change the `.task` line:

```swift
        .task { await purchaseStore.loadOnce() }
```

to:

```swift
        .task { await themePurchaseStore.loadOnce() }
```

Update the `ChampionshipApp.swift` call site that constructs `ContentView` to match the
renamed parameter — in `BR2026/App/Championship.swift`:

```swift
            ContentView(config: config, service: service, themeStore: themeStore, purchaseStore: purchaseStore)
```

becomes:

```swift
            ContentView(config: config, service: service, themeStore: themeStore, themePurchaseStore: themePurchaseStore)
```

- [ ] **Step 7: Update `MoreView.swift`**

Change the property declaration and initializer parameter:

```swift
    let purchaseStore: TeamPurchaseStore

    init(service: MatchService, themeStore: TeamThemeStore, purchaseStore: TeamPurchaseStore) {
        _viewModel = State(initialValue: MoreViewModel(service: service))
        self.service = service
        self.themeStore = themeStore
        self.purchaseStore = purchaseStore
    }
```

to:

```swift
    let themePurchaseStore: PurchaseStore<TeamThemeOption>

    init(service: MatchService, themeStore: TeamThemeStore, themePurchaseStore: PurchaseStore<TeamThemeOption>) {
        _viewModel = State(initialValue: MoreViewModel(service: service))
        self.service = service
        self.themeStore = themeStore
        self.themePurchaseStore = themePurchaseStore
    }
```

Change the `TeamThemePickerViewModel` construction site:

```swift
                case .teamThemePicker:
                    TeamThemePickerView(
                        viewModel: TeamThemePickerViewModel(themeStore: themeStore, purchaseStore: purchaseStore, setting: UserDefaultsTeamThemeSetting(), service: service)
                    )
```

to:

```swift
                case .teamThemePicker:
                    TeamThemePickerView(
                        viewModel: TeamThemePickerViewModel(themeStore: themeStore, purchaseStore: themePurchaseStore, setting: UserDefaultsTeamThemeSetting(), service: service)
                    )
```

- [ ] **Step 8: Update `TeamThemePickerViewModel.swift`'s stored property type**

Change:

```swift
    private let purchaseStore: TeamPurchaseStore
```

to:

```swift
    private let purchaseStore: PurchaseStore<TeamThemeOption>
```

Change the initializer parameter type:

```swift
    init(themeStore: TeamThemeStore, purchaseStore: TeamPurchaseStore, setting: TeamThemeSetting, service: MatchService) {
```

to:

```swift
    init(themeStore: TeamThemeStore, purchaseStore: PurchaseStore<TeamThemeOption>, setting: TeamThemeSetting, service: MatchService) {
```

- [ ] **Step 9: Rename and retype the test file**

```bash
git mv BR2026Tests/Services/TeamPurchaseStoreTests.swift BR2026Tests/Services/PurchaseStoreTests.swift
```

Replace its contents entirely:

```swift
// BR2026Tests/Services/PurchaseStoreTests.swift
import Testing
@testable import BR2026

@Suite("PurchaseStore<TeamThemeOption>")
@MainActor
struct PurchaseStoreTests {
    @Test("loadOnce() populates purchasedIDs from the service's initial purchased set")
    func loadOncePopulatesFromInitialSet() async {
        let service = MockPurchaseService(purchasedProductIDs: [TeamThemeOption.palmeirasHome.productID])
        let store = PurchaseStore<TeamThemeOption>(service: service)

        await store.loadOnce()

        #expect(store.isPurchased(.palmeirasHome) == true)
        #expect(store.isPurchased(.flamengoHome) == false)
    }

    @Test("loadOnce() called twice only loads once")
    func loadOnceIsIdempotent() async {
        let service = MockPurchaseService(purchasedProductIDs: [TeamThemeOption.palmeirasHome.productID])
        let store = PurchaseStore<TeamThemeOption>(service: service)

        await store.loadOnce()
        await store.loadOnce()

        #expect(store.isPurchased(.palmeirasHome) == true)
    }

    @Test("purchase() adds the option to purchasedIDs on success")
    func purchaseAddsToOwnedSet() async {
        let service = MockPurchaseService()
        let store = PurchaseStore<TeamThemeOption>(service: service)
        await store.loadOnce()

        let succeeded = await store.purchase(.corinthiansHome)

        #expect(succeeded == true)
        #expect(store.isPurchased(.corinthiansHome) == true)
    }

    @Test("purchase() leaves the option unpurchased when the service reports failure")
    func purchaseLeavesUnpurchasedOnFailure() async {
        let service = MockPurchaseService()
        service.shouldFailNextPurchase = true
        let store = PurchaseStore<TeamThemeOption>(service: service)
        await store.loadOnce()

        let succeeded = await store.purchase(.corinthiansHome)

        #expect(succeeded == false)
        #expect(store.isPurchased(.corinthiansHome) == false)
    }

    @Test("isPurchased(_:) is false for every option before loadOnce()")
    func isPurchasedFalseBeforeLoad() {
        let store = PurchaseStore<TeamThemeOption>(service: MockPurchaseService())

        for option in TeamThemeOption.allCases {
            #expect(store.isPurchased(option) == false)
        }
    }

    @Test("restorePurchases() re-syncs purchasedIDs from the service")
    func restorePurchasesResyncs() async {
        let service = MockPurchaseService()
        let store = PurchaseStore<TeamThemeOption>(service: service)
        await store.loadOnce()
        #expect(store.isPurchased(.bahiaHome) == false)
        service.simulateExternalPurchase(TeamThemeOption.bahiaHome.productID)  // simulates a purchase made on another device

        await store.restorePurchases()

        #expect(store.isPurchased(.bahiaHome) == true)
    }
}
```

- [ ] **Step 10: Retype `TeamPurchaseStore` references in `TeamThemePickerViewModelTests.swift`**

In `BR2026Tests/ViewModels/TeamThemePickerViewModelTests.swift`, every occurrence of
`TeamPurchaseStore(service:` becomes `PurchaseStore<TeamThemeOption>(service:` — this is a
pure find-and-replace across every call site in the file (15 occurrences as of this plan;
the `-g` flag below handles however many there are, so an exact count doesn't need to match):

```bash
sed -i '' 's/TeamPurchaseStore(service:/PurchaseStore<TeamThemeOption>(service:/g' BR2026Tests/ViewModels/TeamThemePickerViewModelTests.swift
```

- [ ] **Step 11: Search for any remaining `TeamPurchaseStore` references**

```bash
grep -rn "TeamPurchaseStore" --include="*.swift" .
```

Expected: no output. If anything remains, retype it the same way as the steps above.

- [ ] **Step 12: Build and run the full test suite**

```bash
xcodebuild build -project BR2026.xcodeproj -scheme BR2026 -destination "generic/platform=iOS Simulator" -quiet
export PATH="$(rbenv root)/shims:$PATH"
bundle exec fastlane test
```

Expected: build exits 0, all tests pass (167/167 — same count as before this task, since this
is a pure refactor with no new tests yet).

- [ ] **Step 13: Commit**

```bash
git add -A -- BR2026/Models/PurchasableCatalogOption.swift BR2026/Services/PurchaseStore.swift BR2026/Services/TeamPurchaseStore.swift BR2026/Models/TeamThemeOption.swift BR2026/App/Championship.swift BR2026/Views/Root/ContentView.swift BR2026/Views/More/MoreView.swift BR2026/ViewModels/TeamThemePickerViewModel.swift BR2026Tests/Services/PurchaseStoreTests.swift BR2026Tests/Services/TeamPurchaseStoreTests.swift BR2026Tests/ViewModels/TeamThemePickerViewModelTests.swift
git commit -m "Generalize TeamPurchaseStore into PurchaseStore<Option>"
```

---

### Task 2: `TeamIconOption` catalog

**Files:**
- Create: `BR2026/Models/TeamIconOption.swift`
- Create: `BR2026Tests/Models/TeamIconOptionTests.swift`

**Interfaces:**
- Consumes: `PurchasableCatalogOption` (Task 1).
- Produces: `enum TeamIconOption: String, CaseIterable, Identifiable, PurchasableCatalogOption`
  with `teamID: Int`, `displayName: LocalizedStringResource`, `iconAssetName: String`,
  `previewImageName: String`, `productID: String`,
  `static func rawValue(fromProductID:) -> String?` — all 20 cases used by later tasks.

- [ ] **Step 1: Write the failing test**

```swift
// BR2026Tests/Models/TeamIconOptionTests.swift
import Testing
@testable import BR2026

@Suite("TeamIconOption")
struct TeamIconOptionTests {
    @Test("Each case's teamID matches the same real team as its TeamThemeOption counterpart")
    func teamIDs() {
        #expect(TeamIconOption.palmeiras.teamID == 121)
        #expect(TeamIconOption.flamengo.teamID == 127)
        #expect(TeamIconOption.fluminense.teamID == 124)
        #expect(TeamIconOption.athleticoParanaense.teamID == 134)
        #expect(TeamIconOption.bahia.teamID == 118)
        #expect(TeamIconOption.redBullBragantino.teamID == 794)
        #expect(TeamIconOption.coritiba.teamID == 147)
        #expect(TeamIconOption.saoPaulo.teamID == 126)
        #expect(TeamIconOption.atleticoMineiro.teamID == 1062)
        #expect(TeamIconOption.corinthians.teamID == 131)
        #expect(TeamIconOption.cruzeiro.teamID == 135)
        #expect(TeamIconOption.internacional.teamID == 119)
        #expect(TeamIconOption.remo.teamID == 1198)
        #expect(TeamIconOption.botafogo.teamID == 120)
        #expect(TeamIconOption.vitoria.teamID == 136)
        #expect(TeamIconOption.mirassol.teamID == 7848)
        #expect(TeamIconOption.chapecoense.teamID == 132)
        #expect(TeamIconOption.santos.teamID == 128)
        #expect(TeamIconOption.gremio.teamID == 130)
        #expect(TeamIconOption.vascoDaGama.teamID == 133)
    }

    @Test("productID follows the com.vibrito.br2026.icon.<rawValue> scheme for every case")
    func productIDs() {
        for option in TeamIconOption.allCases {
            #expect(option.productID == "com.vibrito.br2026.icon.\(option.rawValue)")
        }
    }

    @Test("rawValue(fromProductID:) round-trips every case's productID and returns nil for a foreign ID")
    func rawValueFromProductID() {
        for option in TeamIconOption.allCases {
            #expect(TeamIconOption.rawValue(fromProductID: option.productID) == option.rawValue)
        }
        #expect(TeamIconOption.rawValue(fromProductID: "com.example.other.product") == nil)
        #expect(TeamIconOption.rawValue(fromProductID: "com.vibrito.br2026.theme.palmeirasHome") == nil)
    }

    @Test("iconAssetName and previewImageName match the asset catalog's capitalized team token")
    func assetNames() {
        #expect(TeamIconOption.palmeiras.iconAssetName == "AppIcon-Palmeiras")
        #expect(TeamIconOption.palmeiras.previewImageName == "AppIconPreview-Palmeiras")
        #expect(TeamIconOption.athleticoParanaense.iconAssetName == "AppIcon-AthleticoParanaense")
        #expect(TeamIconOption.redBullBragantino.iconAssetName == "AppIcon-RedBullBragantino")
        #expect(TeamIconOption.vascoDaGama.iconAssetName == "AppIcon-VascoDaGama")
        #expect(TeamIconOption.saoPaulo.iconAssetName == "AppIcon-SaoPaulo")
    }

    @Test("There are exactly 20 cases, one per TeamThemeOption team")
    func caseCount() {
        #expect(TeamIconOption.allCases.count == 20)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:BR2026Tests/TeamIconOptionTests -quiet
```

Expected: FAIL — `Cannot find type 'TeamIconOption' in scope`.

- [ ] **Step 3: Write the implementation**

```swift
// BR2026/Models/TeamIconOption.swift
import Foundation

/// Purchasable alternate app icons, one per Brasileirão team — a structural twin of
/// `TeamThemeOption`, but a fully independent purchase: owning a team's Theme grants
/// nothing toward its Icon, and vice versa. Always declared for every championship target
/// (same reasoning as `TeamThemeOption` — a zero-case `enum ...: String` fails to compile,
/// and per-target case gating would leave other targets with none at all); visibility is
/// gated at the UI layer instead, mirroring `MoreViewModel`'s `#if` around the "Team Theme"
/// row.
enum TeamIconOption: String, CaseIterable, Identifiable, PurchasableCatalogOption {
    case palmeiras
    case flamengo
    case fluminense
    case athleticoParanaense
    case bahia
    case redBullBragantino
    case coritiba
    case saoPaulo
    case atleticoMineiro
    case corinthians
    case cruzeiro
    case internacional
    case remo
    case botafogo
    case vitoria
    case mirassol
    case chapecoense
    case santos
    case gremio
    case vascoDaGama

    var id: String { rawValue }

    /// Same live-API team IDs `TeamThemeOption.teamID` uses — both catalogs describe the
    /// same 20 real-world teams, so the App Icon picker can sort by the same standings data
    /// without a second ID mapping to maintain.
    var teamID: Int {
        switch self {
        case .palmeiras: 121
        case .flamengo: 127
        case .fluminense: 124
        case .athleticoParanaense: 134
        case .bahia: 118
        case .redBullBragantino: 794
        case .coritiba: 147
        case .saoPaulo: 126
        case .atleticoMineiro: 1062
        case .corinthians: 131
        case .cruzeiro: 135
        case .internacional: 119
        case .remo: 1198
        case .botafogo: 120
        case .vitoria: 136
        case .mirassol: 7848
        case .chapecoense: 132
        case .santos: 128
        case .gremio: 130
        case .vascoDaGama: 133
        }
    }

    /// Matches `TeamThemeOption.displayName` exactly (both already dropped the "(Home)"
    /// suffix) so the same team reads identically in both pickers.
    var displayName: LocalizedStringResource {
        switch self {
        case .palmeiras: "Palmeiras"
        case .flamengo: "Flamengo"
        case .fluminense: "Fluminense"
        case .athleticoParanaense: "Athletico Paranaense"
        case .bahia: "Bahia"
        case .redBullBragantino: "Red Bull Bragantino"
        case .coritiba: "Coritiba"
        case .saoPaulo: "São Paulo"
        case .atleticoMineiro: "Atlético Mineiro"
        case .corinthians: "Corinthians"
        case .cruzeiro: "Cruzeiro"
        case .internacional: "Internacional"
        case .remo: "Remo"
        case .botafogo: "Botafogo"
        case .vitoria: "Vitória"
        case .mirassol: "Mirassol"
        case .chapecoense: "Chapecoense"
        case .santos: "Santos"
        case .gremio: "Grêmio"
        case .vascoDaGama: "Vasco da Gama"
        }
    }

    /// The App Icon Set name for `UIApplication.setAlternateIconName(_:)` — derived by
    /// capitalizing the raw value's first letter rather than a 20-way switch, since every
    /// raw value above is already a valid capitalized-identifier-minus-first-letter (verified
    /// by `TeamIconOptionTests.assetNames()` for the three cases whose asset-catalog token
    /// doesn't match its `design/BR2026/` source filename: `athleticoParanaense`,
    /// `redBullBragantino`, `vascoDaGama` — see Task 3's source→destination mapping table).
    var iconAssetName: String { "AppIcon-\(rawValue.prefix(1).uppercased() + rawValue.dropFirst())" }

    /// The plain Image Set used for this option's preview thumbnail — same
    /// App-Icon-Set-vs-plain-Image-Set distinction `AppIconOption.previewImageName` documents.
    var previewImageName: String { "AppIconPreview-\(rawValue.prefix(1).uppercased() + rawValue.dropFirst())" }

    var productID: String { "com.vibrito.br2026.icon.\(rawValue)" }

    static func rawValue(fromProductID productID: String) -> String? {
        let prefix = "com.vibrito.br2026.icon."
        guard productID.hasPrefix(prefix) else { return nil }
        return String(productID.dropFirst(prefix.count))
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:BR2026Tests/TeamIconOptionTests -quiet
```

Expected: PASS, all 5 tests green.

- [ ] **Step 5: Commit**

```bash
git add BR2026/Models/TeamIconOption.swift BR2026Tests/Models/TeamIconOptionTests.swift
git commit -m "Add TeamIconOption catalog for the Team Icon IAP"
```

---

### Task 3: Asset pipeline and StoreKit test config

**Files:**
- Create: 20× `BR2026/Resources/Assets.xcassets/AppIcon-<Team>.appiconset/` (Contents.json + PNG)
- Create: 20× `BR2026/Resources/Assets.xcassets/AppIconPreview-<Team>.imageset/` (Contents.json + PNG)
- Modify: `BR2026.xcodeproj/project.pbxproj` (`ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`, both Debug and Release configs of the `BR2026` target)
- Modify: `BR2026.storekit`

No automated test covers generated assets or the local StoreKit config directly (same
reasoning as the equivalent Team Theme task) — this task is verified by an `xcodebuild build`
and a `python3 -m json.tool` validity check.

- [ ] **Step 1: Generate the 20 appiconset + 20 imageset folders**

The `<Team>` destination token is always the enum-derived name from `TeamIconOption`
(`rawValue` capitalized) — 17 of 20 source filenames already end in that exact token; 3 don't
and need the explicit mapping below (same table as the design spec):

| `TeamIconOption` case | Source file in `design/BR2026/` | Destination token |
|---|---|---|
| `.athleticoParanaense` | `AppIcon-1n-AthleticoPR-1024.png` | `AthleticoParanaense` |
| `.redBullBragantino` | `AppIcon-1o-Bragantino-1024.png` | `RedBullBragantino` |
| `.vascoDaGama` | `AppIcon-1u-Vasco-1024.png` | `VascoDaGama` |

Run this script from the repo root:

```bash
python3 <<'PYEOF'
import json
import os
import shutil

ASSETS = "BR2026/Resources/Assets.xcassets"
DESIGN = "design/BR2026"

# case rawValue -> (destination token, source filename in design/BR2026)
teams = {
    "palmeiras": ("Palmeiras", "AppIcon-1k-Palmeiras-1024.png"),
    "flamengo": ("Flamengo", "AppIcon-1l-Flamengo-1024.png"),
    "fluminense": ("Fluminense", "AppIcon-1m-Fluminense-1024.png"),
    "athleticoParanaense": ("AthleticoParanaense", "AppIcon-1n-AthleticoPR-1024.png"),
    "redBullBragantino": ("RedBullBragantino", "AppIcon-1o-Bragantino-1024.png"),
    "coritiba": ("Coritiba", "AppIcon-1q-Coritiba-1024.png"),
    "cruzeiro": ("Cruzeiro", "AppIcon-1r-Cruzeiro-1024.png"),
    "internacional": ("Internacional", "AppIcon-1s-Internacional-1024.png"),
    "chapecoense": ("Chapecoense", "AppIcon-1t-Chapecoense-1024.png"),
    "vascoDaGama": ("VascoDaGama", "AppIcon-1u-Vasco-1024.png"),
    "botafogo": ("Botafogo", "AppIcon-1v-Botafogo-1024.png"),
    "bahia": ("Bahia", "AppIcon-1w-Bahia-1024.png"),
    "saoPaulo": ("SaoPaulo", "AppIcon-1x-SaoPaulo-1024.png"),
    "atleticoMineiro": ("AtleticoMineiro", "AppIcon-1y-AtleticoMineiro-1024.png"),
    "corinthians": ("Corinthians", "AppIcon-1z-Corinthians-1024.png"),
    "vitoria": ("Vitoria", "AppIcon-2a-Vitoria-1024.png"),
    "mirassol": ("Mirassol", "AppIcon-2b-Mirassol-1024.png"),
    "remo": ("Remo", "AppIcon-2c-Remo-1024.png"),
    "gremio": ("Gremio", "AppIcon-2d-Gremio-1024.png"),
    "santos": ("Santos", "AppIcon-2e-Santos-1024.png"),
}

assert len(teams) == 20

for raw_value, (token, source_filename) in teams.items():
    source_path = os.path.join(DESIGN, source_filename)
    assert os.path.isfile(source_path), f"missing source file: {source_path}"

    appiconset_dir = os.path.join(ASSETS, f"AppIcon-{token}.appiconset")
    os.makedirs(appiconset_dir, exist_ok=True)
    dest_icon_name = f"AppIcon-{token}-1024.png"
    shutil.copyfile(source_path, os.path.join(appiconset_dir, dest_icon_name))
    with open(os.path.join(appiconset_dir, "Contents.json"), "w") as f:
        json.dump({
            "images": [
                {"filename": dest_icon_name, "idiom": "universal", "platform": "ios", "size": "1024x1024"}
            ],
            "info": {"author": "xcode", "version": 1}
        }, f, indent=2)
        f.write("\n")

    preview_dir = os.path.join(ASSETS, f"AppIconPreview-{token}.imageset")
    os.makedirs(preview_dir, exist_ok=True)
    dest_preview_name = f"AppIconPreview-{token}.png"
    shutil.copyfile(source_path, os.path.join(preview_dir, dest_preview_name))
    with open(os.path.join(preview_dir, "Contents.json"), "w") as f:
        json.dump({
            "images": [
                {"filename": dest_preview_name, "idiom": "universal", "scale": "1x"},
                {"idiom": "universal", "scale": "2x"},
                {"idiom": "universal", "scale": "3x"}
            ],
            "info": {"author": "xcode", "version": 1}
        }, f, indent=2)
        f.write("\n")

print("Generated 20 appiconset + 20 imageset folders")
PYEOF
```

- [ ] **Step 2: Verify the generated folders**

```bash
ls BR2026/Resources/Assets.xcassets/ | grep -c "^AppIcon-.*\.appiconset$"
ls BR2026/Resources/Assets.xcassets/ | grep -c "^AppIconPreview-.*\.imageset$"
```

Expected: `21` for the first (20 new team icons + the pre-existing `AppIcon-Stadium.appiconset`
— the default `AppIcon.appiconset` has no hyphen after `AppIcon` so this pattern doesn't
count it), `22` for the second (20 new team previews + the pre-existing
`AppIconPreview-Light.imageset` and `AppIconPreview-Stadium.imageset`, both of which do start
with `AppIconPreview-`).

- [ ] **Step 3: Update `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` in `project.pbxproj`**

```bash
sed -i '' 's/ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = "AppIcon-Stadium";/ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = "AppIcon-Stadium AppIcon-Palmeiras AppIcon-Flamengo AppIcon-Fluminense AppIcon-AthleticoParanaense AppIcon-Bahia AppIcon-RedBullBragantino AppIcon-Coritiba AppIcon-SaoPaulo AppIcon-AtleticoMineiro AppIcon-Corinthians AppIcon-Cruzeiro AppIcon-Internacional AppIcon-Remo AppIcon-Botafogo AppIcon-Vitoria AppIcon-Mirassol AppIcon-Chapecoense AppIcon-Santos AppIcon-Gremio AppIcon-VascoDaGama";/' BR2026.xcodeproj/project.pbxproj
grep -c "ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = \"AppIcon-Stadium AppIcon-Palmeiras" BR2026.xcodeproj/project.pbxproj
```

Expected: `2` (both the `BR2026` target's Debug and Release configs updated).

- [ ] **Step 4: Add 20 new products to `BR2026.storekit`**

```bash
python3 <<'PYEOF'
import json
import uuid

with open("BR2026.storekit") as f:
    data = json.load(f)

teams = [
    ("palmeiras", "Palmeiras"),
    ("flamengo", "Flamengo"),
    ("fluminense", "Fluminense"),
    ("athleticoParanaense", "Athletico Paranaense"),
    ("bahia", "Bahia"),
    ("redBullBragantino", "Red Bull Bragantino"),
    ("coritiba", "Coritiba"),
    ("saoPaulo", "São Paulo"),
    ("atleticoMineiro", "Atlético Mineiro"),
    ("corinthians", "Corinthians"),
    ("cruzeiro", "Cruzeiro"),
    ("internacional", "Internacional"),
    ("remo", "Remo"),
    ("botafogo", "Botafogo"),
    ("vitoria", "Vitória"),
    ("mirassol", "Mirassol"),
    ("chapecoense", "Chapecoense"),
    ("santos", "Santos"),
    ("gremio", "Grêmio"),
    ("vascoDaGama", "Vasco da Gama"),
]
assert len(teams) == 20

for raw_value, team_name in teams:
    data["products"].append({
        "displayPrice": "0.99",
        "familyShareable": False,
        "internalID": str(uuid.uuid4()).upper(),
        "localizations": [
            {
                "description": f"Unlock the {team_name} app icon.",
                "displayName": f"{team_name} Icon",
                "locale": "en_US"
            }
        ],
        "productID": f"com.vibrito.br2026.icon.{raw_value}",
        "referenceName": f"{team_name} Icon",
        "type": "NonConsumable"
    })

with open("BR2026.storekit", "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print(f"BR2026.storekit now has {len(data['products'])} products")
PYEOF
```

Expected output: `BR2026.storekit now has 40 products`.

- [ ] **Step 5: Validate the StoreKit config is well-formed JSON**

```bash
python3 -m json.tool BR2026.storekit > /dev/null && echo "valid JSON"
```

Expected: `valid JSON`.

- [ ] **Step 6: Build to verify the asset catalog and build setting are valid**

```bash
xcodebuild build -project BR2026.xcodeproj -scheme BR2026 -destination "generic/platform=iOS Simulator" -quiet
```

Expected: exits 0, no new warnings/errors about the asset catalog or alternate icon names.

- [ ] **Step 7: Commit**

```bash
git add BR2026/Resources/Assets.xcassets/ BR2026.xcodeproj/project.pbxproj BR2026.storekit
git commit -m "Add asset catalog entries and StoreKit products for 20 team icons"
```

---

### Task 4: `AppIconPickerViewModel` purchase gating

**Files:**
- Modify: `BR2026/ViewModels/AppIconPickerViewModel.swift`
- Modify: `BR2026Tests/ViewModels/AppIconPickerViewModelTests.swift`

**Interfaces:**
- Consumes: `TeamIconOption` (Task 2), `PurchaseStore<TeamIconOption>` (Task 1),
  `MatchService.cachedStandings()`/`fetchStandings()` (existing, unchanged),
  `AppIconSetting` (existing, unchanged).
- Produces: `AppIconPickerViewModel(iconSetting:purchaseStore:service:)`,
  `selectedIconAssetName: String?`, `standings: [Standing]`, `func loadOnce() async`,
  `func isSelected(_ option: AppIconOption) -> Bool`,
  `func isSelected(_ option: TeamIconOption) -> Bool`,
  `var sortedTeamOptions: [TeamIconOption]`, `func isPurchased(_ option: TeamIconOption) -> Bool`,
  `func price(for option: TeamIconOption) -> String?`,
  `func select(_ option: AppIconOption) async`, `func select(_ option: TeamIconOption) async`,
  `func restorePurchases() async` — all consumed by Task 5's view.

- [ ] **Step 1: Write the failing tests**

Replace the full contents of `BR2026Tests/ViewModels/AppIconPickerViewModelTests.swift`:

```swift
// BR2026Tests/ViewModels/AppIconPickerViewModelTests.swift
import Testing
@testable import BR2026

@Suite("AppIconPickerViewModel")
@MainActor
struct AppIconPickerViewModelTests {
    @Test("selectedIconAssetName reflects the setting's currentIconName at init")
    func selectedIconAssetNameReflectsSetting() {
        let setting = StubAppIconSetting(currentIconName: nil)
        let service = StubMatchService(matches: [], standings: [])
        let purchaseStore = PurchaseStore<TeamIconOption>(service: MockPurchaseService())
        let viewModel = AppIconPickerViewModel(iconSetting: setting, purchaseStore: purchaseStore, service: service)

        #expect(viewModel.selectedIconAssetName == nil)
        #expect(viewModel.isSelected(AppIconOption.light) == true)
    }

    @Test("isSelected(_:) for AppIconOption matches the current icon asset name")
    func isSelectedForAppIconOption() {
        let setting = StubAppIconSetting(currentIconName: "AppIcon-Stadium")
        let service = StubMatchService(matches: [], standings: [])
        let purchaseStore = PurchaseStore<TeamIconOption>(service: MockPurchaseService())
        let viewModel = AppIconPickerViewModel(iconSetting: setting, purchaseStore: purchaseStore, service: service)

        #expect(viewModel.isSelected(AppIconOption.stadium) == true)
        #expect(viewModel.isSelected(AppIconOption.light) == false)
    }

    @Test("select(_: AppIconOption) updates selectedIconAssetName and calls setIconName")
    func selectAppIconOptionUpdatesSelection() async {
        let setting = StubAppIconSetting(currentIconName: nil)
        let service = StubMatchService(matches: [], standings: [])
        let purchaseStore = PurchaseStore<TeamIconOption>(service: MockPurchaseService())
        let viewModel = AppIconPickerViewModel(iconSetting: setting, purchaseStore: purchaseStore, service: service)

        await viewModel.select(AppIconOption.stadium)

        #expect(viewModel.isSelected(AppIconOption.stadium) == true)
        #expect(setting.setIconNameCalls == ["AppIcon-Stadium"])
        #expect(viewModel.errorMessage == nil)
    }

    @Test("select(_: AppIconOption) sets errorMessage when setIconName throws")
    func selectAppIconOptionSetsErrorOnFailure() async {
        let setting = StubAppIconSetting(currentIconName: nil)
        setting.shouldThrow = true
        let service = StubMatchService(matches: [], standings: [])
        let purchaseStore = PurchaseStore<TeamIconOption>(service: MockPurchaseService())
        let viewModel = AppIconPickerViewModel(iconSetting: setting, purchaseStore: purchaseStore, service: service)

        await viewModel.select(AppIconOption.stadium)

        #expect(viewModel.isSelected(AppIconOption.light) == true)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("select(_: TeamIconOption) purchases an unpurchased team icon before applying it")
    func selectTeamIconPurchasesThenApplies() async {
        let setting = StubAppIconSetting(currentIconName: nil)
        let service = StubMatchService(matches: [], standings: [])
        let purchaseStore = PurchaseStore<TeamIconOption>(service: MockPurchaseService())
        let viewModel = AppIconPickerViewModel(iconSetting: setting, purchaseStore: purchaseStore, service: service)

        await viewModel.select(TeamIconOption.palmeiras)

        #expect(viewModel.isSelected(TeamIconOption.palmeiras) == true)
        #expect(setting.setIconNameCalls == ["AppIcon-Palmeiras"])
        #expect(viewModel.errorMessage == nil)
        #expect(purchaseStore.isPurchased(.palmeiras) == true)
    }

    @Test("select(_: TeamIconOption) does not re-purchase an already-purchased team icon")
    func selectTeamIconSkipsPurchaseWhenAlreadyOwned() async {
        let setting = StubAppIconSetting(currentIconName: nil)
        let service = StubMatchService(matches: [], standings: [])
        let purchaseService = MockPurchaseService(purchasedProductIDs: [TeamIconOption.palmeiras.productID])
        let purchaseStore = PurchaseStore<TeamIconOption>(service: purchaseService)
        await purchaseStore.loadOnce()
        let viewModel = AppIconPickerViewModel(iconSetting: setting, purchaseStore: purchaseStore, service: service)

        await viewModel.select(TeamIconOption.palmeiras)

        #expect(viewModel.isSelected(TeamIconOption.palmeiras) == true)
    }

    @Test("select(_: TeamIconOption) leaves selection unchanged when the purchase fails")
    func selectTeamIconLeavesUnchangedOnFailedPurchase() async {
        let setting = StubAppIconSetting(currentIconName: nil)
        let service = StubMatchService(matches: [], standings: [])
        let purchaseService = MockPurchaseService()
        purchaseService.shouldFailNextPurchase = true
        let purchaseStore = PurchaseStore<TeamIconOption>(service: purchaseService)
        let viewModel = AppIconPickerViewModel(iconSetting: setting, purchaseStore: purchaseStore, service: service)

        await viewModel.select(TeamIconOption.palmeiras)

        #expect(viewModel.isSelected(TeamIconOption.palmeiras) == false)
        #expect(setting.setIconNameCalls.isEmpty)
    }

    @Test("isPurchased(_:) and price(for:) pass through to the purchase store")
    func isPurchasedAndPricePassThrough() async {
        let setting = StubAppIconSetting(currentIconName: nil)
        let service = StubMatchService(matches: [], standings: [])
        let purchaseService = MockPurchaseService(purchasedProductIDs: [TeamIconOption.flamengo.productID])
        let purchaseStore = PurchaseStore<TeamIconOption>(service: purchaseService)
        await purchaseStore.loadOnce()
        let viewModel = AppIconPickerViewModel(iconSetting: setting, purchaseStore: purchaseStore, service: service)

        #expect(viewModel.isPurchased(.flamengo) == true)
        #expect(viewModel.isPurchased(.palmeiras) == false)
    }

    @Test("restorePurchases() delegates to the purchase store")
    func restorePurchasesDelegates() async {
        let setting = StubAppIconSetting(currentIconName: nil)
        let service = StubMatchService(matches: [], standings: [])
        let purchaseService = MockPurchaseService(purchasedProductIDs: [TeamIconOption.bahia.productID])
        let purchaseStore = PurchaseStore<TeamIconOption>(service: purchaseService)
        let viewModel = AppIconPickerViewModel(iconSetting: setting, purchaseStore: purchaseStore, service: service)

        await viewModel.restorePurchases()

        #expect(viewModel.isPurchased(.bahia) == true)
    }

    @Test("sortedTeamOptions orders purchased teams before unpurchased teams")
    func sortedTeamOptionsPutsPurchasedFirst() async {
        let setting = StubAppIconSetting(currentIconName: nil)
        let service = StubMatchService(matches: [], standings: [])
        let purchaseService = MockPurchaseService(purchasedProductIDs: [TeamIconOption.corinthians.productID])
        let purchaseStore = PurchaseStore<TeamIconOption>(service: purchaseService)
        await purchaseStore.loadOnce()
        let viewModel = AppIconPickerViewModel(iconSetting: setting, purchaseStore: purchaseStore, service: service)

        let sorted = viewModel.sortedTeamOptions

        #expect(sorted.first == .corinthians)
    }

    @Test("sortedTeamOptions orders teams within the same purchase group by standings position")
    func sortedTeamOptionsOrdersByStandings() {
        let setting = StubAppIconSetting(currentIconName: nil)
        let flamengo = Standing(
            position: 1,
            team: Team(id: TeamIconOption.flamengo.teamID, name: "Flamengo", shortName: "FLA", crestURL: nil),
            playedGames: 10, won: 8, draw: 1, lost: 1, goalsFor: 20, goalsAgainst: 8, goalDifference: 12, points: 25
        )
        let palmeiras = Standing(
            position: 2,
            team: Team(id: TeamIconOption.palmeiras.teamID, name: "Palmeiras", shortName: "PAL", crestURL: nil),
            playedGames: 10, won: 7, draw: 2, lost: 1, goalsFor: 18, goalsAgainst: 9, goalDifference: 9, points: 23
        )
        let service = StubMatchService(matches: [], standings: [palmeiras, flamengo])
        let purchaseStore = PurchaseStore<TeamIconOption>(service: MockPurchaseService())
        let viewModel = AppIconPickerViewModel(iconSetting: setting, purchaseStore: purchaseStore, service: service)

        let sorted = viewModel.sortedTeamOptions

        #expect(sorted.firstIndex(of: .flamengo)! < sorted.firstIndex(of: .palmeiras)!)
    }

    @Test("loadOnce() fetches standings when the cache is empty, updating sortedTeamOptions once fetched")
    func loadOnceFetchesStandingsWhenCacheEmpty() async {
        let setting = StubAppIconSetting(currentIconName: nil)
        let flamengo = Standing(
            position: 1,
            team: Team(id: TeamIconOption.flamengo.teamID, name: "Flamengo", shortName: "FLA", crestURL: nil),
            playedGames: 10, won: 8, draw: 1, lost: 1, goalsFor: 20, goalsAgainst: 8, goalDifference: 12, points: 25
        )
        let service = StubMatchService(matches: [], standings: [flamengo])
        service.cachedStandingsOverride = []
        let purchaseStore = PurchaseStore<TeamIconOption>(service: MockPurchaseService())
        let viewModel = AppIconPickerViewModel(iconSetting: setting, purchaseStore: purchaseStore, service: service)
        #expect(viewModel.standings.isEmpty)

        await viewModel.loadOnce()

        #expect(viewModel.standings.map(\.teamID) == [flamengo.teamID])
        #expect(viewModel.sortedTeamOptions.firstIndex(of: .flamengo)! < viewModel.sortedTeamOptions.firstIndex(of: .palmeiras)!)
    }

    @Test("loadOnce() called twice only fetches standings once")
    func loadOnceFetchesStandingsOnlyOnce() async {
        let setting = StubAppIconSetting(currentIconName: nil)
        let service = StubMatchService(matches: [], standings: [])
        let purchaseStore = PurchaseStore<TeamIconOption>(service: MockPurchaseService())
        let viewModel = AppIconPickerViewModel(iconSetting: setting, purchaseStore: purchaseStore, service: service)

        await viewModel.loadOnce()
        await viewModel.loadOnce()

        #expect(service.fetchStandingsCallCount == 1)
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

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:BR2026Tests/AppIconPickerViewModelTests -quiet
```

Expected: FAIL to compile — `AppIconPickerViewModel` has no `selectedIconAssetName`,
`isSelected`, `sortedTeamOptions`, etc. yet, and its initializer doesn't accept
`purchaseStore`/`service`.

- [ ] **Step 3: Write the implementation**

Replace the full contents of `BR2026/ViewModels/AppIconPickerViewModel.swift`:

```swift
// BR2026/ViewModels/AppIconPickerViewModel.swift
import Foundation
import Observation

@Observable
@MainActor
final class AppIconPickerViewModel {
    private(set) var selectedIconAssetName: String?
    private(set) var errorMessage: String?
    private(set) var standings: [Standing]
    private let iconSetting: AppIconSetting
    private let purchaseStore: PurchaseStore<TeamIconOption>
    private let service: MatchService
    private var hasLoadedStandingsOnce = false

    init(iconSetting: AppIconSetting, purchaseStore: PurchaseStore<TeamIconOption>, service: MatchService) {
        self.iconSetting = iconSetting
        self.purchaseStore = purchaseStore
        self.service = service
        selectedIconAssetName = iconSetting.currentIconName
        standings = service.cachedStandings()
    }

    /// Same cached-then-refresh pattern as `TeamThemePickerViewModel.loadOnce()` — needed
    /// because a user can reach More → App Icon without ever visiting the Standings tab.
    func loadOnce() async {
        guard !hasLoadedStandingsOnce else { return }
        hasLoadedStandingsOnce = true
        if let fresh = try? await service.fetchStandings() {
            standings = fresh
        }
    }

    func isSelected(_ option: AppIconOption) -> Bool {
        option.iconAssetName == selectedIconAssetName
    }

    func isSelected(_ option: TeamIconOption) -> Bool {
        option.iconAssetName == selectedIconAssetName
    }

    /// Purchased teams first, then by standings position — identical logic to
    /// `TeamThemePickerViewModel.sortedOptions`.
    var sortedTeamOptions: [TeamIconOption] {
        let positionsByTeamID = Dictionary(standings.map { ($0.teamID, $0.position) }, uniquingKeysWith: { first, _ in first })
        return TeamIconOption.allCases.sorted { lhs, rhs in
            let lhsPurchased = purchaseStore.isPurchased(lhs)
            let rhsPurchased = purchaseStore.isPurchased(rhs)
            guard lhsPurchased == rhsPurchased else { return lhsPurchased }
            let lhsPosition = positionsByTeamID[lhs.teamID] ?? Int.max
            let rhsPosition = positionsByTeamID[rhs.teamID] ?? Int.max
            return lhsPosition < rhsPosition
        }
    }

    func isPurchased(_ option: TeamIconOption) -> Bool {
        purchaseStore.isPurchased(option)
    }

    func price(for option: TeamIconOption) -> String? {
        purchaseStore.price(for: option)
    }

    /// Default/Stadium — always free, no purchase check.
    func select(_ option: AppIconOption) async {
        await applyIconName(option.iconAssetName)
    }

    /// A team icon — purchase-gated, same shape as `TeamThemePickerViewModel.select(_:)`.
    func select(_ option: TeamIconOption) async {
        guard !isSelected(option) else { return }
        errorMessage = nil
        if !purchaseStore.isPurchased(option) {
            guard await purchaseStore.purchase(option) else { return }
        }
        await applyIconName(option.iconAssetName)
    }

    func restorePurchases() async {
        await purchaseStore.restorePurchases()
    }

    private func applyIconName(_ name: String?) async {
        guard name != selectedIconAssetName else { return }
        do {
            try await iconSetting.setIconName(name)
            selectedIconAssetName = name
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Couldn't change the app icon. Try again.")
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:BR2026Tests/AppIconPickerViewModelTests -quiet
```

Expected: PASS, all 13 tests green.

- [ ] **Step 5: Commit**

```bash
git add BR2026/ViewModels/AppIconPickerViewModel.swift BR2026Tests/ViewModels/AppIconPickerViewModelTests.swift
git commit -m "Purchase-gate AppIconPickerViewModel for team icons"
```

---

### Task 5: `AppIconPickerView` purchase UI

**Files:**
- Modify: `BR2026/Views/More/AppIconPickerView.swift`

**Interfaces:**
- Consumes: `AppIconPickerViewModel` (Task 4) — `isSelected(_:)` (both overloads),
  `sortedTeamOptions`, `isPurchased(_:)`, `price(for:)`, `select(_:)` (both overloads),
  `restorePurchases()`, `errorMessage`.

No new unit tests — this is a SwiftUI view with no business logic (per CLAUDE.md's testing
guidance, "Unit test ViewModels and Services — not Views"). Verified by build + manual
Simulator check.

- [ ] **Step 1: Replace the view's implementation**

```swift
// BR2026/Views/More/AppIconPickerView.swift
import SwiftUI

struct AppIconPickerView: View {
    @State private var viewModel: AppIconPickerViewModel
    @Environment(\.themeTokens) private var themeTokens

    init(viewModel: AppIconPickerViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                GlassCard(cornerRadius: 18, style: .transparent) {
                    VStack(spacing: 10) {
                        // Every free row gets a trailing divider unconditionally — the
                        // purchasable team list below always has at least one row (20 fixed
                        // cases, never empty), so a free row is never the last row overall.
                        ForEach(AppIconOption.allCases) { option in
                            freeRowView(option)
                            Rectangle()
                                .fill(Color.white.opacity(0.16))
                                .frame(height: 0.5)
                        }
                        ForEach(Array(viewModel.sortedTeamOptions.enumerated()), id: \.element.id) { index, option in
                            teamRowView(option)
                            if index < viewModel.sortedTeamOptions.count - 1 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.16))
                                    .frame(height: 0.5)
                            }
                        }
                    }
                }
                Button {
                    Task { await viewModel.restorePurchases() }
                } label: {
                    Text("Restore Purchases")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(themeTokens.textColor.opacity(0.55))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.plain)
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
        .navigationTitle("App Icon")
        .navigationBarTitleDisplayMode(.inline)
        .trackScreen("AppIconPicker")
        .task { await viewModel.loadOnce() }
    }

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

    @ViewBuilder
    private func teamTrailingSlot(_ option: TeamIconOption) -> some View {
        if !viewModel.isPurchased(option) {
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                if let price = viewModel.price(for: option) {
                    Text(price)
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .foregroundStyle(themeTokens.textColor.opacity(0.55))
        } else if viewModel.isSelected(option) {
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(themeTokens.textColor)
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

```bash
xcodebuild build -project BR2026.xcodeproj -scheme BR2026 -destination "generic/platform=iOS Simulator" -quiet
```

Expected: exits 0.

- [ ] **Step 3: Commit**

```bash
git add BR2026/Views/More/AppIconPickerView.swift
git commit -m "Render purchasable team icons in the App Icon picker"
```

---

### Task 6: DI wiring and final verification

**Files:**
- Modify: `BR2026/App/Championship.swift`
- Modify: `BR2026/Views/Root/ContentView.swift`
- Modify: `BR2026/Views/More/MoreView.swift`

**Interfaces:**
- Consumes: `PurchaseStore<TeamIconOption>` (Task 1's generic type + Task 2's `TeamIconOption`),
  `AppIconPickerViewModel(iconSetting:purchaseStore:service:)` (Task 4).

- [ ] **Step 1: Add `iconPurchaseStore` to `ChampionshipApp`**

In `BR2026/App/Championship.swift`, add the new stored property next to
`themePurchaseStore`:

```swift
    let themePurchaseStore: PurchaseStore<TeamThemeOption>
    let iconPurchaseStore: PurchaseStore<TeamIconOption>
```

In `init()`, add the construction line next to `themePurchaseStore`'s, reusing the same
`LivePurchaseService()` instance (construct it once, pass it to both):

```swift
        let purchaseService = LivePurchaseService()
        themePurchaseStore = PurchaseStore<TeamThemeOption>(service: purchaseService)
        iconPurchaseStore = PurchaseStore<TeamIconOption>(service: purchaseService)
```

(This replaces the single-line `themePurchaseStore = PurchaseStore<TeamThemeOption>(service: LivePurchaseService())` from Task 1 Step 5 — both stores now share one `purchaseService` local.)

Update the `ContentView` construction in `body`:

```swift
            ContentView(config: config, service: service, themeStore: themeStore, themePurchaseStore: themePurchaseStore, iconPurchaseStore: iconPurchaseStore)
```

- [ ] **Step 2: Thread `iconPurchaseStore` through `ContentView`**

In `BR2026/Views/Root/ContentView.swift`, add the property:

```swift
    let iconPurchaseStore: PurchaseStore<TeamIconOption>
```

Update the `MoreView` construction line:

```swift
            MoreView(service: service, themeStore: themeStore, themePurchaseStore: themePurchaseStore, iconPurchaseStore: iconPurchaseStore)
```

Add a `.task` alongside the existing two:

```swift
        .task { await iconPurchaseStore.loadOnce() }
```

- [ ] **Step 3: Thread `iconPurchaseStore` through `MoreView`**

In `BR2026/Views/More/MoreView.swift`, add the property and initializer parameter:

```swift
    let iconPurchaseStore: PurchaseStore<TeamIconOption>

    init(service: MatchService, themeStore: TeamThemeStore, themePurchaseStore: PurchaseStore<TeamThemeOption>, iconPurchaseStore: PurchaseStore<TeamIconOption>) {
        _viewModel = State(initialValue: MoreViewModel(service: service))
        self.service = service
        self.themeStore = themeStore
        self.themePurchaseStore = themePurchaseStore
        self.iconPurchaseStore = iconPurchaseStore
    }
```

Update the `AppIconPickerViewModel` construction site:

```swift
                case .appIconPicker:
                    AppIconPickerView(
                        viewModel: AppIconPickerViewModel(iconSetting: UIKitAppIconSetting(), purchaseStore: iconPurchaseStore, service: service)
                    )
```

- [ ] **Step 4: Build and run the full test suite**

```bash
xcodebuild build -project BR2026.xcodeproj -scheme BR2026 -destination "generic/platform=iOS Simulator" -quiet
export PATH="$(rbenv root)/shims:$PATH"
bundle exec fastlane test
```

Expected: build exits 0, all tests pass (180/180 — 167 existing + 5 `TeamIconOptionTests`
(Task 2) + 8 net-new tests from Task 4's `AppIconPickerViewModelTests.swift` rewrite (13
tests now, replacing the 5 that existed before Task 4: 167 + 5 + (13 - 5) = 180).

- [ ] **Step 5: Build the other three championship targets to confirm they're unaffected**

```bash
xcodebuild build -project BR2026.xcodeproj -scheme PremierLeague2026 -destination "generic/platform=iOS Simulator" -quiet
xcodebuild build -project BR2026.xcodeproj -scheme Ligue12026 -destination "generic/platform=iOS Simulator" -quiet
xcodebuild build -project BR2026.xcodeproj -scheme PrimeiraLiga2026 -destination "generic/platform=iOS Simulator" -quiet
```

Expected: all three exit 0 — `TeamIconOption`/`PurchaseStore<TeamIconOption>` compile for
every target (not per-target `#if`-gated, per the Global Constraints), even though only
`BR2026`'s `MoreView`/`ChampionshipApp` wire them up.

- [ ] **Step 6: Commit**

```bash
git add BR2026/App/Championship.swift BR2026/Views/Root/ContentView.swift BR2026/Views/More/MoreView.swift
git commit -m "Wire up iconPurchaseStore through the app"
```

---

## Manual Verification (post-plan, not automated)

- In Simulator, with `BR2026.storekit` wired into the scheme's Run configuration (already
  done for Team Theme — see CLAUDE.md's Theming section), open More → App Icon: confirm
  Default and Stadium show no lock, the 20 team icons show a lock + $0.99 price, tapping a
  locked one opens Apple's sandbox purchase sheet, and completing a purchase both unlocks the
  row and switches the app icon immediately.
- Confirm "Restore Purchases" unlocks previously-purchased team icons after
  `MockPurchaseService`/sandbox state is reset.
- App Store Connect: create the 20 new non-consumables per the design spec's Product Catalog
  checklist before this ships to TestFlight/App Store.
