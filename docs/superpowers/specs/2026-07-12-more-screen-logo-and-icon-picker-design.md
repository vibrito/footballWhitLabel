# More Screen: Competition Header + App Icon Switcher Design

**Goal:** The More screen gains a competition header (Campeonato Brasileiro Série A's logo and
name, fetched from the now-live `GET /v4/competitions/{code}` endpoint) shown above the
sections list, and the previously-disabled "Settings" row becomes a working "App Icon" picker
letting the user switch between three app icons (Light, Brasil, Stadium).

**Architecture:** `MoreViewModel` gains a `MatchService` dependency to fetch competition data —
a deliberate departure from its original "intentionally static, no service dependency" design,
since the screen now has real async data. The icon picker is a separate, self-contained
feature: a new `MoreDestination` case, a dedicated `AppIconPickerViewModel` behind a small
`AppIconSetting` protocol abstracting `UIApplication.setAlternateIconName(_:)` (UIKit-only, no
SwiftUI equivalent, matching CLAUDE.md's stated UIKit exception), and three new App Icon Sets in
`Assets.xcassets` wired in purely via a build setting — no `project.pbxproj` editing needed,
since the whole `Assets.xcassets` folder is already tracked as one reference.

## Competition Header

### Model

`BR2026/Models/Competition.swift` — no separate DTO: unlike `Team`, `Competition` is never
embedded in a SwiftData `@Model`, so a custom `CodingKeys` mapping is safe here (the constraint
documented on `Team` doesn't apply):

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

Wire shape (confirmed live):
```json
{
  "code": "BSA",
  "name": "Campeonato Brasileiro Série A",
  "season": 2026,
  "logo": "https://media.api-sports.io/football/leagues/71.png"
}
```

### Service

`BR2026/Services/MatchService.swift` gains one method:

```swift
func fetchCompetition() async throws -> Competition
```

`LiveMatchService`:
```swift
func fetchCompetition() async throws -> Competition {
    let url = config.apiBaseURL.appendingPathComponent("v4/competitions/\(config.competitionCode)")
    return try await get(url)
}
```

`MockMatchService`: decodes a new `MockDataProvider.competitionJSON` fixture the same way
`matchesJSON`/`standingsJSON` already are, stored as `private let competition: Competition`,
returned directly (no throwing, matching `fetchMatches()`'s/`fetchStandings()`'s pattern).

No persistence — this rarely changes, so a plain fetch-on-appear is enough (matches
`MatchEvent`'s existing no-persistence precedent, not `Match`/`Standing`'s SwiftData treatment).

### ViewModel

`MoreViewModel` (currently static content, `let sections: [MoreSection]`, no service, no async)
becomes:

```swift
@Observable
@MainActor
final class MoreViewModel {
    private(set) var competitionName: String?
    private(set) var competitionLogoURL: URL?
    let sections: [MoreSection] = [ /* unchanged structure, see Icon Picker section below
                                        for the Preferences row change */ ]
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

### View

`MoreView` calls `.task { await viewModel.loadCompetition() }` and renders a header above the
`ForEach(viewModel.sections)`, using `AsyncImage` with a placeholder — muted glass-fill circle
with a `soccerball` SF Symbol — while loading or on failure, mirroring `TeamCrestBadge`'s
existing placeholder pattern:

```swift
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
```

Placed as the first child in `MoreView`'s content `VStack`, before the `ForEach(sections)`.

### ContentView

`ContentView` currently instantiates `MoreView()` with no arguments — becomes
`MoreView(service: service)`, matching the other three tabs.

## App Icon Switcher

### Icon Assets

Both provided PNGs (`prints/icons/AppIcon-1c-1024.png`, `prints/icons/AppIcon-1e-1024.png`) have
an alpha channel; Apple requires App Icon assets to be fully opaque. Both get flattened
(`sips` composite against an opaque background, or equivalent) before import.

Two new App Icon Sets in `Assets.xcassets`, same single-size 1024×1024 "universal" format as the
existing primary `AppIcon`:
- `AppIcon-Brasil` ← flattened `AppIcon-1c-1024.png` (green/yellow/blue Brazil-colors ball)
- `AppIcon-Stadium` ← flattened `AppIcon-1e-1024.png` (dark navy ball, matches the app's own
  stadium-night background)

Three new plain Image Sets, purely for the picker's preview thumbnails (App Icon Set assets
aren't reliably loadable via plain SwiftUI `Image(_:)` across iOS versions, so a dedicated
preview copy avoids relying on undocumented behavior):
- `AppIconPreview-Light` ← existing `AppIcon-1024.png` (unflattened original is fine here, it's
  not going into an App Icon slot)
- `AppIconPreview-Brasil` ← same flattened image as `AppIcon-Brasil`
- `AppIconPreview-Stadium` ← same flattened image as `AppIcon-Stadium`

Since `Assets.xcassets` is tracked in `project.pbxproj` as a single `folder.assetcatalog`
reference, adding these six new files (two App Icon Sets + three Image Sets, each with their
own `Contents.json`) requires no `project.pbxproj` changes at all.

Build setting (both Debug and Release configs, alongside the existing
`ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`):
```
ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = "AppIcon-Brasil AppIcon-Stadium"
```

### Model

`BR2026/Models/AppIconOption.swift`:

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
    /// from `iconAssetName`, which names an App Icon Set — see Icon Assets above for why).
    var previewImageName: String {
        switch self {
        case .light: "AppIconPreview-Light"
        case .brasil: "AppIconPreview-Brasil"
        case .stadium: "AppIconPreview-Stadium"
        }
    }
}
```

### Icon Setting Abstraction

`BR2026/Services/AppIconSetting.swift`:

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

### ViewModel

`BR2026/ViewModels/AppIconPickerViewModel.swift`:

```swift
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

### View

`BR2026/Views/More/AppIconPickerView.swift` — a `GlassCard`-wrapped list of the 3 options
(thumbnail via `Image(option.previewImageName)`, name, checkmark on `viewModel.selectedIcon`),
tapping a row calls `await viewModel.select(option)`. `errorMessage`, if set, shows as a small
inline message below the list (no alert — consistent with the app's existing lack of any
alert/sheet-based error UI elsewhere).

### Destination Wiring

`MoreDestination` gains a case:
```swift
enum MoreDestination: Hashable {
    case termsOfService
    case appIconPicker
}
```

`MoreViewModel`'s Preferences section row changes from disabled/destination-less to enabled:
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

`MoreView`'s `navigationDestination(for: MoreDestination.self)` gains a case, instantiating the
concrete `UIKitAppIconSetting()` at the point of use (matching the app's existing simple
call-site DI style — no dependency-injection container elsewhere in the app):
```swift
case .appIconPicker:
    AppIconPickerView(viewModel: AppIconPickerViewModel(iconSetting: UIKitAppIconSetting()))
```

## Testing

- `MoreViewModelTests.swift`: existing tests updated to construct `MoreViewModel(service:
  StubMatchService(...))` (breaking signature change). New tests: `loadCompetition()` populates
  `competitionName`/`competitionLogoURL` from a stubbed `Competition`; the Preferences section's
  row is now enabled with `destination == .appIconPicker`.
- `MockMatchServiceTests.swift`: new test asserting `fetchCompetition()` returns the fixture's
  name/logo.
- New `AppIconPickerViewModelTests.swift` using a `StubAppIconSetting` test double (mirrors
  `StubMatchService`'s pattern): initial `selectedIcon` correctly derived from a stubbed
  `currentIconName` (both nil→`.light` and a matching asset name); `select()` updates
  `selectedIcon` on success; `select()` sets `errorMessage` and leaves `selectedIcon` unchanged
  when `setIconName` throws; `select()` on the already-selected option is a no-op (doesn't call
  `setIconName` again).

## Documentation

CLAUDE.md updates:
- **Backend API**: add `GET /v4/competitions/{code}` — consumed by the More screen's
  competition header.
- **Assets**: note the three alternate app icons (Light/Brasil/Stadium) and the
  preview-image-set duplication rationale.
- Wherever the More screen's original "intentionally static, no service dependency" note lives
  (design/plan docs, not CLAUDE.md itself — CLAUDE.md doesn't currently state this) — no CLAUDE.md
  change needed there, but this design supersedes that specific framing from the More Screen
  design spec.

## Out of Scope

- Any Settings functionality beyond app icon switching (the row is renamed specifically because
  icon switching is its only function right now, per user decision — not a general Settings hub).
- Persisting `Competition` via SwiftData.
- Alert/toast UI polish for the icon-switch error path — a plain inline message is enough for
  this iteration.
- Additional alternate icons beyond the two provided.
