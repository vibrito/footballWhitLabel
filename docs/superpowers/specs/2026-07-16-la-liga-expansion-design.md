# La Liga Expansion + Spanish Localization Design Spec

## Goal

Add a 6th Xcode target, `LaLiga2026`, to the existing white-label family (`BR2026`,
`PremierLeague2026`, `Ligue12026`, `PrimeiraLiga2026`, `ScottishPremiership2026`) —
sharing all existing source code, differing only in configuration, branding, and
per-target assets. This is the second and final sub-project of roadmap item #2 ("More
championships"). Unlike Scottish Premiership, La Liga also requires adding `es` as a
supported locale app-wide, per the roadmap's own stated consequence of adding this
championship.

## Backend Verification

Verified directly against the live API
(`https://football-api-production-16d9.up.railway.app`) on 2026-07-16 — a re-check after
an earlier check on the same day found the competition record empty:

| League | Competition Code | Matches | Standings |
|---|---|---|---|
| La Liga | `PD` | 380 matches | 20 rows, populated |

No backend changes are needed for this phase.

## Architecture

A 6th Xcode target, added the same way `ScottishPremiership2026` was: duplicate the
`BR2026` native target via the `xcodeproj` Ruby gem (build phases, package product
dependencies, build settings), then override what's target-specific. All existing shared
source (`Views/`, `ViewModels/`, `Services/`, `Models/`, `Components/`, `Config/`) gets
target membership in `LaLiga2026` too.

`BR2026/App/Championship.swift`'s `#if` chain gains one more branch:

```swift
#if TARGET_PREMIER_LEAGUE
let config = ChampionshipConfig.premierLeague
#elseif TARGET_LIGUE_1
let config = ChampionshipConfig.ligue1
#elseif TARGET_PRIMEIRA_LIGA
let config = ChampionshipConfig.primeiraLiga
#elseif TARGET_SCOTTISH_PREMIERSHIP
let config = ChampionshipConfig.scottishPremiership
#elseif TARGET_LA_LIGA
let config = ChampionshipConfig.laLiga
#else
let config = ChampionshipConfig.brasileirao
#endif
```

`LaLiga2026` defines its own `TARGET_LA_LIGA` Active Compilation Condition in its own
Build Settings.

**Two lessons carried forward from the Scottish Premiership expansion, applied from the
start this time instead of being discovered mid-implementation:**
1. The target-duplication script's Frameworks-build-phase copy step skips `PBXBuildFile`s
   whose `file_ref` is nil — true for every SPM package-product entry (they use
   `product_ref` instead). After duplicating, explicitly copy the 3 Frameworks-phase
   entries (FirebaseAnalytics/Crashlytics/Messaging) from an existing target (e.g.
   `ScottishPremiership2026`) onto `LaLiga2026`, verified via the same target-ownership
   check used last time.
2. Duplicating a target also copies its Resources-phase build-file entries verbatim — the
   new target's Resources phase will initially still reference `LaunchScreen-BR2026.storyboard`.
   When wiring the real launch screen, the stale `BR2026` storyboard reference must be
   explicitly removed from `LaLiga2026`'s own Resources phase (not just the
   `INFOPLIST_FILE` build setting changed), and verified via real on-device launch-screen
   inspection, not just a build check.

## New `ChampionshipConfig` Value

```swift
static let laLiga = ChampionshipConfig(
    id: "la-liga",
    displayName: "La Liga",
    competitionCode: "PD",
    accentColorHex: "#AA151B",
    tabSelectionColorHex: "#F1BF00",
    apiBaseURL: sharedAPIBaseURL
)
```

`#AA151B` (Spanish flag red) is the main accent; `#F1BF00` (Spanish flag gold) is used
specifically as the tab-bar selected-item color — the same "one color for the general
accent, a second brighter one for tab-bar legibility" pairing already used for Premier
League (purple + cyan) and Liga Portugal (navy + green), and matching the two colors the
user provided together. Unlike those two cases, this isn't being done reactively after
finding the main color too dark — it's applied proactively here since the two colors were
supplied as a pair. Should be visually confirmed once built; if `#AA151B` alone actually
reads fine against the dark tab bar, the override could be dropped later, but there's no
reason to default to a single-color scheme when both were given.

## Per-Target Bundle ID and Display Name

| Target | Bundle ID | Display Name |
|---|---|---|
| `LaLiga2026` | `com.vibrito.laliga2026` | La Liga 2026 |

## App Icon and Launch Screen

Real artwork already provided:
- `design/AppIcon-LaLiga-1024.png` (1024×1024) → `AppIcon-LaLiga.appiconset` (primary
  icon) + `AppIconPreview-LaLiga.imageset` (picker thumbnail), same as every prior
  non-`BR2026` target.
- `design/Splash-3g-LaLiga-1290x2796.png` (1290×2796) → `LaunchLogo-LaLiga.imageset` (3
  identical physical files, 1x/2x/3x) + `LaunchScreen-LaLiga.storyboard` (single full-bleed
  `imageView`, `translatesAutoresizingMaskIntoConstraints="YES"` with explicit
  `frame`/`autoresizingMask` — not Auto Layout constraints, per the established gotcha) +
  `Generated/LaLiga-Info.plist` (copy of an existing per-target partial Info.plist with
  `UILaunchStoryboardName` changed).

