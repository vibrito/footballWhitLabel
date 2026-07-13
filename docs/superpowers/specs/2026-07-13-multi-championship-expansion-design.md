# Multi-Championship Expansion Design Spec

## Goal

Expand the white-label architecture from one app (Brasileirão) to four: add three new
Xcode targets — Premier League, Ligue 1, and Primeira Liga — sharing all existing source
code, differing only in configuration, branding, and per-target assets. This is the first
of several planned expansions (see Scope below for what's explicitly deferred).

## Backend Verification

All three leagues are already fully served by the existing backend
(`https://football-api-production-16d9.up.railway.app`) — verified directly against the
live API before starting this design:

| League | Competition Code | Matches | Standings |
|---|---|---|---|
| Premier League | `PL` | 380 matches | populated |
| Ligue 1 | `FL1` | 306 matches | populated |
| Primeira Liga | `PPL` | 306 matches | populated |

No backend changes are needed for this phase.

## Architecture

Four Xcode targets in this one repo and one Xcode project:
- `BR2026` (existing) — Brasileirão
- `PremierLeague2026` (new)
- `Ligue12026` (new)
- `PrimeiraLiga2026` (new)

All existing shared source (`Views/`, `ViewModels/`, `Services/`, `Models/`, `Components/`,
`Config/`) gets target membership in all four targets. A bug fix or feature landing in
shared code ships in all four apps simultaneously — this is the existing "config-driven
white-label... adding a championship means adding a config value, not new types"
principle from `CLAUDE.md`, now actually exercised by more than one app for the first time.

`BR2026/App/Championship.swift` (the `@main` `ChampionshipApp` struct) remains a single
shared file across all four targets. It currently hardcodes:
```swift
let config = ChampionshipConfig.brasileirao
```
This becomes an `#if` selection based on one Active Compilation Condition flag per target
(e.g. `TARGET_PREMIER_LEAGUE`, `TARGET_LIGUE_1`, `TARGET_PRIMEIRA_LIGA`, each target
defining its own flag in its own Build Settings; `BR2026` defines none and falls through
to the existing default):
```swift
#if TARGET_PREMIER_LEAGUE
let config = ChampionshipConfig.premierLeague
#elseif TARGET_LIGUE_1
let config = ChampionshipConfig.ligue1
#elseif TARGET_PRIMEIRA_LIGA
let config = ChampionshipConfig.primeiraLiga
#else
let config = ChampionshipConfig.brasileirao
#endif
```

## New `ChampionshipConfig` Values

Three new static values added to `BR2026/Config/ChampionshipConfig.swift`, mirroring the
existing `.brasileirao` pattern exactly (same `apiBaseURL`, since one backend serves all
leagues):

| League | `id` | `competitionCode` | `accentColorHex` | Source |
|---|---|---|---|---|
| Premier League | `"premier-league"` | `"PL"` | `#3D195B` | Official "Purple Power" brand color |
| Ligue 1 | `"ligue-1"` | `"FL1"` | `#FACC15` | Accent color from Ligue 1's 2024 rebrand palette |
| Primeira Liga | `"primeira-liga"` | `"PPL"` | `#00235A` | Official Primeira Liga navy blue |

## Per-Target Bundle IDs and Display Names

Matches the existing `com.vibrito.br2026` / "BR 2026" pattern:

| Target | Bundle ID | Display Name |
|---|---|---|
| `PremierLeague2026` | `com.vibrito.premierleague2026` | Premier League 2026 |
| `Ligue12026` | `com.vibrito.ligue12026` | Ligue 1 2026 |
| `PrimeiraLiga2026` | `com.vibrito.primeiraliga2026` | Primeira Liga 2026 |

## Localization

All three new apps support all 5 existing locales (`pt-BR`, `pt-PT`, `fr`, `en-US`,
`en-GB`) — same as Brasileirão. All UI strings are already shared and already fully
translated (per the earlier session's localization fix); no new translation work is
needed for the app UI itself. New App Store Connect metadata (description, keywords,
etc.) per app is a separate, later concern (not part of this design — this spec covers
the app itself, not its App Store listing content).

## App Icons

Each new target needs its own **primary** app icon (not an alternate icon like
`BR2026`'s existing "Brasil"/"Stadium" options) at its own accent color. Per-target
placeholder icons are generated programmatically now (same technique used for the
Launch Screen's `soccerball` SF Symbol rendering: rasterize the `soccerball` SF Symbol
in white, centered on a solid background at the target's accent color, at the standard
iOS App Icon size of 1024×1024), to unblock development and internal testing.
Real icon artwork can replace these later with no code changes — it's purely an asset
swap in each target's `AppIcon.appiconset`.

## External Setup Required (Manual, Not Part of This Implementation)

The following cannot be automated from this repo and are the user's responsibility
before each new app can actually be built, tested on-device via TestFlight, or
submitted:
- A Firebase project/app per new target (Analytics/Crashlytics/Messaging are keyed to
  bundle ID) → a `GoogleService-Info.plist` per target
- Bundle ID registration (Apple Developer "Identifiers") and an App Store Connect app
  record per new target — likely needs Admin-role API access (the current ASC API key
  is App Manager role, which was insufficient for certificate/profile management earlier
  this project's history; probably also insufficient for registering new bundle IDs) —
  most likely done via the App Store Connect / Apple Developer web UI directly, same as
  how the original `com.vibrito.br2026` bundle ID and app record already exist

This implementation plan builds everything that doesn't require those external
artifacts (the targets themselves, shared code wiring, configs, placeholder icons,
compiler flags) so that once the user provides the `GoogleService-Info.plist` files (and
optionally registers the bundle IDs), the remaining wiring is mechanical.

## Cross-App Linking (item #6)

Each target registers its own custom URL scheme matching its bundle ID's short name
(e.g. `premierleague2026://`, `ligue12026://`, `primeiraliga2026://`, `br2026://`) via
`CFBundleURLTypes` in its Info.plist, and declares the other three schemes in
`LSApplicationQueriesSchemes` (required by iOS for `canOpenURL` to return accurate
results for schemes the app doesn't own).

A new shared `CrossAppLink` model + helper (`BR2026/Models/CrossAppLink.swift` or
similar — exact file TBD in the implementation plan) represents one sibling app: its
name, accent color, custom URL scheme, and App Store numeric ID (placeholder value
until each app's real ASC app record exists). A pure-logic resolver function takes a
`CrossAppLink` and returns which URL to actually open: the custom scheme if
`canOpenURL` succeeds, otherwise the App Store URL
(`https://apps.apple.com/app/id<NUMERIC_ID>`). This resolver is unit-testable in
isolation (no UI, no live app installs required — inject the `canOpenURL` check as a
closure/protocol for testability).

**The reusable component is built, but is NOT wired into the actual More screen in this
phase** — no "Our Other Apps" section ships yet. It gets added to the UI in a small
follow-up task once at least one sibling app is actually approved and live, to avoid
shipping links that go nowhere. This is a deliberate, explicit deferral, not an
oversight.

## Testing

- New `ChampionshipConfig` static values get unit tests confirming their `id`,
  `competitionCode`, and `accentColorHex`, following whatever test pattern the existing
  `.brasileirao` value already has (if any — the implementation plan will check).
- The `CrossAppLink` resolver function gets unit tests covering: sibling installed
  (returns custom scheme URL), sibling not installed (returns App Store URL).
- Each of the 3 new targets gets a build verification
  (`xcodebuild ... -scheme <TargetName> ... build`) as part of the implementation plan's
  final verification step.
- Views aren't unit-tested per `CLAUDE.md`; the shared Views require no changes for this
  phase since branding flows entirely through the existing `ChampionshipConfig` plumbing
  already consumed by existing Views.

## Out of Scope (Deferred to Later Phases)

Per the user's own stated ordering, these are explicitly NOT part of this phase:
- In-app purchase team themes (icon/color/hero-card customization) — item #2
- Push notifications for purchased teams — item #3
- Apple Watch, CarPlay, and Widget companions — item #4
- "Where to watch" broadcast-channel page — item #5
- Actually wiring the cross-app-linking UI into the More screen (see above) — deferred
  until a sibling app is live
- Real (non-placeholder) app icon artwork for the 3 new apps
- App Store Connect metadata, screenshots, and submission for the 3 new apps (a
  separate, later effort once the apps themselves build and run correctly — mirrors the
  work already done for `BR2026` in the App Store submission session, but per-app)
