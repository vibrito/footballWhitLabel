# Team Icon In-App Purchases Design

**Goal:** Add the 20 team-specific alternate app icons found in `design/BR2026/` (one per
team already in [[2026-07-14-palmeiras-team-theme-design]]/`TeamThemeOption`) as purchasable
options in the App Icon picker, each its own $0.99 non-consumable IAP, **separate** from that
team's Team Theme purchase — a user can own a team's colors without its icon, or vice versa.
Mirrors the [[2026-07-15-team-theme-iap-design]] purchase-gating pattern (lock icon + price,
tap-to-purchase, Restore Purchases) rather than inventing a new one.

**Architecture:** The existing `PurchaseService`/`LivePurchaseService`/`MockPurchaseService`
layer is already generic over raw StoreKit product IDs and needs **no changes** — it's reused
as-is. The one piece of Team Theme's IAP work that *is* type-specific,
`TeamPurchaseStore`, is generalized into `PurchaseStore<Option: PurchasableCatalogOption>` so
both the Team Theme and Team Icon catalogs share one implementation instead of two
near-identical copies. A new `TeamIconOption` enum (structurally a twin of `TeamThemeOption`)
catalogs the 20 purchasable icons; the existing free `AppIconOption` (Default, Stadium) is
untouched. `AppIconPickerView` grows from a 2-row list to Default + Stadium (always free) +
the 20 team icons (purchased-first, then by league standings position — matching the Team
Theme picker).

---

## Product Catalog

One non-consumable IAP per `TeamIconOption` case, 20 total, Tier 1 ($0.99 USD).

**Product ID scheme:** `com.vibrito.br2026.icon.<rawValue>`, e.g.
`com.vibrito.br2026.icon.palmeiras`, `com.vibrito.br2026.icon.corinthians` — same derivation
pattern as Team Theme's `com.vibrito.br2026.theme.<rawValue>`, just a different literal
prefix and no `Home` suffix in the raw values (see `TeamIconOption` below).

**App Store Connect setup** (manual, outside this codebase):
1. Create 20 non-consumable in-app purchases under the `com.vibrito.br2026` app record, one
   per product ID above, each priced at Tier 1.
2. Each needs a display name (e.g. "Palmeiras Icon") and a review screenshot showing the
   purchase's effect — the App Icon picker screen with that icon selected works for all 20.
3. Submit for review alongside the app version that ships this feature, same as Team Theme's
   products were.

---

## Components

### `PurchasableCatalogOption` (new protocol, `BR2026/Models/PurchasableCatalogOption.swift`)

The minimal shape `PurchaseStore` needs from any purchasable catalog:

```swift
protocol PurchasableCatalogOption: CaseIterable, Hashable {
    var rawValue: String { get }
    var productID: String { get }
    static func rawValue(fromProductID productID: String) -> String?
}
```

Both `TeamThemeOption` and `TeamIconOption` already have (or will have) exactly this shape —
`RawRepresentable where RawValue == String` satisfies `rawValue` for free, so conformance for
both is just `extension TeamThemeOption: PurchasableCatalogOption {}` /
`extension TeamIconOption: PurchasableCatalogOption {}` plus their existing `productID`/
`rawValue(fromProductID:)` members.

### `PurchaseStore<Option>` (renamed/generalized from `TeamPurchaseStore`, same file path
`BR2026/Services/TeamPurchaseStore.swift` renamed to `BR2026/Services/PurchaseStore.swift`)

```swift
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

Body is byte-for-byte what `TeamPurchaseStore` does today (including the pull-based
`currentPurchasedProductIDs()` design already in place, not the superseded `AsyncStream`
sketch from the Team Theme spec) — only the type parameter and the `purchasedTeamIDs` →
`purchasedIDs` rename (no longer team-specific) change. `TeamThemeStore` (the *color* store,
unrelated to purchases despite the similar name) is untouched.

**Call sites that retype `TeamPurchaseStore` → `PurchaseStore<TeamThemeOption>`:**
`ChampionshipApp.swift`, `ContentView.swift`, `MoreView.swift`,
`TeamThemePickerViewModel.swift`, and existing tests
(`TeamPurchaseStoreTests.swift` → asserts against `PurchaseStore<TeamThemeOption>`).

### `TeamIconOption` (new, `BR2026/Models/TeamIconOption.swift`)

Structural twin of `TeamThemeOption`, always fully declared for every championship target
(same reasoning as `TeamThemeOption` — a zero-case `enum ...: String` fails to compile, and
gating individual cases would leave other targets with none at all; visibility is gated at
the UI layer instead, via the same `#if` pattern `MoreViewModel` already uses for the "Team
Theme" row).

