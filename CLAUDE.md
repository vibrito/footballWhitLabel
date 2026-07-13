# CLAUDE.md — Football 2026 iOS App

## Project Overview
A config-driven white-label iOS app for national football championships. Each championship
(starting with the Brasileirão) is represented by a `ChampionshipConfig` — competition code,
display name, accent color — so new championships can be added without new app code.
Four tabs: **Matchday**, **Fixtures**, **Standings**, **More**.
Design language: Apple Liquid Glass over a deep stadium-night gradient.

---

## Architecture
- **MVVM** — Views own no business logic. Each screen has a dedicated `ViewModel` (`@Observable`).
- Keep `View` files focused on layout and binding only.
- `Model` types are plain Swift structs/classes — no UI imports.
- `ViewModel` handles state, filtering, and data access.
- `ChampionshipConfig` (in `Config/`) captures which championship this build targets
  (competition code, display name, accent color) — injected once at launch; adding a
  championship means adding a config value, not new types.

---

## Tech Stack
| Concern | Choice |
|---|---|
| UI | SwiftUI (iOS 26+) |
| Persistence | SwiftData |
| Testing | Swift Testing (`@Test`, `@Suite`) |
| Concurrency | Swift Concurrency (`async/await`, `Actor`) |
| External dependencies | Firebase (Analytics, Crashlytics, Messaging) via SPM |
| Minimum deployment | iOS 26 |

---

## Design System — Liquid Glass

### Background
```
radial-gradient: #173a68 → #0b2143 → #061325 (top-center light source)
```
Two soft blurred blobs behind content: top-left accent @ 40% alpha, bottom-right teal `rgba(45,212,191,0.32)`.

### Glass Surface (every card, tab bar, table)
In SwiftUI use `.ultraThinMaterial` / `.regularMaterial` and iOS 26 Liquid Glass APIs.
Do **not** reproduce CSS `backdrop-filter` literally.

| Property | Value |
|---|---|
| Active card fill | `white @ 0.07` |
| Muted/finished fill | `white @ 0.05` |
| Border | `0.5px, white @ 0.16` |
| Inner highlight | `inset 0 1px 0, white @ 0.22` |
| Card shadow | `0 8px 22px black @ 0.22` |
| Tab bar shadow | `0 12px 32px black @ 0.40` |

### Corner Radii
| Element | Radius |
|---|---|
| Position chip | 7px |
| Buttons / pills | 13–15px |
| Slim rows | 18px |
| Match cards | 22px |
| Tables / large panels | 24px |
| Tab bar | 26px |
| Hero featured card | 28px |

### Accent Color (themeable, default Sunset Red)
- Sunset Red `#ff4d5e` ← default
- Pitch Teal `#2dd4bf`
- Gold `#fbbf24`

Derived: live chip fill = accent @ 18%, text = accent, border = accent @ 45%.

### Typography (SF Pro via system font)
| Role | Size | Weight | Notes |
|---|---|---|---|
| Screen title | 32 | 800 | tracking -0.5, leading 1.1 |
| Eyebrow / date label | 11 | 700 | tracking 1.4, white @ 0.5, uppercase |
| Section header | 13 | 700 | tracking 0.8, white @ 0.5 |
| Hero score | 46 | 800 | tabular-nums |
| Card team name | 16 | 600 | white |
| Card score | 19 | 800 | tabular-nums |
| Table cell | 14 | 600/700 | tabular-nums for numbers |
| Chip / meta | 11 | 800/600 | tracking 0.3–1 |
| Tab label | 10 | 600 | |

All numeric scores/stats: `.monospacedDigit()`.

### Colors
```swift
// Backgrounds
#173a68, #0b2143, #061325, #07142b

// Text
white, white@0.85, white@0.70, white@0.55, white@0.45, white@0.40

// Status
advance: #2dd4bf   // teal
playoff: #fbbf24   // amber
```

---

## Project Structure
```
BR2026/
├── App/
│   └── Championship.swift
├── Config/
│   └── ChampionshipConfig.swift
├── Models/
│   ├── Match.swift
│   ├── MatchEvent.swift
│   ├── Team.swift
│   └── Standing.swift
├── MockData/
│   └── MockDataProvider.swift
├── Services/
│   ├── MatchService.swift        # protocol
│   ├── LiveMatchService.swift
│   └── MockMatchService.swift
├── ViewModels/
│   ├── MatchdayViewModel.swift
│   ├── FixturesViewModel.swift
│   ├── StandingsViewModel.swift
│   └── MatchDetailViewModel.swift
├── Views/
│   ├── Root/
│   │   └── ContentView.swift     # TabView: Matchday, Fixtures, Standings, More
│   ├── Matchday/
│   ├── Fixtures/
│   ├── Standings/
│   ├── MatchDetail/               # sheet presented from match cards
│   └── More/
├── Components/
│   ├── GlassCard.swift
│   ├── TeamCrestBadge.swift
│   ├── LiveChip.swift
│   ├── ScoreRow.swift
│   ├── AccentPill.swift
│   └── Color+Hex.swift
└── Resources/
    └── Localizable.xcstrings
```

