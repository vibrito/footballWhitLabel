# Team Theme In-App Purchases Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Gate the 20 existing Team Theme colors behind real per-team $0.99 non-consumable
StoreKit 2 purchases, replacing the hardcoded `TeamThemeOption.isPurchased == true` stub.
Implements `docs/superpowers/specs/2026-07-15-team-theme-iap-design.md`.

**Architecture:** A new `PurchaseService` protocol (mirrors `MatchService`) abstracts StoreKit
2 behind `LivePurchaseService` (real) and `MockPurchaseService` (tests only). A new
`@Observable @MainActor` `TeamPurchaseStore` owns purchased-team state, pull-based from
`PurchaseService.currentPurchasedProductIDs()` — **note:** the approved spec sketched an
`AsyncStream`-based live-observation design; this plan replaces it with a simpler pull-based
one after finding the stream design hangs `await store.loadOnce()` forever in tests (an
`AsyncStream` that's never explicitly finished never lets a `for await` loop return) and races
`purchase()`'s caller against a detached background task. The pull-based design meets every
product requirement in the spec (initial load reflects prior purchases, purchase unlocks
immediately, restore unlocks immediately) with no hang/race risk, at the cost of not
auto-observing a same-session cross-device purchase — an edge case the spec never called for.

**Tech Stack:** Swift Testing (`@Test`/`@Suite`), StoreKit 2 (`Product`, `Transaction`,
`AppStore`), `@Observable`.

## Global Constraints

- No `UIKit` unless SwiftUI/StoreKit has no equivalent (CLAUDE.md Coding Guidelines).
- No force-unwraps (`!`) outside of tests.
- `@Observable` over `ObservableObject`.
- Test files live in `BR2026Tests/`, mirroring source structure; `MockPurchaseService` is used
  in all automated tests — no real StoreKit calls in the test target.
- **Ask the user before running `bundle exec fastlane test` or `xcodebuild` builds** — do not
  run them automatically after any step in this plan, even though it's a structured
  multi-task plan (per standing user feedback, confirmed 2026-07-15, applies to every test
  run with no exceptions based on earlier permission in the same session).
- Product ID scheme: `"com.vibrito.br2026.theme.<TeamThemeOption.rawValue>"`, all 20 teams,
  all Tier 1 ($0.99), all non-consumable.

---

### Task 1: `TeamThemeOption` — replace `isPurchased` with `productID`/`rawValue(fromProductID:)`

**Files:**
- Modify: `BR2026/Models/TeamThemeOption.swift`
- Modify: `BR2026Tests/Models/TeamThemeOptionTests.swift`
- Modify: `CLAUDE.md`

**Interfaces:**
- Produces: `TeamThemeOption.productID: String`, `TeamThemeOption.rawValue(fromProductID:) -> String?` (static) — consumed by `TeamPurchaseStore` (Task 3) and `LivePurchaseService`/`MockPurchaseService` (Task 2).
- Removes: `TeamThemeOption.isPurchased` — no other file references it after this task (verified: only `TeamThemeOption.swift:324` and `TeamThemeOptionTests.swift:40` reference it today).

- [ ] **Step 1: Write the failing tests**

In `BR2026Tests/Models/TeamThemeOptionTests.swift`, replace the `allPurchased` test:

```swift
    @Test("All cases are stubbed as purchased")
    func allPurchased() {
        for option in TeamThemeOption.allCases {
            #expect(option.isPurchased == true)
        }
    }
```

with:

```swift
    @Test("productID follows the com.vibrito.br2026.theme.<rawValue> scheme for every case")
    func productIDs() {
        for option in TeamThemeOption.allCases {
            #expect(option.productID == "com.vibrito.br2026.theme.\(option.rawValue)")
        }
    }

    @Test("rawValue(fromProductID:) round-trips every case's productID and returns nil for a foreign ID")
    func rawValueFromProductID() {
        for option in TeamThemeOption.allCases {
            #expect(TeamThemeOption.rawValue(fromProductID: option.productID) == option.rawValue)
        }
        #expect(TeamThemeOption.rawValue(fromProductID: "com.example.other.product") == nil)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL with "value of type 'TeamThemeOption' has no member 'productID'" (compile error, since the test target won't build until Step 3 lands).

- [ ] **Step 3: Implement `productID`/`rawValue(fromProductID:)`, remove `isPurchased`**

In `BR2026/Models/TeamThemeOption.swift`, replace:

```swift
    /// Stubbed always-true until real StoreKit 2 entitlement checking replaces this.
    var isPurchased: Bool { true }
}
```

with:

```swift
    /// The StoreKit product identifier this team's theme purchase uses — one non-consumable
    /// per team, scheme `"com.vibrito.br2026.theme.<rawValue>"`. Derivable directly from the
    /// case with no separate mapping table to keep in sync as teams are added.
    var productID: String {
        "com.vibrito.br2026.theme.\(rawValue)"
    }

    /// The inverse of `productID` — maps a StoreKit product ID back to a `TeamThemeOption`
    /// `rawValue`, used by `TeamPurchaseStore` to translate a purchased-product-ID set into
    /// purchased-team state. Returns `nil` for anything not matching this app's product ID
    /// scheme (e.g. a foreign/malformed ID).
    static func rawValue(fromProductID productID: String) -> String? {
        let prefix = "com.vibrito.br2026.theme."
        guard productID.hasPrefix(prefix) else { return nil }
        return String(productID.dropFirst(prefix.count))
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS — `productIDs` and `rawValueFromProductID` both green, and every other
`TeamThemeOptionTests` test (unaffected by this change) still passes.

- [ ] **Step 5: Update CLAUDE.md's stale `isPurchased` reference**

In `CLAUDE.md`, replace:

```
- `TeamThemeOption` (`BR2026/Models/TeamThemeOption.swift`) is the purchasable-theme catalog —
  currently 3 Palmeiras kit variants (Home/Away/Third). Its cases are **not** per-target
  `#if`-gated (a zero-case `enum ...: String` fails to compile); visibility for other
  championship targets is gated instead in `MoreViewModel.preferencesRows`, via the same
  `#if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA)` pattern
  `AppIconOption` uses for its per-target cases. `isPurchased` is hardcoded `true` — real
  StoreKit 2 entitlement checking is a future phase (see the roadmap's IAP team themes item).
```

with:

```
- `TeamThemeOption` (`BR2026/Models/TeamThemeOption.swift`) is the purchasable-theme catalog —
  20 teams (one home-kit variant each) as of this writing. Its cases are **not** per-target
  `#if`-gated (a zero-case `enum ...: String` fails to compile); visibility for other
  championship targets is gated instead in `MoreViewModel.preferencesRows`, via the same
  `#if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA)` pattern
  `AppIconOption` uses for its per-target cases. Each case maps to its own StoreKit
  non-consumable via `productID` (`"com.vibrito.br2026.theme.<rawValue>"`); `TeamPurchaseStore`
  (`BR2026/Services/TeamPurchaseStore.swift`) owns purchased-team state via `PurchaseService`
  (`LivePurchaseService`/`MockPurchaseService`) — see
  `docs/superpowers/specs/2026-07-15-team-theme-iap-design.md` for the full design.
```

- [ ] **Step 6: Commit**

```bash
git add BR2026/Models/TeamThemeOption.swift BR2026Tests/Models/TeamThemeOptionTests.swift CLAUDE.md
git commit -m "Replace TeamThemeOption.isPurchased stub with productID/rawValue(fromProductID:)"
```

---

### Task 2: `PurchaseService` protocol + `MockPurchaseService`

**Files:**
- Create: `BR2026/Services/PurchaseService.swift`
- Create: `BR2026/Services/MockPurchaseService.swift`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `protocol PurchaseService` with `fetchProducts(productIDs:) async throws -> [String: Product]`, `purchase(productID:) async throws -> Bool`, `restorePurchases() async throws`, `currentPurchasedProductIDs() async -> Set<String>`. `final class MockPurchaseService: PurchaseService` with `init(purchasedProductIDs: Set<String> = [])` and `var shouldFailNextPurchase: Bool`. Both consumed by `TeamPurchaseStore` (Task 3) and `LivePurchaseService` (Task 6).

- [ ] **Step 1: Write `PurchaseService`**

Create `BR2026/Services/PurchaseService.swift`:

```swift
import StoreKit

/// Abstracts StoreKit 2's `Product`/`Transaction` APIs so `TeamPurchaseStore` can be tested
/// without making real StoreKit calls — mirrors `MatchService`'s role for match/standings
/// data: one live implementation (`LivePurchaseService`) talks to the real store, one mock
/// (`MockPurchaseService`) is used in all automated tests.
protocol PurchaseService {
    /// Fetches StoreKit `Product` metadata (price, display name) for the given product IDs,
    /// keyed by product ID.
    func fetchProducts(productIDs: [String]) async throws -> [String: Product]

    /// Starts the purchase flow for one product. Returns `true` if the user now owns it
    /// (purchase completed and verified), `false` if they cancelled or the purchase is
    /// pending (e.g. Ask to Buy). Throws for actual failures (network, StoreKit errors,
    /// failed verification).
    func purchase(productID: String) async throws -> Bool

    /// Re-syncs entitlements from the App Store — the "Restore Purchases" action App Store
    /// guidelines require for non-consumables.
    func restorePurchases() async throws

    /// A snapshot of every product ID the user currently owns.
    func currentPurchasedProductIDs() async -> Set<String>
}
```

- [ ] **Step 2: Write `MockPurchaseService`**

Create `BR2026/Services/MockPurchaseService.swift`:

```swift
import StoreKit

/// Test double for `PurchaseService` — used in every automated test, never in the shipped
/// app (unlike `MockMatchService`, which also serves as `ChampionshipApp`'s offline
/// fallback). `fetchProducts` always returns `[:]`: `StoreKit.Product` has no public
/// initializer, so a mock can't hand back a fake one — price display is verified manually via
/// the `.storekit` configuration file instead (see Task 8).
final class MockPurchaseService: PurchaseService {
    private var purchased: Set<String>
    /// When `true`, `purchase(productID:)` returns `false` (simulating a cancelled/failed
    /// purchase) instead of granting the entitlement.
    var shouldFailNextPurchase = false

    init(purchasedProductIDs: Set<String> = []) {
        self.purchased = purchasedProductIDs
    }

    func fetchProducts(productIDs: [String]) async throws -> [String: Product] { [:] }

    func purchase(productID: String) async throws -> Bool {
        guard !shouldFailNextPurchase else { return false }
        purchased.insert(productID)
        return true
    }

    func restorePurchases() async throws {}

    func currentPurchasedProductIDs() async -> Set<String> { purchased }
}
```

- [ ] **Step 3: Verify it compiles**

Run: `xcodebuild build -project BR2026.xcodeproj -scheme BR2026 -destination "generic/platform=iOS Simulator" -quiet`
Expected: build succeeds with no new warnings/errors from these two files. (A full test run is
covered by Task 9 — don't run `fastlane test` here per the Global Constraints.)

- [ ] **Step 4: Commit**

```bash
git add BR2026/Services/PurchaseService.swift BR2026/Services/MockPurchaseService.swift
git commit -m "Add PurchaseService protocol and MockPurchaseService test double"
```

---

### Task 3: `TeamPurchaseStore`

**Files:**
- Create: `BR2026/Services/TeamPurchaseStore.swift`
- Create: `BR2026Tests/Services/TeamPurchaseStoreTests.swift`

**Interfaces:**
- Consumes: `PurchaseService` (Task 2), `TeamThemeOption.productID`/`rawValue(fromProductID:)` (Task 1).
- Produces: `@Observable @MainActor final class TeamPurchaseStore` with `init(service: PurchaseService)`, `purchasedTeamIDs: Set<String>` (read-only), `loadOnce() async`, `isPurchased(_ option: TeamThemeOption) -> Bool`, `price(for option: TeamThemeOption) -> String?`, `purchase(_ option: TeamThemeOption) async -> Bool` (`@discardableResult`), `restorePurchases() async`. Consumed by `TeamThemePickerViewModel` (Task 4) and `ChampionshipApp`/`ContentView`/`MoreView` (Task 7).

- [ ] **Step 1: Write the failing tests**

Create `BR2026Tests/Services/TeamPurchaseStoreTests.swift`:

```swift
import Testing
@testable import BR2026

@Suite("TeamPurchaseStore")
@MainActor
struct TeamPurchaseStoreTests {
    @Test("loadOnce() populates purchasedTeamIDs from the service's initial purchased set")
    func loadOncePopulatesFromInitialSet() async {
        let service = MockPurchaseService(purchasedProductIDs: [TeamThemeOption.palmeirasHome.productID])
        let store = TeamPurchaseStore(service: service)

        await store.loadOnce()

        #expect(store.isPurchased(.palmeirasHome) == true)
        #expect(store.isPurchased(.flamengoHome) == false)
    }

    @Test("loadOnce() called twice only loads once")
    func loadOnceIsIdempotent() async {
        let service = MockPurchaseService(purchasedProductIDs: [TeamThemeOption.palmeirasHome.productID])
        let store = TeamPurchaseStore(service: service)

        await store.loadOnce()
        await store.loadOnce()

        #expect(store.isPurchased(.palmeirasHome) == true)
    }

    @Test("purchase() adds the team to purchasedTeamIDs on success")
    func purchaseAddsToOwnedSet() async {
        let service = MockPurchaseService()
        let store = TeamPurchaseStore(service: service)
        await store.loadOnce()

        let succeeded = await store.purchase(.corinthiansHome)

        #expect(succeeded == true)
        #expect(store.isPurchased(.corinthiansHome) == true)
    }

    @Test("purchase() leaves the team unpurchased when the service reports failure")
    func purchaseLeavesUnpurchasedOnFailure() async {
        let service = MockPurchaseService()
        service.shouldFailNextPurchase = true
        let store = TeamPurchaseStore(service: service)
        await store.loadOnce()

        let succeeded = await store.purchase(.corinthiansHome)

        #expect(succeeded == false)
        #expect(store.isPurchased(.corinthiansHome) == false)
    }

    @Test("isPurchased(_:) is false for every team before loadOnce()")
    func isPurchasedFalseBeforeLoad() {
        let store = TeamPurchaseStore(service: MockPurchaseService())

        for option in TeamThemeOption.allCases {
            #expect(store.isPurchased(option) == false)
        }
    }

    @Test("restorePurchases() re-syncs purchasedTeamIDs from the service")
    func restorePurchasesResyncs() async {
        let service = MockPurchaseService()
        let store = TeamPurchaseStore(service: service)
        await store.loadOnce()
        #expect(store.isPurchased(.bahiaHome) == false)
        service.simulateExternalPurchase(TeamThemeOption.bahiaHome.productID)  // simulates a purchase made on another device

        await store.restorePurchases()

        #expect(store.isPurchased(.bahiaHome) == true)
    }
}
```

- [ ] **Step 2: Add the `MockPurchaseService.simulateExternalPurchase(_:)` test helper the last test needs**

`restorePurchasesResyncs` needs a way to add to `MockPurchaseService`'s owned set from outside
`purchase(productID:)` (simulating a purchase that happened elsewhere, discovered only via
restore). In `BR2026/Services/MockPurchaseService.swift`, add:

```swift
    /// Test-only helper simulating an entitlement that exists on the App Store but wasn't
    /// granted through this instance's own `purchase(productID:)` — e.g. a purchase made on
    /// another device, only visible here after `restorePurchases()`. Named distinctly from
    /// the `purchased` stored property to avoid any ambiguity between a same-named property
    /// and method.
    func simulateExternalPurchase(_ productID: String) {
        purchased.insert(productID)
    }
```

(This is additive to the file Task 2 already created — no conflict with Task 2's content.)

- [ ] **Step 3: Run tests to verify they fail**

Expected: FAIL with "cannot find 'TeamPurchaseStore' in scope" (compile error).

- [ ] **Step 4: Write `TeamPurchaseStore`**

Create `BR2026/Services/TeamPurchaseStore.swift`:

```swift
import Foundation
import StoreKit
import Observation

/// Owns which teams' themes the user has purchased, sourced from `PurchaseService`. No
/// custom SwiftData cache — StoreKit already persists and syncs entitlements across
/// devices/reinstalls on its own, so re-querying it is enough (unlike match/standings data,
/// which genuinely needs an offline-first cache).
@Observable
@MainActor
final class TeamPurchaseStore {
    private(set) var purchasedTeamIDs: Set<String> = []
    private var products: [String: Product] = [:]
    private let service: PurchaseService
    private var hasLoadedOnce = false

    init(service: PurchaseService) {
        self.service = service
    }

    func loadOnce() async {
        guard !hasLoadedOnce else { return }
        hasLoadedOnce = true
        let productIDs = TeamThemeOption.allCases.map(\.productID)
        products = (try? await service.fetchProducts(productIDs: productIDs)) ?? [:]
        await refreshPurchasedTeamIDs()
    }

    func isPurchased(_ option: TeamThemeOption) -> Bool {
        purchasedTeamIDs.contains(option.rawValue)
    }

    func price(for option: TeamThemeOption) -> String? {
        products[option.productID]?.displayPrice
    }

    @discardableResult
    func purchase(_ option: TeamThemeOption) async -> Bool {
        guard let succeeded = try? await service.purchase(productID: option.productID), succeeded else {
            return false
        }
        await refreshPurchasedTeamIDs()
        return true
    }

    func restorePurchases() async {
        try? await service.restorePurchases()
        await refreshPurchasedTeamIDs()
    }

    private func refreshPurchasedTeamIDs() async {
        let ids = await service.currentPurchasedProductIDs()
        purchasedTeamIDs = Set(ids.compactMap(TeamThemeOption.rawValue(fromProductID:)))
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Expected: PASS — all 6 `TeamPurchaseStoreTests` green.

- [ ] **Step 6: Commit**

```bash
git add BR2026/Services/TeamPurchaseStore.swift BR2026/Services/MockPurchaseService.swift BR2026Tests/Services/TeamPurchaseStoreTests.swift
git commit -m "Add TeamPurchaseStore"
```

---

### Task 4: `TeamThemePickerViewModel` — purchase-gate `select(_:)`

**Files:**
- Modify: `BR2026/ViewModels/TeamThemePickerViewModel.swift`
- Modify: `BR2026Tests/ViewModels/TeamThemePickerViewModelTests.swift`

**Interfaces:**
- Consumes: `TeamPurchaseStore` (Task 3).
- Produces: `TeamThemePickerViewModel.init(themeStore:purchaseStore:setting:)` (signature change — `purchaseStore` param added), `isPurchased(_ option: TeamThemeOption) -> Bool`, `price(for option: TeamThemeOption) -> String?`, `restorePurchases() async`. Consumed by `TeamThemePickerView` (Task 5) and `MoreView` (Task 7).

- [ ] **Step 1: Write the failing tests**

Replace the full contents of `BR2026Tests/ViewModels/TeamThemePickerViewModelTests.swift`:

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
        let purchaseStore = TeamPurchaseStore(service: MockPurchaseService())
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting)

        #expect(viewModel.selectedOption == nil)
    }

    @Test("selectedOption is derived from a matching persisted rawValue")
    func derivesFromPersistedValue() {
        let setting = StubTeamThemeSetting(selectedThemeID: TeamThemeOption.palmeirasHome.rawValue)
        let store = TeamThemeStore(setting: setting, service: StubMatchService(matches: [], standings: []))
        let purchaseStore = TeamPurchaseStore(service: MockPurchaseService())
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting)

        #expect(viewModel.selectedOption == .palmeirasHome)
    }

    @Test("select() purchases an unpurchased team before applying it, and updates selectedOption on success")
    func selectPurchasesThenUpdatesOnSuccess() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)
        let purchaseStore = TeamPurchaseStore(service: MockPurchaseService())
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting)

        await viewModel.select(.palmeirasHome)

        #expect(viewModel.selectedOption == .palmeirasHome)
        #expect(viewModel.errorMessage == nil)
        #expect(purchaseStore.isPurchased(.palmeirasHome) == true)
    }

    @Test("select() does not re-purchase an already-purchased team")
    func selectSkipsPurchaseWhenAlreadyOwned() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)
        let purchaseService = MockPurchaseService(purchasedProductIDs: [TeamThemeOption.palmeirasHome.productID])
        let purchaseStore = TeamPurchaseStore(service: purchaseService)
        await purchaseStore.loadOnce()
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting)

        await viewModel.select(.palmeirasHome)

        #expect(viewModel.selectedOption == .palmeirasHome)
    }

    @Test("select() leaves selectedOption unchanged, with no errorMessage, when the purchase fails/is cancelled")
    func selectLeavesUnchangedOnFailedPurchase() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)
        let purchaseService = MockPurchaseService()
        purchaseService.shouldFailNextPurchase = true
        let purchaseStore = TeamPurchaseStore(service: purchaseService)
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting)

        await viewModel.select(.palmeirasHome)

        #expect(viewModel.selectedOption == nil)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("select() sets errorMessage and leaves selectedOption unchanged when theme application fails after a successful purchase")
    func selectSetsErrorMessageOnThemeApplicationFailure() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.shouldThrowOnTeamThemeFetch = true
        let store = TeamThemeStore(setting: setting, service: service)
        let purchaseStore = TeamPurchaseStore(service: MockPurchaseService())
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting)

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
        let purchaseStore = TeamPurchaseStore(service: MockPurchaseService())
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting)
        await viewModel.select(.palmeirasHome)
        let callCountAfterFirstSelect = service.fetchTeamThemeColorSetCallCount

        await viewModel.select(.palmeirasHome)

        #expect(service.fetchTeamThemeColorSetCallCount == callCountAfterFirstSelect)
    }

    @Test("isPurchased(_:) and price(for:) pass through to the purchase store")
    func isPurchasedAndPricePassThrough() async {
        let setting = StubTeamThemeSetting()
        let store = TeamThemeStore(setting: setting, service: StubMatchService(matches: [], standings: []))
        let purchaseService = MockPurchaseService(purchasedProductIDs: [TeamThemeOption.flamengoHome.productID])
        let purchaseStore = TeamPurchaseStore(service: purchaseService)
        await purchaseStore.loadOnce()
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting)

        #expect(viewModel.isPurchased(.flamengoHome) == true)
        #expect(viewModel.isPurchased(.palmeirasHome) == false)
    }

    @Test("restorePurchases() delegates to the purchase store")
    func restorePurchasesDelegates() async {
        let setting = StubTeamThemeSetting()
        let store = TeamThemeStore(setting: setting, service: StubMatchService(matches: [], standings: []))
        let purchaseService = MockPurchaseService(purchasedProductIDs: [TeamThemeOption.bahiaHome.productID])
        let purchaseStore = TeamPurchaseStore(service: purchaseService)
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting)

        await viewModel.restorePurchases()

        #expect(viewModel.isPurchased(.bahiaHome) == true)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — compile error, `TeamThemePickerViewModel.init` doesn't accept `purchaseStore:`.

