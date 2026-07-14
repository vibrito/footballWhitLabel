# Palmeiras Team Theme (IAP Themes Proof of Concept) Design

**Goal:** Let the user recolor the whole app to Palmeiras's real kit colors — background
gradient, ambient glow blobs, `HeroMatchCard`'s border, the app's accent (tab tint/`LiveChip`/
`AccentPill`), and all body text — sourced live from the API's
`GET /v4/competitions/{code}/teams/{id}/colors` endpoint. This is the first slice of the
top-priority post-launch roadmap item, **in-app-purchase team themes** (icon/colors/hero-card,
purchasable per team): this pass builds the *theming mechanism* end-to-end for one hardcoded
team (Palmeiras, BSA team id `121`), with the purchase gate stubbed as always-unlocked. Custom
per-team app icons, a purchasable catalog of multiple teams, and real StoreKit 2 purchasing are
explicitly out of scope — separate follow-ups once this mechanism is proven and icon assets
exist.

**Wire shape (confirmed live)**, `GET /v4/competitions/BSA/teams/121/colors`:
```json
{
  "team": {"id": 121, "name": "Palmeiras"},
  "home": {"fontColor": "ffffff", "mainColor": "225638", "secondaryColor": "225638", "matchesConsidered": 15},
  "away": {"fontColor": "035336", "mainColor": "ffffff", "secondaryColor": "ffffff", "matchesConsidered": 1},
  "third": {"fontColor": "2c5434", "mainColor": "ffffff", "secondaryColor": "ffffff", "matchesConsidered": 1}
}
```
Only `home.mainColor` and `home.fontColor` are used — there is no per-match home/away context in
this feature (it's a fixed app-wide theme, not a match-specific treatment), and `secondaryColor`/
`matchesConsidered`/`away`/`third` have no consumer in this pass.

**Architecture:** A new `TeamThemeStore` (`@Observable @MainActor`, created once in
`ChampionshipApp.swift` next to `config`/`service`) owns whether the Palmeiras theme is selected
(persisted via `UserDefaults`) and its resolved colors (fetched through a new `MatchService`
method, cached in SwiftData). It exposes one `ThemeTokens` value — always fully resolved,
defaulting to today's exact fixed values when no theme is active — injected once into the
environment at `ContentView`. Every consumer (background, hero card, and the many `.white`-based
text call sites app-wide) reads `@Environment(\.themeTokens)` instead of a literal color, so no
per-file service/config plumbing is needed beyond this one environment value. **The 4 already-
shipped apps must render pixel-identical to today when no theme is selected** — this is the
central constraint every default value in this design is built around.

## Data & Service

### Model

`BR2026/Models/TeamThemeColors.swift` (new, plain struct — not SwiftData):
```swift
struct TeamThemeColors: Codable, Equatable {
    let mainColorHex: String
    let fontColorHex: String
}

struct TeamThemeColorsResponse: Decodable {
    let home: HomeKitColorsDTO

    struct HomeKitColorsDTO: Decodable {
        let fontColor: String
        let mainColor: String
    }
}

extension TeamThemeColors {
    init(response: TeamThemeColorsResponse) {
        self.init(mainColorHex: response.home.mainColor, fontColorHex: response.home.fontColor)
    }
}
```
`TeamThemeColorsResponse` only declares the keys this feature reads (`Decodable` ignores unknown
JSON keys, so `away`/`third`/`secondaryColor`/`matchesConsidered`/`team` are simply skipped).

`BR2026/Models/TeamThemeColorCache.swift` (new, SwiftData — mirrors `TeamCrestCache.swift`):
```swift
@Model
final class TeamThemeColorCache {
    @Attribute(.unique) var teamID: Int
    var mainColorHex: String
    var fontColorHex: String
    var cachedAt: Date

    init(teamID: Int, mainColorHex: String, fontColorHex: String, cachedAt: Date = Date()) {
        self.teamID = teamID
        self.mainColorHex = mainColorHex
        self.fontColorHex = fontColorHex
        self.cachedAt = cachedAt
    }
}
```
No TTL check (unlike `Competition`'s 7-day refresh) — kit colors don't change like scores do, so
once cached for a `teamID` it's reused forever, same reasoning as crest images.

Added to `ChampionshipApp.swift`'s `ModelContainer(for:)` list.

### Service

`MatchService` protocol gains:
```swift
func fetchTeamThemeColors(teamID: Int) async throws -> TeamThemeColors
func cachedTeamThemeColors(teamID: Int) -> TeamThemeColors?
```

`LiveMatchService`:
```swift
func fetchTeamThemeColors(teamID: Int) async throws -> TeamThemeColors {
    let url = config.apiBaseURL
        .appendingPathComponent("v4/competitions/\(config.competitionCode)/teams/\(teamID)/colors")
    let response: TeamThemeColorsResponse = try await get(url)
    let colors = TeamThemeColors(response: response)
    try modelContext.delete(model: TeamThemeColorCache.self, where: #Predicate { $0.teamID == teamID })
    modelContext.insert(TeamThemeColorCache(teamID: teamID, mainColorHex: colors.mainColorHex, fontColorHex: colors.fontColorHex))
    try modelContext.save()
    return colors
}

func cachedTeamThemeColors(teamID: Int) -> TeamThemeColors? {
    let descriptor = FetchDescriptor<TeamThemeColorCache>(predicate: #Predicate { $0.teamID == teamID })
    guard let cached = try? modelContext.fetch(descriptor).first else { return nil }
    return TeamThemeColors(mainColorHex: cached.mainColorHex, fontColorHex: cached.fontColorHex)
}
```

`MockMatchService`: returns Palmeiras's real known values with no network/cache —
`TeamThemeColors(mainColorHex: "225638", fontColorHex: "ffffff")` — for both `fetchTeamThemeColors`
and `cachedTeamThemeColors`.

## Theme State & Tokens

`BR2026/Models/ThemeTokens.swift` (new, plain struct):
```swift
struct ThemeTokens: Equatable {
    var overrideAccentColor: Color?          // nil = no theme active
    var textColor: Color = .white
    var gradientStops: [Color] = StadiumBackground.defaultGradientStops
    var blobColors: (top: Color, bottom: Color) = StadiumBackground.defaultBlobColors
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
`overrideAccentColor` is deliberately optional (not a concrete color defaulting to something
visible) because it drives two different defaults depending on the consumer:
- `ContentView`'s `.tint(...)` falls back to `Color(hex: config.accentColorHex)` when nil — the
  existing per-championship brand accent, unchanged from today.
- `HeroMatchCard`'s new border falls back to `.clear` when nil — no border, unchanged from today.

A single `nil` correctly encodes "theme inactive" for both without needing two separate fields
with contradictory defaults.

`BR2026/Services/TeamThemeStore.swift` (new, `@Observable @MainActor`):
```swift
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
        guard setting.selectedThemeID == TeamThemeOption.palmeiras.rawValue else { return }
        await apply(.palmeiras)
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
        guard let colors = await resolveColors(teamID: option.teamID) else { return false }
        setting.setSelectedThemeID(option.rawValue)
        tokens = ThemeTokens.themed(mainColorHex: colors.mainColorHex, fontColorHex: colors.fontColorHex)
        return true
    }

    private func apply(_ option: TeamThemeOption) async {
        guard let colors = await resolveColors(teamID: option.teamID) else { return }
        tokens = ThemeTokens.themed(mainColorHex: colors.mainColorHex, fontColorHex: colors.fontColorHex)
    }

    private func resolveColors(teamID: Int) async -> TeamThemeColors? {
        if let cached = service.cachedTeamThemeColors(teamID: teamID) { return cached }
        return try? await service.fetchTeamThemeColors(teamID: teamID)
    }
}
```
`loadOnce()` (restoring a persisted selection at launch) uses `apply(_:)`, which leaves `tokens`
at its current value on failure — there's no user-facing action to fail at launch, so it silently
retries on the next `select()` or relaunch. `select(_:)` (a live user action from the picker) uses
the stricter form above so `TeamThemePickerViewModel` can surface a failure, mirroring
`AppIconPickerViewModel`'s `errorMessage` pattern.

`ThemeTokens.themed(mainColorHex:fontColorHex:)` is a static factory that builds the "active"
token set: `overrideAccentColor = Color(hex: mainColorHex)`, `textColor = Color(hex: fontColorHex)`,
`gradientStops` derived from `mainColorHex` (see below), `blobColors` both `Color(hex:
mainColorHex)` (reusing today's existing 0.4/0.32 opacities, applied at the point of rendering,
not baked into the token).

**Gradient derivation** (`Color` extension, new): lighten `mainColorHex` toward white for the top
stop, use it as-is (or a light darken) for the middle stop, and darken it toward near-black for
the bottom stop — same light-to-dark structure as today's fixed
`#173a68 → #0b2143 → #061325`, just recolored. Implemented as simple linear RGB interpolation
toward white/black (no HSB precision needed — this is a stylistic backdrop, not brand-critical
color matching).