---

## Localization
- **Supported locales:** `pt-BR`, `pt-PT`, `fr`, `en-US`, `en-GB`
- **Default fallback:** `en-US` (when system language is not covered)
- Language is set by the system — no in-app language picker.
- All user-facing strings must go through `String(localized:)` or `.xcstrings`.
- No hardcoded English strings in View or ViewModel files.
- Team, venue, and competition names come dynamically from the live API and are displayed
  as-is — there is no local translation table for server-driven content.

---

## Data & Persistence
- **SwiftData** for the `Match` model (`@Model`) — persisted, supports partial updates.
- `Standing` is also a SwiftData `@Model` — the whole table is replaced on each fetch via a
  clear-and-reinsert (not persisted incrementally, same principle as before), so it now
  survives a relaunch too.
- `Competition` is also a SwiftData `@Model`, caching the name and logo image bytes
  together. Unlike Matchday/Fixtures/Standings (which always background-refresh),
  `MoreViewModel.load()` skips the network entirely once a cache exists and is under 7 days
  old — competition branding doesn't change the way scores do, so there's nothing to keep
  continuously fresh.
- Matchday, Fixtures, and Standings show their last-known persisted data immediately on load,
  then refresh from the API in the background via `MatchService.cachedMatches()`/
  `cachedStandings()` — a failed background refresh keeps the last-known data on screen rather
  than clearing it. This auto-refresh only fires once, on each ViewModel's first `loadOnce()`
  call — calling it again (e.g. `.task` restarting when a tab reappears) is a no-op. Repeating
  it on every reappear collided with `.refreshable`'s own layout negotiation and caused a
  visible content jump; pull-to-refresh (`.refreshable`, which calls `load()` directly) is the
  way to force a refresh after the first one.
- `MatchService` protocol abstracts the data source. `MockMatchService` is used in all
  automated tests; `LiveMatchService` talks to the live API — both conform to the same
  protocol.
- Match data updates incrementally as games progress — models support partial updates
  (score, minute, status) via `Match.update(from:)`.
- Avoid full-reload refreshes for matches; upsert by `id` instead.

---

## Backend API
- Base URL: `https://football-api-production-16d9.up.railway.app`
- Auth: `X-Auth-Token` header, value in `Secrets.xcconfig` (see `Secrets.xcconfig.example`);
  never commit the real key.
- `GET /v4/competitions/{code}/matches` — supports `?status=LIVE`, `?matchday=N`
- `GET /v4/competitions/{code}/standings`
- `GET /v4/competitions/{code}` — competition name and logo, consumed by the More screen's
  competition header.
- `GET /v4/competitions/{code}/matches/:id/events` — consumed by the match-detail sheet
  (`MatchDetailView`), which shows a goals/cards/substitutions timeline.
- `GET /v4/competitions/{code}/matches/:id/{statistics,lineups}` — not yet consumed;
  deferred to a future phase.
- Brasileirão's competition code is `BSA`, set via `ChampionshipConfig.brasileirao`.

---

## Firebase

- First external dependency (`firebase-ios-sdk`, pinned `upToNextMajorVersion` from
  `12.0.0`), added via Swift Package Manager. Three products linked to the `BR2026` app
  target only (not the test targets): `FirebaseAnalytics`, `FirebaseCrashlytics`,
  `FirebaseMessaging`.
- SPM integration was scripted with the `xcodeproj` Ruby gem rather than hand-edited — see
  `docs/superpowers/plans/2026-07-12-firebase-integration-implementation.md` Task 1 for the
  script, if a future Firebase product needs adding the same way.
- `GoogleService-Info.plist` is committed directly to the repo at `BR2026/GoogleService-Info.plist`
  (unlike `Secrets.xcconfig`, this file isn't a traditional secret per Google's own guidance).
- `AppDelegate` (`BR2026/App/AppDelegate.swift`, bridged via `@UIApplicationDelegateAdaptor`)
  calls `FirebaseApp.configure()` and `registerForRemoteNotifications()` on launch — this
  silently mints an FCM token but **never** calls
  `UNUserNotificationCenter.requestAuthorization`, so no permission prompt or visible push
  UI ever appears. `BR2026.entitlements` sets `aps-environment: development` (Xcode swaps in
  `production` for distribution builds automatically); `UIBackgroundModes` includes
  `remote-notification` for silent delivery.