- [ ] **Step 3: Update `TeamThemePickerViewModel`**

Replace the full contents of `BR2026/ViewModels/TeamThemePickerViewModel.swift`:

```swift
import Foundation
import Observation

@Observable
@MainActor
final class TeamThemePickerViewModel {
    private(set) var selectedOption: TeamThemeOption?
    private(set) var errorMessage: String?
    private let themeStore: TeamThemeStore
    private let purchaseStore: TeamPurchaseStore
    private let setting: TeamThemeSetting

    init(themeStore: TeamThemeStore, purchaseStore: TeamPurchaseStore, setting: TeamThemeSetting) {
        self.themeStore = themeStore
        self.purchaseStore = purchaseStore
        self.setting = setting
        selectedOption = TeamThemeOption.allCases.first { $0.rawValue == setting.selectedThemeID }
    }

    func isPurchased(_ option: TeamThemeOption) -> Bool {
        purchaseStore.isPurchased(option)
    }

    func price(for option: TeamThemeOption) -> String? {
        purchaseStore.price(for: option)
    }

    func select(_ option: TeamThemeOption?) async {
        guard option != selectedOption else { return }
        if let option, !purchaseStore.isPurchased(option) {
            guard await purchaseStore.purchase(option) else { return }
        }
        guard await themeStore.select(option) else {
            errorMessage = String(localized: "Couldn't apply that team's colors. Try again.")
            return
        }
        selectedOption = option
        errorMessage = nil
    }

    func restorePurchases() async {
        await purchaseStore.restorePurchases()
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS — all `TeamThemePickerViewModelTests` green (9 tests).

- [ ] **Step 5: Commit**

```bash
git add BR2026/ViewModels/TeamThemePickerViewModel.swift BR2026Tests/ViewModels/TeamThemePickerViewModelTests.swift
git commit -m "Purchase-gate TeamThemePickerViewModel.select(_:)"
```

---

### Task 5: `TeamThemePickerView` — lock icon/price + Restore Purchases

**Files:**
- Modify: `BR2026/Views/More/TeamThemePickerView.swift`

**Interfaces:**
- Consumes: `TeamThemePickerViewModel.isPurchased(_:)`/`price(for:)`/`restorePurchases()` (Task 4).
- Produces: no new public interface — a View, not unit-tested per CLAUDE.md's "Unit test ViewModels and Services — not Views."

- [ ] **Step 1: Update the row's trailing slot and add the Restore Purchases button**

Replace the full contents of `BR2026/Views/More/TeamThemePickerView.swift`:

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
                        .fill(Color(hex: option.previewColorHex))
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
                trailingSlot(option)
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(themeTokens.textColor)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func trailingSlot(_ option: TeamThemeOption?) -> some View {
        if let option, !viewModel.isPurchased(option) {
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                if let price = viewModel.price(for: option) {
                    Text(price)
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .foregroundStyle(themeTokens.textColor.opacity(0.55))
        } else if viewModel.selectedOption == option {
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(themeTokens.textColor)
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild build -project BR2026.xcodeproj -scheme BR2026 -destination "generic/platform=iOS Simulator" -quiet`
Expected: build succeeds. (`MoreView.swift`'s inline `TeamThemePickerViewModel(...)` construction
will still fail to compile until Task 7 — that's expected and fixed there, not here.)

- [ ] **Step 3: Commit**

```bash
git add BR2026/Views/More/TeamThemePickerView.swift
git commit -m "Show lock icon/price for unpurchased teams and add Restore Purchases button"
```

---

### Task 6: `LivePurchaseService`

**Files:**
- Create: `BR2026/Services/LivePurchaseService.swift`

**Interfaces:**
- Consumes: `PurchaseService` protocol (Task 2).
- Produces: `final class LivePurchaseService: PurchaseService`, `enum PurchaseServiceError: Error`. Consumed by `ChampionshipApp` (Task 7).

- [ ] **Step 1: Write `LivePurchaseService`**

Create `BR2026/Services/LivePurchaseService.swift`:

```swift
import StoreKit

/// Real StoreKit 2 implementation of `PurchaseService`. Used everywhere except the test
/// target — no "if not configured, fall back to mock" branch like `LiveMatchService`/
/// `MockMatchService` have, since StoreKit's local `.storekit` configuration file (see
/// `BR2026.storekit`) already makes this fully functional in Simulator with no external
/// setup or API key.
final class LivePurchaseService: PurchaseService {
    func fetchProducts(productIDs: [String]) async throws -> [String: Product] {
        let products = try await Product.products(for: productIDs)
        return Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
    }

    func purchase(productID: String) async throws -> Bool {
        let products = try await Product.products(for: [productID])
        guard let product = products.first else { throw PurchaseServiceError.productNotFound }
        let result = try await product.purchase()
        switch result {
        case .success(.verified(let transaction)):
            await transaction.finish()
            return true
        case .success(.unverified):
            throw PurchaseServiceError.unverifiedTransaction
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
    }

    func currentPurchasedProductIDs() async -> Set<String> {
        var owned: Set<String> = []
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement {
                owned.insert(transaction.productID)
            }
        }
        return owned
    }
}

enum PurchaseServiceError: Error {
    case productNotFound
    case unverifiedTransaction
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild build -project BR2026.xcodeproj -scheme BR2026 -destination "generic/platform=iOS Simulator" -quiet`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add BR2026/Services/LivePurchaseService.swift
git commit -m "Add LivePurchaseService (real StoreKit 2 implementation)"
```

---

### Task 7: Wire `TeamPurchaseStore` through `ChampionshipApp` → `ContentView` → `MoreView`

**Files:**
- Modify: `BR2026/App/Championship.swift`
- Modify: `BR2026/Views/Root/ContentView.swift`
- Modify: `BR2026/Views/More/MoreView.swift`

**Interfaces:**
- Consumes: `TeamPurchaseStore` (Task 3), `LivePurchaseService` (Task 6), `TeamThemePickerViewModel.init(themeStore:purchaseStore:setting:)` (Task 4).
- Produces: `ContentView.init(config:service:themeStore:purchaseStore:)`, `MoreView.init(service:tabSelectionColorHex:themeStore:purchaseStore:)` (both signature changes).

- [ ] **Step 1: Add `purchaseStore` to `ChampionshipApp`**

In `BR2026/App/Championship.swift`, replace:

```swift
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
```

with:

```swift
    let modelContainer: ModelContainer
    let service: MatchService
    let themeStore: TeamThemeStore
    let purchaseStore: TeamPurchaseStore

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
        purchaseStore = TeamPurchaseStore(service: LivePurchaseService())
    }

    var body: some Scene {
        WindowGroup {
            ContentView(config: config, service: service, themeStore: themeStore, purchaseStore: purchaseStore)
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }
```

- [ ] **Step 2: Thread `purchaseStore` through `ContentView`**

Replace the full contents of `BR2026/Views/Root/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    let config: ChampionshipConfig
    let service: MatchService
    let themeStore: TeamThemeStore
    let purchaseStore: TeamPurchaseStore

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
            MoreView(service: service, tabSelectionColorHex: config.tabSelectionColorHex, themeStore: themeStore, purchaseStore: purchaseStore)
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
                .tint(themeStore.tokens.overrideAccentColor ?? Color(hex: config.accentColorHex))
        }
        // Governs only the tab bar's own selected-item chrome; each tab's content above
        // re-applies the true brand accent so LiveChip/AccentPill etc. stay brand-colored.
        .tint(themeStore.tokens.overrideTabSelectionColor ?? themeStore.tokens.overrideAccentColor ?? Color(hex: config.tabSelectionColorHex))
        .background(StadiumBackground())
        .environment(\.themeTokens, themeStore.tokens)
        .task { await themeStore.loadOnce() }
        .task { await purchaseStore.loadOnce() }
    }
}
```

- [ ] **Step 3: Thread `purchaseStore` through `MoreView`**

In `BR2026/Views/More/MoreView.swift`, replace:

```swift
struct MoreView: View {
    @State private var viewModel: MoreViewModel
    let tabSelectionColorHex: String
    let themeStore: TeamThemeStore
    @Environment(\.themeTokens) private var themeTokens

