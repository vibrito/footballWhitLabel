# Solo Firebase + Publish for Premier League, Ligue 1, Liga Portugal — Design

## Context

The multi-championship expansion added three new Xcode targets — `PremierLeague2026`,
`Ligue12026`, `PrimeiraLiga2026` — sharing all source with `BR2026`. Two things from that
plan were deliberately deferred:

- All four targets currently share `BR2026`'s single Firebase project (one
  `GoogleService-Info.plist`, wired into all 4 targets' Resources build phase) — a
  documented bootstrap state, not a production setup.
- Firebase/App Store Connect/bundle-ID registration for the 3 new apps was called out as a
  manual, external, future step.

This phase closes both gaps: each of the 3 new apps gets its own standalone Firebase
project, and each is taken through the same publish pipeline `BR2026` already went through
(TestFlight → App Store metadata/screenshots → submitted for Apple review, currently
`WAITING_FOR_REVIEW`).

## Goal

Premier League, Ligue 1, and Liga Portugal each end this phase with: their own Firebase
project (separate Analytics/Crashlytics data from BR2026 and from each other), their own
registered bundle ID and App Store Connect app record, and a build submitted for Apple
review — done one app at a time, matching how icons/splash screens were reviewed earlier
(Premier League → Ligue 1 → Liga Portugal).

## Firebase: per-target file separation, no code changes

Today, one physical `GoogleService-Info.plist` is referenced by a single `PBXFileReference`
that's added to all 4 targets' Resources build phases. `FirebaseApp.configure()` (called
with no arguments in `AppDelegate.swift`) relies on auto-discovering a file literally named
`GoogleService-Info.plist` in the app's main bundle — it doesn't care about the file's
source path, only its bundled filename.

The fix — Firebase's own documented pattern for multi-target apps — is four separate source
folders, each holding a file named exactly `GoogleService-Info.plist` with different
content, each wired into *only* its own target's Resources build phase (not shared). No
Swift code changes are needed; `FirebaseApp.configure()` keeps working as-is.

Layout:
```
BR2026/Firebase/BR2026/GoogleService-Info.plist              (existing content, moved)
BR2026/Firebase/PremierLeague/GoogleService-Info.plist        (new)
BR2026/Firebase/Ligue1/GoogleService-Info.plist               (new)
BR2026/Firebase/PrimeiraLiga/GoogleService-Info.plist         (new)
```

The pbxproj surgery (new `PBXFileReference` per file, each added to exactly one target's
Resources phase, removing the old shared reference from the 3 new targets) follows the same
`xcodeproj` Ruby gem pattern already established for the target duplication work.

The Crashlytics "Upload dSYMs" run script phase (already present on all 4 targets, copied
verbatim during target duplication) reads each target's own bundled `GoogleService-Info.plist`
at build time to resolve its Firebase app ID — once each target has its own correct file,
dSYM upload works per-app with no further changes.

**External step (yours):** for each of the 3 apps, in the Firebase console — create a new
project, add an iOS app with that target's exact bundle ID
(`com.vibrito.premierleague2026` / `com.vibrito.ligue12026` / `com.vibrito.primeiraliga2026`),
download the resulting `GoogleService-Info.plist`, hand it to me. I'll give exact
step-by-step instructions when each app's turn comes up in the implementation plan.

## Apple side: automated via the existing ASC API key

The API key already configured in `fastlane/.env.default` (used today for BR2026's
automatic signing/provisioning) has enough permission to register new bundle IDs and
create new App Store Connect app records via `fastlane produce`/the Connect API — no manual
Apple Developer portal clicking needed. I'll still confirm with you before the one
genuinely irreversible action: actually submitting a build for Apple review.

## Fastlane: parameterize the existing lanes

`fastlane/Fastfile` currently hardcodes `SCHEME = "BR2026"` and
`APP_IDENTIFIER = "com.vibrito.br2026"` at file scope, and `fastlane/Appfile` hardcodes
`app_identifier("com.vibrito.br2026")`. Every lane (`test`, `screenshots`, `release_notes`,
`beta`, `prepare_release`, `submit_for_review`) will take an `app:` parameter selecting
among 4 known apps (`br2026`, `premier_league`, `ligue1`, `primeira_liga`), each resolving
to its own scheme name, bundle identifier, and `fastlane/metadata/<app>/` directory. Example:
`bundle exec fastlane beta app:premier_league`. Existing no-arg invocations
(`bundle exec fastlane test`) keep defaulting to `br2026` so nothing breaks for the
already-shipped app.

## Screenshots: fix the UI test's hardwired target application

`BR2026UITests`'s "Target Application" association is fixed to `BR2026` in the pbxproj
regardless of which scheme invokes it — confirmed directly while verifying the icon-picker
rename earlier this session (a test run via `-scheme PremierLeague2026` still launched
`com.vibrito.br2026`). The fix: change `SnapshotUITests.swift` from bare `XCUIApplication()`
to `XCUIApplication(bundleIdentifier:)`, passing the bundle ID for whichever app the
`screenshots` lane is currently targeting (threaded through as a launch argument or
environment variable from the parameterized Fastfile lane). This bypasses the pbxproj-level
association entirely and was already proven working in this session's ad hoc verification.

## Marketing/support/privacy site: extend the existing site

`website/` (deployed to Netlify from this same repo, `netlify.toml` at the repo root)
currently serves BR2026 only (`index.html`, `support/`, `privacy/<locale>/`). Rather than
stand up 3 new Netlify sites, this phase adds a section per league to the same site — new
subpaths (e.g. `/premier-league/`, `/ligue-1/`, `/primeira-liga/`) each with their own
support and privacy pages (identical data-practice content to BR2026's — Firebase
Analytics/Crashlytics only, no accounts, no user-supplied data — reworded per app), plus a
lightweight landing/index update linking to all 4 apps. Each new app's `marketing_url`/
`support_url` metadata fields point at its own subpath on the same site.

## Per-app task shape (repeated 3×, in order)

For each app, in this order:
1. Give you the Firebase console steps for this app; wait for the `GoogleService-Info.plist`.
2. Wire that file into the target via the pbxproj surgery above.
3. Register the bundle ID + create the App Store Connect app record via the API.
4. Add the app's `website/` subpath (support + privacy).
5. Draft App Store metadata (name, subtitle, description, keywords, promotional text,
   release notes) for all 5 locales, mirroring BR2026's tone reworded for the league.
6. Fix and run the `screenshots` lane for this app; verify real screenshots generated.
7. Run `beta` (TestFlight), verify the build lands and processes.
8. Run `prepare_release` (attach build + push metadata/screenshots to the App Store version).
9. Confirm with you, then run `submit_for_review`.

## Out of scope for this phase

- In-app purchases, push notification permission prompts, Watch/CarPlay/widgets — later
  roadmap phases, untouched here.
- `CrossAppLink` stays unwired into any View (per the multi-championship expansion's own
  scoping) — cross-app linking activates once at least one sibling app is actually live,
  which this phase produces for the first time, but wiring it into the UI is a separate,
  future task, not bundled into this one.
- Real device testing — TestFlight builds are produced via `gym`/archive regardless of
  which device or simulator was used for local development testing.