```swift
enum TeamIconOption: String, CaseIterable, Identifiable {
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

    /// Same live-API team IDs `TeamThemeOption.teamID` uses — reused directly (both catalogs
    /// describe the same 20 real-world teams) so the App Icon picker can sort by the same
    /// standings data without a second ID mapping to maintain.
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

    /// The App Icon Set name for `UIApplication.setAlternateIconName(_:)`.
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

`displayName` text matches `TeamThemeOption.displayName` exactly (both already dropped the
"(Home)" suffix — see the earlier "Remove the (home) for all teams" change) so the same team
reads identically in both pickers. `iconAssetName`/`previewImageName` derive the asset name
by capitalizing the raw value's first letter rather than a full switch (20 fewer duplicate
strings to keep in sync with the enum cases); this only works because every raw value here is
a valid capitalized-identifier-minus-first-letter — verified against all 20 cases above.

### `AppIconPickerViewModel` changes

Selection state stops being a matched `AppIconOption` and becomes the raw setting value
directly — `iconSetting.currentIconName` already **is** the value both `AppIconOption.
iconAssetName` and `TeamIconOption.iconAssetName` compare against, so there's no need to
re-derive a typed "currently selected option" at all:

```swift
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

    /// Same cached-then-refresh pattern as `TeamThemePickerViewModel.loadOnce()`.
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

Two `select` overloads (one per option type) rather than a union type — Swift resolves the
correct one from each row's static call site, so the view never needs to branch on which kind
of option it's rendering.

### `AppIconPickerView` changes

One continuous list inside the existing `GlassCard`: `AppIconOption.allCases` render first
(unchanged rows, `viewModel.isSelected(option)` replaces the old `viewModel.selectedIcon ==
option` check), then a divider, then `viewModel.sortedTeamOptions` render with the same
locked-row treatment `TeamThemePickerView` uses (`lock.fill` + `price(for:)` when
`!isPurchased`, checkmark when `isSelected`). A "Restore Purchases" `Button` is added below
the `GlassCard`, identical in style to Team Theme picker's, calling
`viewModel.restorePurchases()`. `.task { await viewModel.loadOnce() }` is added (wasn't
needed before — nothing was ever fetched).

### DI wiring (`ChampionshipApp.swift`, `ContentView.swift`, `MoreView.swift`)

`ChampionshipApp.init()` gains `iconPurchaseStore: PurchaseStore<TeamIconOption>`, built from
the same `LivePurchaseService()` instance the theme purchase store already uses (one
`PurchaseService` backs both catalogs — StoreKit itself distinguishes products by ID, so
sharing the service is safe). `ContentView` and `MoreView` each gain an
`iconPurchaseStore: PurchaseStore<TeamIconOption>` pass-through parameter, terminating at
`MoreView`'s construction of `AppIconPickerViewModel`. `ContentView.body` gains
`.task { await iconPurchaseStore.loadOnce() }` alongside the existing theme/icon-unrelated
`.task`s.

---

## Asset Pipeline

For each of the 20 `TeamIconOption` cases, two new asset catalog entries are generated (by a
one-off script during implementation, not hand-built — same approach used when the Brasil
icon was removed):

- `AppIcon-<Team>.appiconset/` — `Contents.json` (single `1024x1024` universal image, same
  shape as `AppIcon-Stadium.appiconset/Contents.json`) + the corresponding
  `design/BR2026/AppIcon-*-1024.png` copied in as `AppIcon-<Team>-1024.png`.
- `AppIconPreview-<Team>.imageset/` — `Contents.json` (single `1x` scale, same shape as
  `AppIconPreview-Stadium.imageset/Contents.json`) + the same source PNG copied in as
  `AppIconPreview-<Team>.png`.

The destination `<Team>` token is always the enum-derived name (`rawValue` capitalized —
matches `iconAssetName`/`previewImageName` above), **not** the source filename — 17 of the 20
source filenames already match that token, but 3 don't and need an explicit source→
destination mapping:

| `TeamIconOption` case | Source file in `design/BR2026/` | Destination token |
|---|---|---|
| `.athleticoParanaense` | `AppIcon-1n-AthleticoPR-1024.png` | `AthleticoParanaense` |
| `.redBullBragantino` | `AppIcon-1o-Bragantino-1024.png` | `RedBullBragantino` |
| `.vascoDaGama` | `AppIcon-1u-Vasco-1024.png` | `VascoDaGama` |

