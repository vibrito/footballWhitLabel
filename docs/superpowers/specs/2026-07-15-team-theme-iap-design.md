# Team Theme In-App Purchases Design

**Goal:** Gate the 20 already-built Team Theme colors (see
[[2026-07-14-palmeiras-team-theme-design]]) behind real per-team purchases, replacing the
hardcoded `TeamThemeOption.isPurchased == true` stub. This is the top-priority post-launch
roadmap item. Each team is its own $0.99 non-consumable In-App Purchase — no free team, no
bundle discount. A locked row shows a lock icon + localized price instead of the checkmark
slot; tapping it starts Apple's purchase sheet directly from the row. A "Restore Purchases"
button lives at the bottom of the picker screen, as required by App Store guidelines for
non-consumables.

**Architecture:** A new `PurchaseService` protocol (mirrors the existing `MatchService`
pattern) abstracts StoreKit 2's `Product`/`Transaction` APIs behind an interface two
implementations satisfy: `LivePurchaseService` (real StoreKit 2 calls) and
`MockPurchaseService` (used in all automated tests — no real StoreKit calls in the test
target, same principle as `MockMatchService`). A new `@Observable @MainActor`
`TeamPurchaseStore` (created once in `ChampionshipApp.init()`, threaded down alongside the
existing `themeStore`) owns purchased-team state, sourced from
`Transaction.currentEntitlements` — StoreKit's own persisted, cross-device-synced source of
truth, so no custom SwiftData cache is needed for entitlements (unlike match/standings data,
which genuinely needs an offline-first cache; purchase state doesn't — it's small, rare to
change, and StoreKit already keeps it current). `TeamThemeOption.isPurchased` is removed
entirely from the enum — purchase state is runtime data, not team metadata — and
`TeamPurchaseStore.isPurchased(_:)` replaces every call site.

---

## Product Catalog

One non-consumable IAP per `TeamThemeOption` case, 20 total, all priced at App Store
Connect's Tier 1 ($0.99 USD, localized per storefront by Apple).

**Product ID scheme:** `com.vibrito.br2026.theme.<rawValue>`, e.g.
`com.vibrito.br2026.theme.palmeirasHome`, `com.vibrito.br2026.theme.corinthiansHome`. Using
the enum's own `rawValue` keeps the product ID trivially derivable from the case
(`"com.vibrito.br2026.theme.\(option.rawValue)"`) with no separate mapping table to keep in
sync as teams are added.

**App Store Connect setup** (manual, outside this codebase — a checklist for whoever does the
setup, not a code task):
1. Create 20 non-consumable in-app purchases under the `com.vibrito.br2026` app record, one
   per product ID above, each priced at Tier 1.
