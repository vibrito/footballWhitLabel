# Fastlane Release Automation — Design

Date: 2026-07-11
Status: Approved, ready for implementation plan

## Context

The project currently has no build/release automation: no Gemfile, no fastlane, no CI. Xcode
signing is `CODE_SIGN_STYLE = Automatic`, `DEVELOPMENT_TEAM = R4L6C6JGYH`, bundle id
`com.vibrito.br2026`, single scheme `BR2026`. The project stopped using xcodegen as of the
last commit ("Drop xcodegen; manage the Xcode project by hand going forward") — `project.pbxproj`
is now hand-edited and is the source of truth.

Also relevant: an earlier auto-incrementing build-number script (git-commit-count based) was
deliberately removed because it silently overwrote whatever build number was set by hand in
Xcode's General tab. `CURRENT_PROJECT_VERSION` is now a manually-maintained value. Any new
automation must not reintroduce a script that clobbers that field.

Goal: add fastlane to (1) run the test suite, (2) build and upload TestFlight betas, (3)
generate App Store screenshots for all five supported locales, (4) push "What's New" release
notes to App Store Connect. CI (GitHub Actions) and `match`-based signing are explicitly out
of scope for this pass — lanes are run locally from Terminal, and signing continues to use
Xcode's existing Automatic profile management.

## Ruby toolchain

System Ruby is 2.6.10 (Apple's frozen/EOL build) — too old to safely trust for fastlane's
native gem dependencies (nokogiri, etc.). Add:

- `Gemfile` — `gem "fastlane"`, version pinned to a `~>` constraint on the latest 2.x release
  available at implementation time.
- `Gemfile.lock` — committed, so every machine resolves the same gem set.
- `.ruby-version` — pins a modern Ruby (3.3.x) for rbenv/asdf/Homebrew-ruby users. Does not
  install a Ruby version manager itself; assumes the developer has one, or falls back to
  system Ruby with a warning if `bundle install` fails.

All lanes are invoked as `bundle exec fastlane <lane>`.

## Layout

```
Gemfile
Gemfile.lock
.ruby-version
fastlane/
  Appfile                        # app_identifier, apple_id, team_id
  Fastfile                       # lanes: test, screenshots, release_notes, beta
  Snapfile                       # devices + languages for `snapshot`
  Deliverfile                    # shared deliver config (skip_binary_upload defaults, etc.)
  metadata/
    en-US/release_notes.txt
    en-GB/release_notes.txt
    pt-BR/release_notes.txt
    pt-PT/release_notes.txt
    fr-FR/release_notes.txt
  .env.default.example           # checked in template (ASC key id/issuer id/path placeholders)
  .env.default                   # gitignored — real values, mirrors Secrets.xcconfig pattern
BR2026UITests/                   # new XCUITest target
  SnapshotHelper.swift           # fastlane's standard snapshot helper (vendored, not hand-written)
  SnapshotUITests.swift          # one XCTestCase visiting each of the 4 tabs
```

`.gitignore` gains: `fastlane/screenshots/`, `fastlane/test_output/`, `fastlane/.env.default`,
`*.p8`.

## Authentication

App Store Connect API key (`.p8`), read via `app_store_connect_api_key` in the Fastfile from
`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_FILEPATH` in `.env.default`. No Apple ID / 2FA / session
cookie flow. The `.p8` file itself lives outside the repo (path referenced by
`ASC_KEY_FILEPATH`), same as how `Secrets.xcconfig` keeps the API key out of git.

## New XCUITest target (`BR2026UITests`)

`fastlane snapshot` requires a UI test target — none exists today (only the `BR2026Tests` unit
test bundle). Adding it means creating a new Xcode target. Since the project is hand-managed
(no xcodegen), the target is added programmatically with the `xcodeproj` Ruby gem (a fastlane
dependency already) rather than by hand-editing `project.pbxproj` text — same end state as
using Xcode's "New Target" wizard, but scriptable and reviewable as a diff. After creation,
`xcodebuild -list` is used to confirm the target/scheme picked it up, and the lane is run once
to confirm it builds and produces images.

The UI test target uses XCTest/XCUITest (not Swift Testing) — this is what fastlane's
`SnapshotHelper.swift` is built around, and it's UI/E2E scaffolding, not the ViewModel/Service
unit tests `CLAUDE.md`'s testing section governs.

## Deterministic screenshots (no live API dependency)

`fastlane snapshot` sets `FASTLANE_SNAPSHOT=YES` in the app's launch environment automatically.
`Championship.swift`'s `makeService()` gets one added check: if `FASTLANE_SNAPSHOT` is set in
`ProcessInfo.processInfo.environment`, return `MockMatchService()` directly, skipping the
`LiveMatchService` attempt. This reuses the existing `MatchService` protocol split (no new
launch-argument plumbing) and makes screenshots reproducible regardless of the live season/API
state.

```swift
private func makeService() -> MatchService {
    if ProcessInfo.processInfo.environment["FASTLANE_SNAPSHOT"] == "YES" {
        return MockMatchService()
    }
    let context = ModelContext(modelContainer)
    if let live = try? LiveMatchService.makeFromBundle(config: config, modelContext: context) {
        return live
    }
    return MockMatchService()
}
```

Locales: `en-US`, `en-GB`, `pt-BR`, `pt-PT`, `fr-FR` (fr maps to the `fr-FR` region code, which
is what simulators and App Store Connect both expect).

**Known gap:** `Localizable.xcstrings` currently only has `en` string values. Screenshots for
the other four locales will show English UI text (team/venue names are server-driven and
unaffected either way) until those locales get real translations — that's a separate,
unscoped localization effort. The lane is still wired for all five now so it's ready the
moment translations land.

Devices: two simulator classes — the largest current iPhone (e.g. "iPhone 17 Pro Max", 6.9",
which is what App Store Connect actually requires) plus one smaller class (e.g. "iPhone 17")
for broader visual QA.

`fastlane screenshots` writes to `fastlane/screenshots/` only — no automatic upload to App
Store Connect. Uploading is a deliberate separate step added later, once output has been
reviewed.

## Lanes

- **`test`** — `scan` (xcodebuild test) against scheme `BR2026`.
- **`screenshots`** — `snapshot` across the 5 locales × 2 device classes, writes to
  `fastlane/screenshots/`.
- **`release_notes`** — `deliver(skip_binary_upload: true, skip_screenshots: true,
  submit_for_review: false)`, pushing only `fastlane/metadata/<locale>/release_notes.txt`
  ("What's New") to App Store Connect.
- **`beta`** — build number is computed as `latest_testflight_build_number + 1` at run time
  (in-memory only; never written back to `project.pbxproj` or Xcode's General tab field, so it
  can't fight with a manually-set value). Runs `gym` to archive using the existing Automatic
  signing, then `upload_to_testflight` to ship the build.

## Documentation

Add a short "Fastlane / Release Automation" section to `CLAUDE.md`, listing the four lanes and
the one-time `.env.default` setup step, in the same style as the existing "Backend API"
section.

## Out of scope

- CI (GitHub Actions) integration — lanes are local-only for this phase.
- `match`-based code signing — Automatic signing stays as-is.
- Actual translation of the four non-English locales.
- Auto-uploading screenshots to App Store Connect.
- Full App Store submission (`submit_for_review`) — `release_notes` only pushes metadata.