- Firebase's automatic `screen_view` tracking relies on swizzling `UIViewController`
  lifecycle methods, which SwiftUI's non-UIKit-backed view hierarchy never triggers — so
  every top-level screen calls `View.trackScreen(_:)` (`BR2026/Services/ScreenTracking.swift`)
  on appear, which manually logs `AnalyticsEventScreenView` via `Analytics.logEvent(...)`.
  This is the only place analytics events are logged explicitly; everything else Firebase
  reports (`first_open`, `session_start`, etc.) remains automatic. Crashlytics uploads
  dSYMs via a Run Script build phase on the app target.

---

## Fastlane / Release Automation

Ruby toolchain pinned via `Gemfile`/`.ruby-version` (rbenv). Invoke all lanes as
`bundle exec fastlane <lane>`. One-time setup: copy `fastlane/.env.default.example` to
`fastlane/.env.default` and fill in an App Store Connect API key (Users and Access >
Integrations > App Store Connect API > Team Keys).

| Lane | What it does |
|---|---|
| `test` | Runs the `BR2026Tests` suite via `scan`. |
| `screenshots` | Captures App Store screenshots for all 5 locales via `snapshot` (uses the `BR2026UITests` target); writes to `fastlane/screenshots/`, no upload. |
| `release_notes` | Pushes `fastlane/metadata/<locale>/release_notes.txt` ("What's New") to App Store Connect via `deliver`. Metadata only — no binary, no screenshots, no submission. |
| `beta` | Builds an archive and uploads to TestFlight via `gym` + `upload_to_testflight`. Build number is `latest_testflight_build_number + 1`, applied only for that build (`xcargs`) — never written back to `project.pbxproj` or Xcode's General tab. |

`BR2026UITests` is a dedicated XCUITest target (not part of the Swift Testing unit suite),
used only by the `screenshots` lane — its tab navigation taps `tabBars.buttons` by index
(SwiftUI `TabView` tab bar buttons don't propagate `.accessibilityIdentifier`, verified
empirically). The `screenshots` lane hits the real live API — `Secrets.xcconfig` must be
configured with a real API key before running it (see Backend API section), and captured
screenshots reflect whatever matches/standings are live or scheduled at capture time.

---

## Assets
- **Team crests:** loaded remotely via `AsyncImage` from each team's `crest` URL. No
  bundled team images. Show a placeholder (team initials on a muted glass fill) while
  loading or if the URL is missing/fails.
- **Icons:** SF Symbols only. No custom raster icons.
  - Matchday → `soccerball`
  - Fixtures → `calendar`
  - Standings → `chart.bar`
  - More → `ellipsis.circle`
- **Alternate app icons:** Light (default), Brasil, Stadium — switchable from the More screen's
  App Icon row via `UIApplication.setAlternateIconName(_:)`. Each has a matching
  `AppIconPreview-*` plain Image Set for the picker's thumbnail (App Icon Set assets aren't
  reliably loadable via plain SwiftUI `Image(_:)`).

---

## Coding Guidelines
- Keep changes small and focused — one concern per PR/commit.
- Prefer clear SwiftUI structure over premature abstractions.
- No `UIKit` unless SwiftUI has no equivalent.
- No force-unwraps (`!`) outside of tests.
- `@Observable` over `ObservableObject` (iOS 26 standard).
- Use `SwiftData` `@Model` for persistence; plain structs for transient/display models.
- Animations: use SwiftUI `.animation()` and `withAnimation` — no manual timers for pulse.
  - Live pulse: opacity `1→0.35→1`, scale `1→0.8→1`, 1.4s ease-in-out, repeat forever.
  - Refresh pulse: same values as the live pulse, in muted `white @ 0.5` instead of accent
    color — shown in the nav bar while a background data refresh (`isRefreshing`) is in flight.
    Fixtures and Standings show it; Matchday deliberately doesn't (its blank system title
    made the dot's mount/unmount visibly destabilize that screen's nav bar layout) — see
    the comment in `MatchdayView.swift`.

---

## Testing
- Framework: **Swift Testing** (`import Testing`).
- Unit test ViewModels and Services — not Views.
- Test files live in `BR2026Tests/`, mirroring the source structure.
- Use `MockMatchService` in all tests — no network calls, no SwiftData container in unit tests.
- Name tests descriptively: `@Test("Matchday tab shows only today's matches")`.

---

## Scope (current phase)
- 4 tabs: Matchday, Fixtures, Standings, More.
- This white label will be used by other apps — championships beyond Brasileirão are a
  future phase, added via new `ChampionshipConfig` values.
- Brasileirão is the only wired-up championship; a championship switcher UI and theming
  beyond one accent color are out of scope. Match detail covers the events timeline;
  statistics and lineups are deferred to a future phase.
- Alternate home variants (B/C) are **out of scope**.
- No user accounts, no user-visible notifications, no watchOS/widgets — future phases.
  Firebase Messaging is wired up at the plumbing level (APNs registration, FCM token
  generation) as scaffolding for a future phase, but no permission is requested and no
  push-consuming feature exists yet.