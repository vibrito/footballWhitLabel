# More Screen Design

**Goal:** Replace the placeholder `MoreView` with a real screen: a Legal section (Terms of
Service) plus disabled placeholder rows for Settings and In-App Purchases, so the tab's final
shape is visible before those features exist.

**Architecture:** A data-driven row/section model (`MoreRow`, `MoreSection`, `MoreDestination`)
exposed by `MoreViewModel` (`@Observable`, no service dependency). `MoreView` renders each
section as a `GlassCard`-wrapped group of rows — enabled rows are `NavigationLink`s, disabled
rows are plain dimmed rows with no chevron. Terms of Service pushes a new `TermsOfServiceView`
showing localized static text. Adding real Settings/In-App Purchases later means adding a
`MoreDestination` case and a destination view, and flipping `isEnabled` — no reshaping of
`MoreView` or the model.

## Data Model

`Models/MoreDestination.swift`:
```swift
enum MoreDestination: Hashable {
    case termsOfService
}
```

`Models/MoreRow.swift`:
```swift
struct MoreRow: Identifiable {
    let id: String
    let titleKey: LocalizedStringResource
    let systemImage: String
    let destination: MoreDestination?   // nil = disabled, non-tappable
    let isEnabled: Bool
}
```

`Models/MoreSection.swift`:
```swift
struct MoreSection: Identifiable {
    let id: String
    let titleKey: LocalizedStringResource
    let rows: [MoreRow]
}
```

## ViewModel

`ViewModels/MoreViewModel.swift` — `@Observable`, exposes a static `sections: [MoreSection]`:

- **Legal** section: one row, Terms of Service, `isEnabled: true`, `destination: .termsOfService`.
- **Preferences** section: two rows, Settings and In-App Purchases, both `isEnabled: false`,
  `destination: nil`.

No async data, no `MatchService` dependency — this is intentionally static content, distinct
from the other three tabs.

## Views

- `Views/More/MoreView.swift` — `NavigationStack` over `ScrollView`. For each `MoreSection`:
  a section-header `Text` above the card (CLAUDE.md's existing "Section header" style — 13pt/700,
  tracking 0.8, `white @ 0.5`, uppercase), then a single `GlassCard` whose content is a `VStack`
  of that section's rows (`GlassCard` has no title parameter of its own — the header sits outside
  it, same pattern as Standings). Enabled rows use `NavigationLink(value: row.destination)` with
  a `.navigationDestination(for: MoreDestination.self)` modifier mapping `.termsOfService` to
  `TermsOfServiceView()`. Disabled rows are a plain `HStack` (icon + label) at `white @ 0.3`
  opacity, no chevron, no tap gesture — matching the "Muted/finished fill" tone already used
  elsewhere for non-interactive states.
- Row icons (SF Symbols only, per CLAUDE.md): Terms of Service → `doc.text`, Settings →
  `gearshape`, In-App Purchases → `cart`.
- `Views/More/TermsOfServiceView.swift` — `ScrollView` + `Text(String(localized: "terms_of_service_body"))`,
  `.navigationTitle("Terms of Service")`.

## Legal Content & Localization

- Terms of Service body text is genuine starter boilerplate — reasonable for a football scores
  app, but **not legal advice**. It must be reviewed by qualified counsel before this build is
  submitted to the App Store. This is called out in a code comment above the string catalog
  entry and must not be treated as final.
- Delivered like every other user-facing string in this project: through `Localizable.xcstrings`,
  under one key `terms_of_service_body`, with real starter copy provided for all 5 supported
  locales (pt-BR, pt-PT, fr, en-US, en-GB) — the same "real but review-before-ship" treatment
  used for the fastlane `release_notes.txt` copy. No separate text-file loading mechanism.
- Privacy Policy is out of scope for the in-app screen — handled solely via App Store Connect
  metadata, per user decision.

## Testing

`BR2026Tests/ViewModels/MoreViewModelTests.swift` (Swift Testing, no `MockMatchService` needed):

- `sections` contains a "Legal" section with exactly one row (Terms of Service), `isEnabled == true`,
  `destination == .termsOfService`.
- `sections` contains a "Preferences" section with exactly two rows (Settings, In-App Purchases),
  both `isEnabled == false` and `destination == nil`.

No view tests, per CLAUDE.md's "unit test ViewModels, not Views."

## Scope

**In scope for this build:**
- `MoreRow` / `MoreSection` / `MoreDestination` models
- `MoreViewModel` with the two hardcoded sections described above
- `MoreView` rewritten to render sections/rows via `GlassCard`, replacing the current
  "More settings coming soon" placeholder
- `TermsOfServiceView` with real starter copy in all 5 locales
- Unit tests for `MoreViewModel`

**Out of scope (future phases, per CLAUDE.md):**
- Actual Settings screen/functionality
- Actual In-App Purchases integration
- Privacy Policy in-app screen (handled via App Store Connect metadata only)
- Any settings persistence (SwiftData, UserDefaults, etc.)