    init(service: MatchService, tabSelectionColorHex: String, themeStore: TeamThemeStore) {
        _viewModel = State(initialValue: MoreViewModel(service: service))
        self.tabSelectionColorHex = tabSelectionColorHex
        self.themeStore = themeStore
    }
```

with:

```swift
struct MoreView: View {
    @State private var viewModel: MoreViewModel
    let tabSelectionColorHex: String
    let themeStore: TeamThemeStore
    let purchaseStore: TeamPurchaseStore
    @Environment(\.themeTokens) private var themeTokens

    init(service: MatchService, tabSelectionColorHex: String, themeStore: TeamThemeStore, purchaseStore: TeamPurchaseStore) {
        _viewModel = State(initialValue: MoreViewModel(service: service))
        self.tabSelectionColorHex = tabSelectionColorHex
        self.themeStore = themeStore
        self.purchaseStore = purchaseStore
    }
```

and replace:

```swift
                case .teamThemePicker:
                    TeamThemePickerView(
                        viewModel: TeamThemePickerViewModel(themeStore: themeStore, setting: UserDefaultsTeamThemeSetting())
                    )
```

with:

```swift
                case .teamThemePicker:
                    TeamThemePickerView(
                        viewModel: TeamThemePickerViewModel(themeStore: themeStore, purchaseStore: purchaseStore, setting: UserDefaultsTeamThemeSetting())
                    )
```

- [ ] **Step 4: Verify the whole app target compiles**

Run: `xcodebuild build -project BR2026.xcodeproj -scheme BR2026 -destination "generic/platform=iOS Simulator" -quiet`
Expected: build succeeds — this is the first point where the full app (not just the modified
files in isolation) compiles end-to-end with the new purchase flow wired in.

- [ ] **Step 5: Commit**

```bash
git add BR2026/App/Championship.swift BR2026/Views/Root/ContentView.swift BR2026/Views/More/MoreView.swift
git commit -m "Wire TeamPurchaseStore through ChampionshipApp, ContentView, and MoreView"
```

---

### Task 8: Local StoreKit testing configuration

**Files:**
- Create: `BR2026.storekit` (repo root, alongside `BR2026.xcodeproj`)

**Interfaces:**
- Consumes: nothing (static data file).
- Produces: a `.storekit` configuration Xcode can attach to the `BR2026` scheme for
  Simulator/on-device testing of the real purchase/restore flow with no App Store Connect
  setup required.

- [ ] **Step 1: Generate the `.storekit` file**

Run this exact script — it writes `BR2026.storekit` at the repo root with all 20 team
products declared, matching `TeamThemeOption`'s current 20 cases and each one's `productID`
scheme from Task 1:

```bash
python3 << 'PYEOF'
import json

teams = [
    ('palmeirasHome', 'Palmeiras (Home)', '35590C27-D1EB-492C-93E1-DAC621C9F7C5'),
    ('flamengoHome', 'Flamengo (Home)', 'C7B6D6F9-5507-4EF0-B1D3-D009F0E56F3C'),
    ('fluminenseHome', 'Fluminense (Home)', '653FEE07-53E2-4404-AE37-B34B0C923F12'),
    ('athleticoParanaenseHome', 'Athletico Paranaense (Home)', 'B979F586-54ED-4DAE-985E-1A1C015133CE'),
    ('bahiaHome', 'Bahia (Home)', '131AA9BA-F86A-4344-A1BD-85E8C8C957CA'),
    ('redBullBragantinoHome', 'Red Bull Bragantino (Home)', 'D0346482-026E-4E31-9262-7B3EAB268C4E'),
    ('coritibaHome', 'Coritiba (Home)', '49867DA7-9E0B-45E0-8F7E-1C2795EA91E6'),
    ('saoPauloHome', 'São Paulo (Home)', 'BE7B4DD1-1397-401E-9A88-0FAD02D6E169'),
    ('atleticoMineiroHome', 'Atlético Mineiro (Home)', '154FD321-8C18-4C71-B2E8-75921142A7F3'),
    ('corinthiansHome', 'Corinthians (Home)', 'EAF8AF5A-0143-4371-9E4B-B0E1BD7C0138'),
    ('cruzeiroHome', 'Cruzeiro (Home)', '0B124483-BC8C-424C-AF6F-2103A4A55045'),
    ('internacionalHome', 'Internacional (Home)', 'BD786EB6-F494-4F0C-B245-33410A1E1074'),
    ('remoHome', 'Remo (Home)', '435E92D0-9D38-4B51-B8E4-3F7523411CDF'),
    ('botafogoHome', 'Botafogo (Home)', '1C0DC8FB-C0A7-4142-829D-A38932E95F9A'),
    ('vitoriaHome', 'Vitória (Home)', 'E770B828-910E-4C29-88B3-3A52F7C6CD12'),
    ('mirassolHome', 'Mirassol (Home)', '323CE37F-2DA3-4F1A-857D-AA240F627B90'),
    ('chapecoenseHome', 'Chapecoense (Home)', '62242422-C330-4CAA-85DF-2068D9811DEF'),
    ('santosHome', 'Santos (Home)', '19CA6CD3-9A18-47F6-B3BE-F173D4B0B269'),
    ('gremioHome', 'Grêmio (Home)', '2554E730-0627-4D58-B237-43B6D1AE0E76'),
    ('vascoDaGamaHome', 'Vasco da Gama (Home)', 'F695CD2B-6ED0-481D-923C-C7CE05995EA6'),
]

products = []
for raw, display, uid in teams:
    products.append({
        "displayPrice": "0.99",
        "familyShareable": False,
        "internalID": uid,
        "localizations": [
            {
                "description": f"Recolor the app with {display}'s team colors.",
                "displayName": f"{display} Theme",
                "locale": "en_US"
            }
        ],
        "productID": f"com.vibrito.br2026.theme.{raw}",
        "referenceName": f"{display} Theme",
        "type": "NonConsumable"
    })

doc = {
    "identifier": "9C6C4F55-6C63-4B7C-9C79-9D6B9F6F0D4C",
    "nonRenewingSubscriptions": [],
    "products": products,
    "settings": {
        "_applicationInternalID": "0",
        "_developerTeamID": "0",
        "_failTransactionsEnabled": False,
        "_lastSynchronizedDate": 0,
        "_locale": "en_US",
        "_storefront": "USA",
        "_storeKitErrors": [
            {"current": None, "emptyOnError": False, "enabled": False, "name": "Load Products"},
            {"current": None, "emptyOnError": False, "enabled": False, "name": "Purchase"},
            {"current": None, "enabled": False, "name": "Verification"},
            {"current": None, "enabled": False, "name": "App Store Sync"},
            {"current": None, "enabled": False, "name": "Subscription Status"},
            {"current": None, "enabled": False, "name": "App Transaction"},
            {"current": None, "enabled": False, "name": "Manage Subscriptions Sheet"},
            {"current": None, "enabled": False, "name": "Refund Request Sheet"},
            {"current": None, "enabled": False, "name": "Offer Code Redeem Sheet"}
        ]
    },
    "subscriptionGroups": [],
    "version": {"major": 3, "minor": 0}
}

with open('BR2026.storekit', 'w') as f:
    json.dump(doc, f, indent=2, ensure_ascii=False)
    f.write('\n')
PYEOF
```

Run from the repo root (`/Users/mlbbr-mac-vinicius/projects/footballWhiteLabel`).

- [ ] **Step 2: Verify the file is valid JSON with 20 products**

Run: `python3 -c "import json; d = json.load(open('BR2026.storekit')); print(len(d['products']))"`
Expected output: `20`

- [ ] **Step 3: Add the file to the Xcode project and enable it in the scheme (manual, Xcode GUI)**

This step can't be scripted safely (blind edits to `.pbxproj`/`.xcscheme` XML risk corrupting
the project file with no way to verify the result outside Xcode itself) — do it in Xcode:

1. In Xcode's Project Navigator, right-click the top-level `BR2026` project (or any group) →
   **Add Files to "BR2026"...** → select `BR2026.storekit` from the repo root → ensure
   **BR2026** target membership is *unchecked* (it's a scheme-level config, not a compiled
   resource) → Add.
2. **Product ▸ Scheme ▸ Edit Scheme...** (or ⌘<) → select the **Run** action → **Options** tab
   → **StoreKit Configuration** dropdown → select `BR2026.storekit`.
3. Repeat step 2 for the **Test** action's Options tab too, so `fastlane test`/`xcodebuild
   test` also runs against this configuration (relevant for the `BR2026UITests` target if a
   future UI test exercises the purchase flow — the Swift Testing unit tests in
   `BR2026Tests` don't need it, since they use `MockPurchaseService` exclusively).

- [ ] **Step 4: Commit**

```bash
git add BR2026.storekit
git commit -m "Add local StoreKit configuration for testing the purchase flow in Simulator"
```

(The scheme edit from Step 3 is a local Xcode user-state change under
`xcuserdata/`/`xcshareddata/` depending on how it's saved — if Xcode writes it to
`BR2026.xcodeproj/xcshareddata/xcschemes/BR2026.xcscheme` — a tracked, shared file — include
that in the same commit: `git add BR2026.xcodeproj/xcshareddata/xcschemes/BR2026.xcscheme`
before committing, so the StoreKit configuration is wired in for every clone of the repo, not
just this machine.)

---

### Task 9: Final verification

**Files:** none (verification only).

- [ ] **Step 1: Ask the user before running tests**

Per the Global Constraints, stop here and ask: "All 8 implementation tasks are done — want me
to build and run the full test suite now?" Do not proceed to Step 2 without an explicit yes.

- [ ] **Step 2: Run the full test suite (only after the user confirms)**

Run: `bundle exec fastlane test` (from the repo root, with `rbenv`'s shims on `PATH` — see
this project's established pattern: `export PATH="$(rbenv root)/shims:$PATH"` first if `ruby
-v` doesn't already report 3.2.2).
Expected: all tests pass, including the ~15 new/changed tests from Tasks 1, 3, and 4.

- [ ] **Step 3: Manual purchase-flow smoke test (optional, requires the user's own hands)**

Not scriptable — note it for the user rather than attempting it: with the `.storekit`
configuration from Task 8 active, run the app in Simulator, navigate to More → Team Theme, tap
a locked team, confirm Apple's sandbox purchase sheet appears and completes, confirm the theme
applies immediately after, then tap "Restore Purchases" and confirm previously-purchased teams
stay unlocked after deleting and reinstalling the app (Simulator: Device → Erase All Content
and Settings, or just delete+reinstall the app).
