# Scottish Premiership Expansion Design Spec

## Goal

Add a 5th Xcode target, `ScottishPremiership2026`, to the existing white-label family
(`BR2026`, `PremierLeague2026`, `Ligue12026`, `PrimeiraLiga2026) — sharing all existing
source code, differing only in configuration, branding, and per-target assets. This is the
first sub-project of roadmap item #2 ("More championships"); the second sub-project, La
Liga plus the Spanish localization it requires, is deferred separately (see Out of Scope).

## Backend Verification

Verified directly against the live API
(`https://football-api-production-16d9.up.railway.app`) before starting this design:

| League | Competition Code | Matches | Standings |
|---|---|---|---|
| Scottish Premiership | `SPL` | 198 matches | 12 rows, populated |

No backend changes are needed for this phase.

## Architecture

A 5th Xcode target in this one repo and one Xcode project:
- `BR2026` (existing) — Brasileirão
- `PremierLeague2026` (existing) — Premier League
- `Ligue12026` (existing) — Ligue 1
- `PrimeiraLiga2026` (existing) — Liga Portugal
- `ScottishPremiership2026` (new) — Scottish Premiership

All existing shared source (`Views/`, `ViewModels/`, `Services/`, `Models/`, `Components/`,
`Config/`) gets target membership in `ScottishPremiership2026` too — the existing
"config-driven white-label... adding a championship means adding a config value, not new
types" principle, unchanged from the prior 3-target expansion.

`BR2026/App/Championship.swift`'s `#if` chain gains one more branch, following the exact
pattern already there:

```swift
#if TARGET_PREMIER_LEAGUE
let config = ChampionshipConfig.premierLeague
#elseif TARGET_LIGUE_1
let config = ChampionshipConfig.ligue1
#elseif TARGET_PRIMEIRA_LIGA
let config = ChampionshipConfig.primeiraLiga
#elseif TARGET_SCOTTISH_PREMIERSHIP
let config = ChampionshipConfig.scottishPremiership
#else
let config = ChampionshipConfig.brasileirao
#endif
```

`ScottishPremiership2026` defines its own `TARGET_SCOTTISH_PREMIERSHIP` Active Compilation
Condition in its own Build Settings, same as the other 3 non-`BR2026` targets each define
their own flag.

## New `ChampionshipConfig` Value

Added to `BR2026/Config/ChampionshipConfig.swift`, mirroring the existing values exactly
(same shared `apiBaseURL`):

```swift
static let scottishPremiership = ChampionshipConfig(
    id: "scottish-premiership",
    displayName: "Scottish Premiership",
    competitionCode: "SPL",
    accentColorHex: "#005EB8",
    tabSelectionColorHex: "#005EB8",
    apiBaseURL: sharedAPIBaseURL
)
```

`#005EB8` is the Scotland flag's Saltire blue (user-provided), chosen specifically to be
visually distinct from Premier League's purple (`#3D195B`) within this app family — the
current "cinch Premiership" sponsor branding is itself purple-dominated, which would have
been indistinguishable from Premier League's existing color if used directly.

Unlike Premier League's purple and Liga Portugal's navy (both of which needed a separate,
brighter `tabSelectionColorHex` because the raw brand color was nearly invisible against
the dark tab bar), `#005EB8` is bright/saturated enough that this spec uses it directly for
both `accentColorHex` and `tabSelectionColorHex` — same as Brasileirão's and Ligue 1's
values. This should be visually confirmed once the target is built and run in Simulator;
if the tab bar's selected-item color reads as too dark in practice, swap in a brighter
substitute for `tabSelectionColorHex` only (same fix already applied twice before), leaving
`accentColorHex` untouched.

## Per-Target Bundle ID and Display Name

Matches the existing pattern:

| Target | Bundle ID | Display Name |
|---|---|---|
| `ScottishPremiership2026` | `com.vibrito.scottishpremiership2026` | Scottish Premiership 2026 |

## Localization

No new locale needed — Scottish Premiership is English-speaking and already covered by the
existing `en-GB` locale (same reasoning that applied to Premier League). All UI strings are
already shared and already fully translated; no new translation work for this sub-project.

## App Icon and Launch Screen

Real artwork is already provided (`design/AppIcon-SPL-1024.png`, 1024×1024, and
`design/BR2026/Splash-SPL-1290x2796.png`, 1290×2796) — unlike the prior 3-target expansion,
no programmatic placeholder generation is needed for this sub-project. Both follow the
per-target asset-catalog pattern already used for `PremierLeague2026`/`Ligue12026`/
`PrimeiraLiga2026` (not `BR2026`'s newer full-bleed splash design, which is
`BR2026`-specific — this new target mirrors the *other 3* targets' launch pattern):

- **App icon:** a new `AppIcon-ScottishPremiership.appiconset` (1024×1024), populated
  directly from `design/AppIcon-SPL-1024.png`. `ScottishPremiership2026`'s own Build
  Settings set `ASSETCATALOG_COMPILER_APPICON_NAME = "AppIcon-ScottishPremiership"` (its
  *primary* icon, not an alternate — same as how the other 3 targets each point at their
  own named App Icon Set rather than the shared `AppIcon.appiconset` `BR2026` uses).
- **Launch screen:** a new `LaunchScreen-ScottishPremiership.storyboard`, structurally
  identical to `LaunchScreen-PremierLeague.storyboard` — a single full-bleed `imageView`
  referencing a new `LaunchLogo-ScottishPremiership` Image Set populated directly from
  `design/BR2026/Splash-SPL-1290x2796.png`, over a solid background color matching
  `#005EB8` (`red 0.0, green 0.369, blue 0.722`) as a fallback behind the image.

## `CrossAppLink` Registry

A `scottishPremiership` entry is added to the existing registry in
`BR2026/Models/CrossAppLink.swift`, for consistency with the other 4 apps already listed:

```swift
static let scottishPremiership = CrossAppLink(
    id: "scottish-premiership",
    displayName: "Scottish Premiership",
    accentColorHex: "#005EB8",
    urlScheme: "scottishpremiership2026",
    appStoreID: "0000000000"
)
```

Added to the `all` array. Per the existing, unchanged deferral: this stays **not wired into
any View** — no "Our Other Apps" UI ships from this sub-project either. `Info.plist`'s
`CFBundleURLTypes` (`scottishpremiership2026://`) and `LSApplicationQueriesSchemes`
(declaring the other 4 apps' schemes) are still set up per-target, matching the existing
pattern, even though the UI that would use them isn't wired in yet.

## Testing

- A new `ChampionshipConfig.scottishPremiership` unit test, following whatever test
  pattern the existing `.brasileirao`/`.premierLeague` values already have.
- A `CrossAppLink.scottishPremiership` case added to the existing `CrossAppLink` resolver
  tests' fixture data, if those tests iterate over `CrossAppLink.all`.
- A build verification (`xcodebuild ... -scheme ScottishPremiership2026 ... build`) as part
  of the implementation plan's final verification step, plus a full-suite regression run
  confirming the other 4 targets are unaffected.
- Views aren't unit-tested per `CLAUDE.md`; no shared View changes are needed for this
  phase — branding flows entirely through the existing `ChampionshipConfig` plumbing.

## External Setup Required (Manual, Not Part of This Implementation)

Same category of manual, external work as the prior 3-target expansion — cannot be
automated from this repo, and is the user's responsibility before `ScottishPremiership2026`
can run on a real device via TestFlight or be submitted:
- A Firebase project/app for this target (Analytics/Crashlytics/Messaging are keyed to
  bundle ID) → a `GoogleService-Info.plist` for `ScottishPremiership2026`.
- Bundle ID registration (Apple Developer "Identifiers") and an App Store Connect app
  record for `com.vibrito.scottishpremiership2026` — most likely done via the Apple
  Developer/App Store Connect web UI directly, same as every prior app.

This implementation plan builds everything that doesn't require those external artifacts
(the target itself, shared code wiring, the new config value, placeholder icon/launch
assets, the compiler flag) so that once the user provides the `GoogleService-Info.plist`
file (and optionally registers the bundle ID), the remaining wiring is mechanical.

## Out of Scope (Deferred to Later Work)

- **La Liga + Spanish localization** — the second sub-project of roadmap item #2. La
  Liga's backend competition record (`PD`) currently has zero matches and zero standings
  populated, unlike Scottish Premiership's fully-populated data — this needs to be resolved
  (or simply wait for the backend to sync) before that sub-project's own design/build
  begins. Not part of this spec.
- **Wiring `CrossAppLink`'s UI into the More screen** — still deferred until at least one
  sibling app is actually approved and live, unchanged from the prior expansion's deferral.
- **Real (non-placeholder) app icon/launch artwork** for `ScottishPremiership2026`.
- **App Store Connect metadata, screenshots, and submission** for `ScottishPremiership2026`
  — a separate, later effort once the target itself builds and runs correctly, mirroring
  the per-app metadata work already done for the other 4 apps.
- In-app-purchase Team Theme/Team Icon content, push notifications, Watch/CarPlay/Widgets,
  the where-to-watch page, and Standings zone markers/redesign — all separate roadmap
  items, unaffected by this sub-project.