`TeamThemeOption` (new, mirrors `AppIconOption`'s per-target gating exactly):
```swift
enum TeamThemeOption: String, CaseIterable, Identifiable {
    #if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA)
    case palmeiras
    #endif

    var id: String { rawValue }

    var teamID: Int {
        switch self {
        #if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA)
        case .palmeiras: 121
        #endif
        }
    }

    var displayName: LocalizedStringResource {
        switch self {
        #if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA)
        case .palmeiras: "Palmeiras"
        #endif
        }
    }

    /// Stubbed always-true until real StoreKit 2 entitlement checking replaces this — the seam
    /// a future purchase-flow change plugs into.
    var isPurchased: Bool { true }
}
```

`TeamThemeSetting` protocol + `UserDefaultsTeamThemeSetting` (mirrors `AppIconSetting`):
```swift
@MainActor
protocol TeamThemeSetting {
    var selectedThemeID: String? { get }
    func setSelectedThemeID(_ id: String?)
}

@MainActor
final class UserDefaultsTeamThemeSetting: TeamThemeSetting {
    private let defaults: UserDefaults
    private let key = "selectedTeamThemeID"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var selectedThemeID: String? { defaults.string(forKey: key) }

    func setSelectedThemeID(_ id: String?) {
        defaults.set(id, forKey: key)
    }
}
```

### App wiring

`ChampionshipApp.swift`: constructs `TeamThemeStore` once (same place `config`/`service` are
built), passes it to `ContentView`:
```swift
let themeStore = TeamThemeStore(setting: UserDefaultsTeamThemeSetting(), service: makeService())
...
ContentView(config: config, service: service, themeStore: themeStore)
```

`ContentView`:
```swift
struct ContentView: View {
    let config: ChampionshipConfig
    let service: MatchService
    let themeStore: TeamThemeStore

    var body: some View {
        TabView { /* unchanged */ }
        .tint(themeStore.tokens.overrideAccentColor ?? Color(hex: config.tabSelectionColorHex))
        .background(StadiumBackground())
        .environment(\.themeTokens, themeStore.tokens)
        .task { await themeStore.loadOnce() }
    }
}
```
Each tab's own `.tint(Color(hex: config.accentColorHex))` similarly becomes
`.tint(themeStore.tokens.overrideAccentColor ?? Color(hex: config.accentColorHex))`.

Setting `.environment(\.themeTokens, ...)` once here cascades into all 8 existing
`StadiumBackground()` call sites and every screen's text — `MatchdayView`/`FixturesView`/
`StandingsView`/`MoreView` as direct `TabView` children, `MatchDetailView` as a `.sheet` from
within those tabs, and `AppIconPickerView`/`TermsOfServiceView`/the new `TeamThemePickerView` as
`NavigationStack` pushes from `MoreView` — all are descendants of `ContentView`'s environment, so
none of these call sites need code changes to *receive* the token, only to *use* it.

## UI Changes

### `StadiumBackground`

```swift
struct StadiumBackground: View {
    @Environment(\.themeTokens) private var themeTokens

    static let defaultGradientStops = [Color(hex: "#173a68"), Color(hex: "#0b2143"), Color(hex: "#061325")]
    static let defaultBlobColors: (top: Color, bottom: Color) = (Color(hex: "#173a68"), Color(red: 45/255, green: 212/255, blue: 191/255))

    var body: some View {
        ZStack {
            RadialGradient(colors: themeTokens.gradientStops, center: .top, startRadius: 0, endRadius: 700)
            Circle().fill(themeTokens.blobColors.top.opacity(0.4)) /* same frame/blur/offset as today */
            Circle().fill(themeTokens.blobColors.bottom.opacity(0.32)) /* same frame/blur/offset as today */
        }
        .ignoresSafeArea()
    }
}
```
When no theme is active, `themeTokens` is the environment's `defaultValue` (`ThemeTokens()`),
whose `gradientStops`/`blobColors` are these same `static let` defaults — today's exact look,
byte-for-byte.

### `HeroMatchCard`

Adds a border/glow, invisible by default:
```swift
GlassCard(cornerRadius: 28, style: .transparent) { /* unchanged content */ }
    .overlay(
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .strokeBorder(themeTokens.overrideAccentColor ?? .clear, lineWidth: 1.5)
    )
```
(Reads `@Environment(\.themeTokens)` the same way `StadiumBackground` does.) No glow/shadow beyond
the border for this pass — kept minimal since it's invisible for every shipped app by default and
this is a proof of concept, not a final visual treatment.

### App-wide text color

Every `.foregroundStyle(.white)` / `.foregroundStyle(.white.opacity(x))` in Views and Components
(`HeroMatchCard`, `FixtureMatchCard`, `ScoreRow`, `TeamCrestBadge`, `MatchdayView`, `FixturesView`,
`StandingsView`, `MoreView`, `MatchDetailView`, `TermsOfServiceView`, `AppIconPickerView`, and any
others found during implementation) is replaced with a `@Environment(\.themeTokens) private var
themeTokens` read and `themeTokens.textColor.opacity(x)` in place of the literal `.white`. This
does **not** touch `LiveChip`/`AccentPill` (they already derive their color from `Color.accentColor`
via SwiftUI's `.tint()` environment, which is separately covered by `overrideAccentColor` above) or
any place already reading a non-white color (e.g. `advance`/`playoff` status colors, dimmed-state
opacities layered on top of the base token). The exhaustive file list is an implementation-time
concern, not a design-time one — the mechanism (one environment read, same opacity literal, new
base color) is identical at every call site.

## More Screen: Team Theme Picker

`MoreDestination` gains a case:
```swift
enum MoreDestination: Hashable {
    case termsOfService
    case appIconPicker
    case teamThemePicker
}
```

`MoreViewModel`'s `preferences` section gains a second row, gated by the same compiler flag as
`TeamThemeOption`/`AppIconOption`'s Brasileirão-only options:
```swift
MoreRow(
    id: "teamTheme",
    titleKey: "Team Theme",
    systemImage: "paintpalette",
    destination: .teamThemePicker,
    isEnabled: true
)
```

`BR2026/ViewModels/TeamThemePickerViewModel.swift` (new, mirrors `AppIconPickerViewModel`):
```swift
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

`BR2026/Views/More/TeamThemePickerView.swift` (new) — a `GlassCard`-wrapped list: a "Default"
row (no theme) plus one row per `TeamThemeOption.allCases` (just Palmeiras today), each showing
`option.displayName`, a color swatch, a checkmark on `viewModel.selectedOption`, and a lock icon
if `!option.isPurchased` (always unlocked for now, so never shown) — tapping calls `await
viewModel.select(option)`. Mirrors `AppIconPickerView`'s layout/interaction pattern.

`MoreView`'s `navigationDestination` gains:
```swift
case .teamThemePicker:
    TeamThemePickerView(
        viewModel: TeamThemePickerViewModel(themeStore: themeStore, setting: UserDefaultsTeamThemeSetting())
    )
```
(`MoreView` gains a `themeStore: TeamThemeStore` parameter, passed from `ContentView` alongside
`service`.)

## Testing

- `TeamThemeStoreTests.swift` (new): `loadOnce()` with no persisted selection leaves `tokens ==
  ThemeTokens()` (today's defaults); with a persisted `"palmeiras"` selection, resolves tokens
  from `MockMatchService`'s canned colors; `select(.palmeiras)` then `select(nil)` returns to
  default tokens; `select` persists via a stub `TeamThemeSetting` only on success; a stub service
  whose `fetchTeamThemeColors`/`cachedTeamThemeColors` both fail makes `select()` return `false`
  and leaves `tokens`/the persisted id unchanged.
- `TeamThemePickerViewModelTests.swift` (new): initial `selectedOption` derived correctly from a
  stubbed `TeamThemeSetting`; `select()` updates both the view model and delegates to
  `TeamThemeStore`; re-selecting the current option is a no-op; `select()` sets `errorMessage` and
  leaves `selectedOption` unchanged when `TeamThemeStore.select` returns `false`.
- `MockMatchServiceTests.swift`: new case asserting `fetchTeamThemeColors`/`cachedTeamThemeColors`
  both return the canned Palmeiras values.
- No snapshot/UI tests for the text-color sweep or gradient derivation — Views aren't unit tested
  per CLAUDE.md; verified manually in Simulator (default look unchanged, Palmeiras theme applies
  correctly) as part of implementation.

## Documentation

CLAUDE.md updates:
- **Backend API**: add `GET /v4/competitions/{code}/teams/{id}/colors`.
- **Data & Persistence**: note `TeamThemeColorCache` alongside the existing crest-cache pattern
  (cached indefinitely, no TTL).
- **Assets** or a new **Theming** section: document `ThemeTokens`/`TeamThemeStore` as the
  mechanism future team themes (and eventually per-team icons) plug into.

## Out of Scope

- Real StoreKit 2 purchasing — `TeamThemeOption.isPurchased` is hardcoded `true`.
- Per-team alternate app icons — needs real icon assets, provided later.
- Any team other than Palmeiras, or a purchasable catalog UI beyond a single hardcoded option.
- Home/away-context-dependent coloring (e.g. showing a match's away team in their away kit) —
  this theme always uses the team's `home` kit colors, regardless of match context.
- Standings row backgrounds, match card backgrounds/fills, or any *solid* (non-text, non-border)
  team-colored surface beyond the background gradient/blobs and the hero card's border.
- `secondaryColor`, `matchesConsidered`, and the `away`/`third` kit payloads — fetched implicitly
  (they're in the JSON response) but never decoded or used.