Every other case's source file already ends in `<Token>-1024.png` where `<Token>` is exactly
the destination token (e.g. `AppIcon-1k-Palmeiras-1024.png` → `Palmeiras`).

`ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` (both Debug and Release configs, `BR2026`
target only) grows from `"AppIcon-Stadium"` to a space-separated list of all 21 alternate
names (`AppIcon-Stadium` + the 20 new `AppIcon-<Team>` names).

`BR2026.storekit` gains 20 more product entries (`type: NonConsumable`, `displayPrice:
"0.99"`, `productID: com.vibrito.br2026.icon.<rawValue>`), same shape as the existing 20
theme entries, for local Simulator purchase-flow testing.

---

## Data Flow

Identical shape to Team Theme's, with `TeamIconOption`/`PurchaseStore<TeamIconOption>` in
place of `TeamThemeOption`/`TeamPurchaseStore`, and "apply an icon" (`applyIconName`) in place
of "apply a color theme":

**Cold launch:** `ChampionshipApp.init()` constructs an empty `PurchaseStore<TeamIconOption>`
→ `ContentView.task` calls `loadOnce()` → fetches all 20 icon `Product`s and current
entitlements → `AppIconPickerView` (once navigated to) renders lock icons only for
not-yet-owned teams.

**Purchase:** tap a locked team icon row → `AppIconPickerViewModel.select(TeamIconOption)` →
`purchaseStore.purchase(option)` → Apple's native purchase sheet → on success, the same call
proceeds to `applyIconName`, setting the icon immediately (no second tap).

**Restore:** tap "Restore Purchases" → `purchaseStore.restorePurchases()` → previously-locked
rows the user owns on this Apple ID unlock without a relaunch.

---

## Error Handling

Same as Team Theme's (see [[2026-07-15-team-theme-iap-design]]'s Error Handling section) —
failed/cancelled purchases leave the row locked with no destructive state change and no
custom error UI (StoreKit surfaces its own alerts); `applyIconName` failures use the existing
`errorMessage` mechanism (already present for the Default/Stadium path today); an offline
`fetchProducts` failure leaves `price(for:)` returning `nil`, showing a lock icon with no
price rather than blocking the screen.

---

## Testing

- `TeamIconOptionTests.swift` (new): `productID` matches the
  `com.vibrito.br2026.icon.<rawValue>` scheme for all 20 cases; `rawValue(fromProductID:)`
  round-trips and returns `nil` for a foreign ID; `iconAssetName`/`previewImageName` produce
  the expected capitalized asset names for all 20 cases (guards the "derive, don't switch"
  choice above against a future case whose raw value doesn't capitalize cleanly).
- `PurchaseStoreTests.swift` (renamed from `TeamPurchaseStoreTests.swift`): existing five
  tests retyped to `PurchaseStore<TeamThemeOption>`, plus the same five re-run against
  `PurchaseStore<TeamIconOption>` (two `@Suite`s in the same file, sharing no code — Swift
  Testing doesn't parametrize suites over types, and duplicating five short tests is cheaper
  than building a generic-test-suite mechanism for it).
- `AppIconPickerViewModelTests.swift`: extend with a real `PurchaseStore<TeamIconOption>`
  over `MockPurchaseService` (matching how `TeamThemePickerViewModelTests` already constructs
  a real `TeamPurchaseStore`) — `select(TeamIconOption)` on a locked team triggers a purchase
  before applying the icon; a failed/cancelled purchase leaves `selectedIconAssetName`
  unchanged; `sortedTeamOptions` orders purchased-first then by standings, matching
  `TeamThemePickerViewModelTests`' coverage; `loadOnce()` fetches standings once.
- Price display is untested at the unit level for the same reason as Team Theme's — `Product`
  has no public initializer. Manual verification uses `BR2026.storekit` in Simulator.

---

## Out of Scope

- **Other championship targets:** ships in `BR2026` only, gated at the UI layer the same way
  Team Theme's "Team Theme" row is gated in `MoreViewModel` — a corresponding gate is added
  for wherever `AppIconPickerView`'s team-icon section is rendered, so Premier League/Ligue 1/
  Liga Portugal builds show only Default/Stadium, unchanged from today.
- **Bundling with Team Theme purchases:** confirmed separate — owning a team's theme grants
  nothing toward its icon and vice versa.
- **A dedicated paywall/marketing screen:** the picker row itself is the only purchase entry
  point, same as Team Theme.
- **Family Sharing configuration nuances:** same as Team Theme — a checkbox in App Store
  Connect, not an app code concern.