2. Each needs a display name (team's `displayName`, e.g. "Palmeiras (Home)") and a review
   screenshot showing the purchase's effect — the existing Team Theme picker screen with that
   team selected works for all 20.
3. Submit for review alongside (or after) the app version that ships this feature — Apple
   reviews new IAPs together with the binary that references them the first time.

---

## Components

### `PurchaseService` (new protocol, `BR2026/Services/PurchaseService.swift`)

```swift
protocol PurchaseService {
    /// Fetches StoreKit `Product` metadata (price, display name) for the given product IDs.
    /// Keyed by product ID so callers can look up a specific team's price without re-parsing
    /// `Product.id`.
    func fetchProducts(productIDs: [String]) async throws -> [String: Product]

    /// Starts the purchase flow for one product. Returns `true` if the user now owns it
    /// (purchase completed and verified), `false` if they cancelled. Throws for actual
    /// failures (network, StoreKit errors, failed verification).
    func purchase(productID: String) async throws -> Bool

    /// Re-syncs entitlements from the App Store (the required "Restore Purchases" action).
    func restorePurchases() async throws

    /// The current set of owned product IDs, re-emitted whenever it changes (initial fetch,
    /// a purchase completes, a restore completes, or StoreKit delivers an update from
    /// another device/Family Sharing).
    var purchasedProductIDs: AsyncStream<Set<String>> { get }
}
```

### `LivePurchaseService` (new, `BR2026/Services/LivePurchaseService.swift`)

Real implementation using `StoreKit.Product.products(for:)`, `Product.purchase()`, and
`Transaction.currentEntitlements`/`Transaction.updates` (the StoreKit 2 async APIs — no
`SKPaymentQueue` delegate boilerplate needed). `purchase(productID:)`:
1. Looks up the already-fetched `Product` (fetched via `fetchProducts` first — the store
   always fetches products before offering them for purchase, so this is a dictionary lookup,
   not a second network round-trip).
2. Calls `product.purchase()`, switches on the result:
   - `.success(.verified(let transaction))`: calls `transaction.finish()`, returns `true`.
   - `.success(.unverified)`: throws (StoreKit's own receipt verification failed — treat as a
     failure, don't grant the entitlement).
   - `.userCancelled`: returns `false`.
   - `.pending`: returns `false` (Ask to Buy / parental approval — no entitlement yet; when it
     resolves later, `Transaction.updates` delivers it and `purchasedProductIDs` updates on
     its own with no further user action in this app).

`purchasedProductIDs` is backed by a `Task` that seeds from `Transaction.currentEntitlements`
once, then continues listening on `Transaction.updates` for the process lifetime, yielding
into the `AsyncStream` on every change.

### `MockPurchaseService` (new, `BR2026/Services/MockPurchaseService.swift`)

Test double, same role as `MockMatchService`:
```swift
final class MockPurchaseService: PurchaseService {
    private var purchased: Set<String>
    private let continuation: AsyncStream<Set<String>>.Continuation
    let stream: AsyncStream<Set<String>>
    /// When `true`, `purchase(productID:)` returns `false` (simulating a cancelled/failed
    /// purchase) instead of granting the entitlement — lets tests exercise the "purchase
    /// didn't go through" path in `TeamThemePickerViewModel.select(_:)`.
    var shouldFailNextPurchase = false

    init(purchasedProductIDs: Set<String> = []) {
        self.purchased = purchasedProductIDs
        (stream, continuation) = AsyncStream.makeStream()
    }

    func fetchProducts(productIDs: [String]) async throws -> [String: Product] { [:] }
    // returns [:] since real StoreKit `Product` values can't be constructed outside StoreKit
    // itself — see the Testing section for how price display is verified instead.

    func purchase(productID: String) async throws -> Bool {
        guard !shouldFailNextPurchase else { return false }
        purchased.insert(productID)
        continuation.yield(purchased)
        return true
    }

    func restorePurchases() async throws {
        continuation.yield(purchased)
    }

    var purchasedProductIDs: AsyncStream<Set<String>> { stream }
}
```

`fetchProducts` returning `[:]` is a real constraint: `StoreKit.Product` has no public
initializer, so a mock can't hand back a fake one. `TeamPurchaseStore.price(for:)` is
therefore left untested at the unit level — see the Testing section for how it's verified
instead.

### `TeamPurchaseStore` (new, `BR2026/Services/TeamPurchaseStore.swift`)

```swift
@Observable
@MainActor
final class TeamPurchaseStore {
    private(set) var purchasedTeamIDs: Set<String> = []
    private var products: [String: Product] = [:]
    private let service: PurchaseService
    private var hasLoadedOnce = false

    init(service: PurchaseService) { self.service = service }

    func loadOnce() async {
        guard !hasLoadedOnce else { return }
        hasLoadedOnce = true
        let productIDs = TeamThemeOption.allCases.map(\.productID)
        products = (try? await service.fetchProducts(productIDs: productIDs)) ?? [:]
        for await ids in service.purchasedProductIDs {
            purchasedTeamIDs = Set(ids.compactMap(TeamThemeOption.rawValue(fromProductID:)))
        }
    }

    func isPurchased(_ option: TeamThemeOption) -> Bool {
        purchasedTeamIDs.contains(option.rawValue)
    }

    func price(for option: TeamThemeOption) -> String? {
        products[option.productID]?.displayPrice
    }

    @discardableResult
    func purchase(_ option: TeamThemeOption) async -> Bool {
        (try? await service.purchase(productID: option.productID)) ?? false
    }

    func restorePurchases() async {
        try? await service.restorePurchases()
    }
}
```

`loadOnce()`'s `for await` loop runs for the store's lifetime (same one-shot-then-persistent
pattern as `TeamThemeStore.loadOnce()`/`MatchdayViewModel.loadOnce()` — see CLAUDE.md's
"Data & Persistence" section), so `purchasedTeamIDs` stays live for the whole app session
without polling.

### `TeamThemeOption` changes (`BR2026/Models/TeamThemeOption.swift`)

- Remove `var isPurchased: Bool { true }` entirely.
- Add `var productID: String { "com.vibrito.br2026.theme.\(rawValue)" }` and the reverse
  lookup `static func rawValue(fromProductID productID: String) -> String?` (strips the
  `"com.vibrito.br2026.theme."` prefix, used by `TeamPurchaseStore` to map StoreKit's
  purchased-product-ID set back to `TeamThemeOption` rawValues).

### `TeamThemePickerViewModel` changes

Gains a `purchaseStore: TeamPurchaseStore` dependency (constructor param, same shape as its
existing `themeStore`/`setting`). `select(_:)` becomes purchase-aware:
```swift
func select(_ option: TeamThemeOption?) async {
    guard option != selectedOption else { return }
    if let option, !purchaseStore.isPurchased(option) {
        guard await purchaseStore.purchase(option) else { return }  // cancelled/failed — stay on current selection
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
```
Also gains two thin pass-throughs the view reads directly, so the view never touches
`purchaseStore` itself: `func isPurchased(_ option: TeamThemeOption) -> Bool { purchaseStore.isPurchased(option) }`
and `func price(for option: TeamThemeOption) -> String? { purchaseStore.price(for: option) }`.
`select(nil)` (the "Default" row) is unaffected — it's always free, no purchase check.

### `TeamThemePickerView` changes

Each row (`rowView(_:)`) reads `viewModel.isPurchased(option)` (a small pass-through the view
model exposes) — if `false`, the trailing slot shows `Image(systemName: "lock.fill")` +
`Text(viewModel.price(for: option) ?? "")` instead of the checkmark, styled at the same
opacity as the row's other secondary text. Tapping the row still calls
`viewModel.select(option)` regardless of lock state — the view model itself decides whether a
purchase is needed, so the view doesn't branch on purchased-vs-not for the tap handler, only
for what it displays. A "Restore Purchases" `Button` is added below the `GlassCard`, calling
`viewModel.restorePurchases()`, styled as a plain text button (matches the existing
`errorMessage` `Text`'s treatment — small, secondary-opacity).

### DI wiring (`ChampionshipApp.swift`, `MoreView.swift`)

`ChampionshipApp.init()` builds `purchaseStore: TeamPurchaseStore` next to the existing
`themeStore`, using `LivePurchaseService()` (no config/API-key dependency — StoreKit needs no
setup parameters, unlike `LiveMatchService`). `ContentView` and `MoreView` each gain a
`purchaseStore: TeamPurchaseStore` pass-through parameter (same pattern as `themeStore`
today), terminating at `MoreView`'s inline construction of `TeamThemePickerViewModel`, which
now also takes `purchaseStore`. `ContentView.body` calls `.task { await purchaseStore.loadOnce() }`
alongside the existing `.task { await themeStore.loadOnce() }`.

---

## Data Flow

**Cold launch:** `ChampionshipApp.init()` constructs `TeamPurchaseStore` (empty
`purchasedTeamIDs`) → `ContentView.task` calls `loadOnce()` → fetches all 20 `Product`s,
then starts consuming `Transaction.currentEntitlements` → `purchasedTeamIDs` populates →
`TeamThemePickerView` (once navigated to) renders lock icons only for teams not in that set.
Because `Transaction.currentEntitlements` reflects prior purchases immediately (no network
round-trip needed for entitlements the device already knows about from the receipt), a
returning user who reinstalls sees their prior purchases unlocked without doing anything.

**Purchase:** user taps a locked row → `TeamThemePickerViewModel.select(option)` →
`purchaseStore.purchase(option)` → `LivePurchaseService.purchase(productID:)` → Apple's native
purchase sheet → on success, `Transaction.updates` fires → `purchasedTeamIDs` updates → the
same `select` call proceeds to `themeStore.select(option)`, applying the theme immediately
after a successful purchase (no second tap needed).

**Restore:** user taps "Restore Purchases" → `TeamThemePickerViewModel.restorePurchases()` →
`purchaseStore.restorePurchases()` → `LivePurchaseService.restorePurchases()` calls
`AppStore.sync()` → `Transaction.updates` re-fires for anything restored → `purchasedTeamIDs`
updates → previously-locked rows the user owns on this Apple ID unlock without an app
relaunch.

---

## Error Handling

- **Purchase fails (network, StoreKit error, unverified transaction):** `purchase(_:)`
  returns `false` via the `try?` in `TeamPurchaseStore.purchase(_:)` — the row stays locked,
  no destructive state change. The existing `errorMessage` mechanism isn't triggered for a
  failed *purchase* specifically (StoreKit already surfaces its own native alert for payment
  failures) — it's reserved for the theme-application failure path that already exists.
- **User cancels the purchase sheet:** treated identically to a purchase failure (`false`,
  stay locked) — cancelling isn't an error state worth surfacing.
- **`restorePurchases()` fails:** silently no-ops (`try?`) — there's nothing new to unlock if
  it fails and nothing was in a broken state before the tap, so no error UI is needed here
  either; the user can just tap Restore again.
- **`fetchProducts` fails at launch** (e.g. offline): `TeamPurchaseStore.products` stays
  empty, `price(for:)` returns `nil` for every team, and the picker shows a lock icon with no
  price text rather than crashing or blocking the screen — purchasing simply won't succeed
  until products are fetched (StoreKit's own purchase call would fail without a fetched
  `Product`), consistent with this app's existing "degrade gracefully when offline" pattern
  for match/standings data.

---

## Testing

- `TeamPurchaseStoreTests.swift` (new): uses `MockPurchaseService`, asserts `loadOnce()`
  populates `purchasedTeamIDs` from the mock's initial set, `purchase(_:)` adds to it,
  `isPurchased(_:)` reflects membership correctly for both purchased and unpurchased teams.
- `TeamThemeOptionTests.swift`: add coverage for `productID` (matches the
  `"com.vibrito.br2026.theme.<rawValue>"` scheme for all 20 cases) and
  `rawValue(fromProductID:)` (round-trips correctly, returns `nil` for a malformed/foreign
  product ID).
- `TeamThemePickerViewModelTests.swift`: extend by constructing a real `TeamPurchaseStore`
  over `MockPurchaseService` (matching how `TeamThemeStoreTests` already constructs a real
  `TeamThemeStore` over `StubMatchService`) to verify `select(_:)` on a locked team triggers a
  purchase before applying the theme, and that a failed/cancelled purchase leaves
  `selectedOption` unchanged.
- Price display (`price(for:)`) is deliberately **not** unit-tested against real `Product`
  values, since `Product` has no public initializer — this is a known StoreKit 2 testing
  limitation, not an oversight. Manual verification uses the `.storekit` configuration file
  below in the iOS Simulator, which *does* let Xcode synthesize real `Product` instances
  end-to-end.

**Local StoreKit testing:** a `BR2026.storekit` configuration file (Xcode's StoreKit Testing
feature) is added to the project, declaring all 20 non-consumable products with placeholder
$0.99 pricing, and wired into the `BR2026` scheme's Run configuration
(Options → StoreKit Configuration). This lets the full purchase/restore flow — including
Apple's real (sandboxed, on-device) purchase sheet UI — be exercised in Simulator without
App Store Connect being configured yet, and without spending real money during development.

---

## Out of Scope

- **Other championship targets** (Premier League, Ligue 1, Liga Portugal): Team Theme itself
  is still Brasileirão-only (see CLAUDE.md's Scope section) — this IAP work only ships in the
  `BR2026` target, gated the same way the picker's "Team Theme" row already is in
  `MoreViewModel`.
- **Promotional offers, introductory pricing, subscription-style themes:** not requested;
  every product is a plain one-time non-consumable at a flat price.
- **A dedicated paywall/marketing screen:** the picker row itself is the only purchase entry
  point (per the "price button + lock icon" decision) — no separate upsell screen.
- **Family Sharing configuration nuances:** StoreKit 2's `Transaction.currentEntitlements`
  already reflects Family Sharing-shared purchases automatically once Family Sharing is
  enabled for the non-consumables in App Store Connect (a checkbox there, not a code change)
  — no app code branches on Family Sharing specifically.