`LaLiga2026`'s Build Settings set `ASSETCATALOG_COMPILER_APPICON_NAME =
"AppIcon-LaLiga"` and have the inherited `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`
(copied from `BR2026`'s 21-entry list) cleared, same as every prior non-`BR2026` target.

## Gating Brasileirão-Specific UI

The same 8 `#if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA ||
TARGET_SCOTTISH_PREMIERSHIP)` sites across `AppIconOption.swift`, `MoreViewModel.swift`,
and `AppIconPickerView.swift` (the "Stadium" alternate icon, "Team Theme" row, purchasable
Team Icon catalog) gain ` || TARGET_LA_LIGA`, plus `AppIconOption.swift`'s separate
positive-selection `previewImageName` chain gains one more `#elseif TARGET_LA_LIGA`
branch. A repo-wide grep before considering this done must show zero remaining instances
of the old (pre-`TARGET_LA_LIGA`) condition anywhere.

## `CrossAppLink` Registry

```swift
static let laLiga = CrossAppLink(
    id: "la-liga",
    displayName: "La Liga",
    accentColorHex: "#AA151B",
    urlScheme: "laliga2026",
    appStoreID: "0000000000"
)
```

Appended to `all` (6 entries total). Still not wired into any View — same deferral as
every other app.

## Spanish Localization

`BR2026.xcodeproj`'s project-level `knownRegions` gains `es` (currently `Base, en, en-GB,
fr, pt-BR, pt-PT` — this is a single, project-wide setting, not per-target, so it applies
to all 6 targets at once). All 39 keys in `BR2026/Resources/Localizable.xcstrings` gain an
`es` localization, using the same JSON-serialization technique already established for
adding `pt-BR` earlier (`separators=(',', ' : ')`, trailing newline stripped, to keep the
diff minimal and match Xcode's own formatting exactly). **Translations for all 39 keys are
supplied by the user** — not fabricated — and get wired in verbatim once provided.

No new locale-specific asset work is needed beyond the string catalog — team/venue/
competition names remain server-driven and untranslated per the existing
"no local translation table for server-driven content" rule (CLAUDE.md).

## Terms of Service Parameterization Fix

Found while scoping this work, approved to fix now since it's directly adjacent (the
exact string being touched for the new `es` translation) — not unrelated scope creep:
`TermsOfServiceView`'s body text hardcodes **"the Brasileirão championship"** identically
across every target, in all 5 existing locales. This is wrong for the 5 non-`BR2026` apps
today, and would be wrong for `LaLiga2026`/`es` too if left as-is.

Fix: parameterize the one affected sentence in the `terms_of_service_body` catalog entry
to use a `%@` placeholder in place of the hardcoded championship name, in all locales:

| Locale | Change |
|---|---|
| `en`/`en-GB` | "for the Brasileirão championship" → "for the %@ championship" |
| `fr` | "du Championnat brésilien (Brasileirão)" → "du championnat %@" |
| `pt-BR` | "do Campeonato Brasileiro" → "do campeonato %@" |
| `pt-PT` | "do Campeonato Brasileiro" → "do campeonato %@" |
| `es` (new) | supplied by the user, written with the same `%@` placeholder from the start |

`TermsOfServiceView` gains a `config: ChampionshipConfig` parameter, threaded from
`ContentView` (which already holds `config`) → `MoreView` (gains a `config` parameter,
passed alongside its existing `service`/`themeStore`/purchase-store parameters) →
`TermsOfServiceView`. The body text becomes:

```swift
Text(String(format: String(localized: "terms_of_service_body"), config.displayName))
```

`ChampionshipConfig.displayName` is already exactly the right string for each target
("Brasileirão", "Premier League", "Ligue 1", "Liga Portugal", "Scottish Premiership", "La
Liga") — no new field needed.

## Testing

- `ChampionshipConfig.laLiga` unit test, mirroring the existing per-config test shape
  (id, competitionCode, displayName, accentColorHex, tabSelectionColorHex, apiBaseURL).
- `CrossAppLink.laLiga` addition; the existing `siblingsExcludesCurrentApp` test's
  expected count moves from 4 to 5, plus asserts the new sibling's presence.
- A build verification for the `LaLiga2026` scheme, plus a full-suite regression run
  confirming all 6 targets are unaffected by the gating/localization/Terms-of-Service
  changes.
- No new tests for `TermsOfServiceView`'s parameterization (Views aren't unit-tested per
  `CLAUDE.md`) — verified by reading the resulting string manually for at least one
  non-`BR2026` target during manual verification.
- No dedicated test for the `es` localization strings themselves (this project has no
  existing test coverage asserting localized string *content* for any locale — matching
  established precedent, not a new gap introduced here).

## External Setup Required (Manual, Not Part of This Implementation)

Same category as every prior target: a Firebase project/app for `LaLiga2026` (a
`GoogleService-Info.plist`) and bundle ID registration/App Store Connect app record for
`com.vibrito.laliga2026` — both the user's responsibility, both deferred. Until provided,
`LaLiga2026` shares `BR2026`'s Firebase project, the same known bootstrap state every
other new target has started in.

## Out of Scope (Deferred to Later Work)

- Wiring `CrossAppLink`'s UI into the More screen — still deferred until at least one
  sibling app is approved and live.
- Real (non-placeholder) App Store Connect metadata, screenshots, and submission for
  `LaLiga2026`.
- Any locale beyond `es` (e.g. Latin American Spanish variants) — confirmed generic `es`
  is sufficient for now, matching the existing generic `fr` precedent.
- Any other pre-existing bug unrelated to the Terms of Service championship-name issue —
  this spec fixes only that one specific, directly-adjacent issue, not a general audit of
  `Localizable.xcstrings` for other latent cross-target inconsistencies.
