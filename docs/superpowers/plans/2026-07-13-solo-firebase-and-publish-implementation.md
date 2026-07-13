# Solo Firebase + Publish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Note on this plan's shape:** Tasks 1-3 are ordinary code tasks (write/change files, build,
> test, commit). Tasks 4-6 are per-app *publish runbooks* — most of their steps are external
> actions (Firebase console clicks, waiting for a file from the user, real calls against Apple's
> servers) rather than code-test-commit cycles. Each still has concrete commands and expected
> output; a few steps are marked **STOP — external action required** where the plan cannot
> proceed without a live human action (either the user's, in the Firebase console, or an
> explicit go-ahead before an irreversible submission).

**Goal:** Give Premier League, Ligue 1, and Liga Portugal each their own standalone Firebase
project, then take each through the same TestFlight → App Store pipeline BR2026 already
completed, per `docs/superpowers/specs/2026-07-13-solo-firebase-and-publish-design.md`.

**Architecture:** Firebase separation is pure pbxproj/file surgery (four per-target
`GoogleService-Info.plist` files, no Swift code changes — `FirebaseApp.configure()` already
auto-discovers by filename). Fastlane's lanes become parameterized by an `app:` key resolving
to that app's scheme/bundle ID/metadata path. Apple-side app creation goes through
`fastlane produce` using the existing ASC API key. The 3 apps are done one at a time, in order:
Premier League → Ligue 1 → Liga Portugal.

**Tech Stack:** `xcodeproj` Ruby gem (pbxproj surgery), fastlane (`produce`, `scan`, `snapshot`,
`gym`, `deliver`, `upload_to_testflight`), XCUITest (`XCUIApplication(bundleIdentifier:)`).

## Global Constraints

- Bundle IDs (fixed, already used throughout the project): `com.vibrito.br2026`,
  `com.vibrito.premierleague2026`, `com.vibrito.ligue12026`, `com.vibrito.primeiraliga2026`.
- Scheme names (fixed): `BR2026`, `PremierLeague2026`, `Ligue12026`, `PrimeiraLiga2026`.
- Order: Premier League fully done (through `submit_for_review`) before starting Ligue 1;
  Ligue 1 fully done before starting Liga Portugal.
- Every `submit_for_review` invocation requires an explicit go-ahead in chat first — this is
  the one genuinely irreversible action in the whole plan (per the project's own safety rules
  around actions "visible to others or affecting shared state").
- `CrossAppLink` stays unwired into any View — out of scope for this plan (per the design spec).
- All Ruby pbxproj scripts run via `eval "$(rbenv init -)" && bundle exec ruby -e '...'` from
  the repo root, matching this project's established pattern.
- After every task: run `bundle exec fastlane test app:br2026` (or the plan step's own
  verification) before moving on — never leave a task with a broken build.

---

### Task 1: Parameterize fastlane lanes by app

**Files:**
- Modify: `fastlane/Fastfile`
- Modify (via `git mv`, preserving history): `fastlane/metadata/*` → `fastlane/metadata/br2026/*`
- Modify (via `git mv`): `fastlane/screenshots/*` → `fastlane/screenshots/br2026/*`

**Interfaces:**
- Produces: an `APPS` hash keyed by `"br2026"` / `"premier_league"` / `"ligue1"` /
  `"primeira_liga"`, each mapping to `{ scheme:, bundle_id:, metadata_path:, screenshots_path: }`.
  A `resolve_app(options)` helper reads `options[:app]` (defaulting to `"br2026"`) and raises via
  `UI.user_error!` on an unknown key. Every lane below takes this as its first line.

- [ ] **Step 1: Move the existing metadata and screenshots into `br2026` subfolders**

```bash
cd /Users/mlbbr-mac-vinicius/projects/footballWhiteLabel
mkdir -p fastlane/metadata/br2026 fastlane/screenshots/br2026
for d in en-GB en-US fr-FR pt-BR pt-PT; do
  git mv "fastlane/metadata/$d" "fastlane/metadata/br2026/$d"
  git mv "fastlane/screenshots/$d" "fastlane/screenshots/br2026/$d"
done
git mv fastlane/metadata/copyright.txt fastlane/metadata/br2026/copyright.txt
git mv fastlane/screenshots/screenshots.html fastlane/screenshots/br2026/screenshots.html
```

- [ ] **Step 2: Verify the move left nothing behind**

Run: `find fastlane/metadata fastlane/screenshots -maxdepth 1`
Expected: only `br2026/` under each (plus fastlane/screenshots may still show other stray
files like `.DS_Store` — fine to ignore).

- [ ] **Step 3: Rewrite `fastlane/Fastfile` in full**

```ruby
default_platform(:ios)

APPS = {
  "br2026" => {
    scheme: "BR2026",
    bundle_id: "com.vibrito.br2026",
    metadata_path: "fastlane/metadata/br2026",
    screenshots_path: "fastlane/screenshots/br2026"
  },
  "premier_league" => {
    scheme: "PremierLeague2026",
    bundle_id: "com.vibrito.premierleague2026",
    metadata_path: "fastlane/metadata/premier_league",
    screenshots_path: "fastlane/screenshots/premier_league"
  },
  "ligue1" => {
    scheme: "Ligue12026",
    bundle_id: "com.vibrito.ligue12026",
    metadata_path: "fastlane/metadata/ligue1",
    screenshots_path: "fastlane/screenshots/ligue1"
  },
  "primeira_liga" => {
    scheme: "PrimeiraLiga2026",
    bundle_id: "com.vibrito.primeiraliga2026",
    metadata_path: "fastlane/metadata/primeira_liga",
    screenshots_path: "fastlane/screenshots/primeira_liga"
  }
}.freeze

def resolve_app(options)
  key = (options[:app] || "br2026").to_s
  APPS.fetch(key) { UI.user_error!("Unknown app '#{key}' — expected one of: #{APPS.keys.join(', ')}") }
end

def asc_api_key
  app_store_connect_api_key(
    key_id: ENV["ASC_KEY_ID"],
    issuer_id: ENV["ASC_ISSUER_ID"],
    key_filepath: ENV["ASC_KEY_FILEPATH"]
  )
end

# Shared by beta and prepare_release: xcodebuild's automatic signing only
# refreshes provisioning profiles (e.g. to pick up a newly added capability
# like Push Notifications) when explicitly told to via -allowProvisioningUpdates,
# and needs API key auth (with at least the App Manager role — Developer-role
# keys can't manage certs/profiles) to do so non-interactively from the CLI.
def build_and_upload_to_testflight(app:, api_key:, build_number:, skip_submission: false)
  provisioning_update_args = [
    "-allowProvisioningUpdates",
    "-authenticationKeyPath \"#{ENV['ASC_KEY_FILEPATH']}\"",
    "-authenticationKeyID \"#{ENV['ASC_KEY_ID']}\"",
    "-authenticationKeyIssuerID \"#{ENV['ASC_ISSUER_ID']}\""
  ].join(" ")

  gym(
    scheme: app[:scheme],
    export_method: "app-store",
    output_directory: "./build",
    clean: true,
    xcargs: "CURRENT_PROJECT_VERSION=#{build_number}",
    export_xcargs: provisioning_update_args
  )

  upload_to_testflight(
    api_key: api_key,
    app_identifier: app[:bundle_id],
    skip_submission: skip_submission,
    skip_waiting_for_build_processing: false
  )
end

platform :ios do
  desc "Run the BR2026Tests unit test suite"
  lane :test do |options|
    app = resolve_app(options)
    scan(scheme: app[:scheme], devices: ["iPhone 17"])
  end

  desc "Generate App Store screenshots for all supported locales"
  lane :screenshots do |options|
    app = resolve_app(options)
    snapshot(
      scheme: app[:scheme],
      output_directory: app[:screenshots_path],
      xcargs: "TEST_RUNNER_SNAPSHOT_BUNDLE_ID=#{app[:bundle_id]}"
    )
  end

  desc "Push release notes (What's New) to App Store Connect"
  lane :release_notes do |options|
    app = resolve_app(options)
    deliver(
      api_key: asc_api_key,
      app_identifier: app[:bundle_id],
      metadata_path: app[:metadata_path],
      skip_binary_upload: true,
      skip_screenshots: true,
      skip_metadata: false,
      submit_for_review: false,
      run_precheck_before_submit: false
    )
  end

  desc "Build and upload a TestFlight beta"
  lane :beta do |options|
    app = resolve_app(options)
    api_key = asc_api_key
    build_number = (latest_testflight_build_number(api_key: api_key, app_identifier: app[:bundle_id]) + 1).to_s

    build_and_upload_to_testflight(app: app, api_key: api_key, build_number: build_number)
  end

  desc "Build a fresh binary, attach it to the App Store version, and push metadata + screenshots — does NOT submit for review"
  lane :prepare_release do |options|
    app = resolve_app(options)
    api_key = asc_api_key
    build_number = (latest_testflight_build_number(api_key: api_key, app_identifier: app[:bundle_id]) + 1).to_s

    build_and_upload_to_testflight(app: app, api_key: api_key, build_number: build_number, skip_submission: true)

    deliver(
      api_key: api_key,
      app_identifier: app[:bundle_id],
      metadata_path: app[:metadata_path],
      screenshots_path: app[:screenshots_path],
      build_number: build_number,
      skip_binary_upload: true,
      skip_screenshots: false,
      skip_metadata: false,
      submit_for_review: false,
      run_precheck_before_submit: false,
      force: true
    )

    # deliver's build_number: param does not reliably attach the build to the
    # App Store version (observed: it silently left a July 3rd build attached
    # instead of the one just uploaded) — set it explicitly via the Connect API.
    connect_app = Spaceship::ConnectAPI::App.find(app[:bundle_id])
    version = connect_app.get_edit_app_store_version
    build = connect_app.get_builds(filter: { processingState: "VALID", version: build_number }).first
    UI.user_error!("Build #{build_number} not found or not yet VALID") unless build
    Spaceship::ConnectAPI.patch_app_store_version_with_build(app_store_version_id: version.id, build_id: build.id)
    UI.success("Attached build #{build_number} to App Store version #{version.version_string}")
  end

  desc "Submit the currently-attached build for Apple review — does NOT auto-release; requires a manual Release click in App Store Connect after approval"
  lane :submit_for_review do |options|
    app = resolve_app(options)
    deliver(
      api_key: asc_api_key,
      app_identifier: app[:bundle_id],
      metadata_path: app[:metadata_path],
      skip_binary_upload: true,
      skip_screenshots: true,
      skip_metadata: true,
      submit_for_review: true,
      automatic_release: false,
      run_precheck_before_submit: false,
      force: true,
      submission_information: {
        # This app only talks to its backend over standard HTTPS — no custom
        # or non-exempt encryption — so it qualifies for the export
        # compliance exemption.
        export_compliance_uses_encryption: false
      }
    )
  end

  desc "Register a bundle ID and create its App Store Connect app record (one-time, per new app)"
  lane :create_app do |options|
    app = resolve_app(options)
    produce(
      api_key: asc_api_key,
      app_identifier: app[:bundle_id],
      app_name: options[:app_name] || UI.user_error!("Pass app_name: \"Display Name\""),
      language: "English",
      skip_itc: false
    )
  end
end
```

- [ ] **Step 4: Verify BR2026's own lanes still work unaffected**

Run: `eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: same result as the no-arg `bundle exec fastlane test` before this change — 67 tests,
0 failures (defaulting `app:` to `"br2026"` must produce identical behavior to before).

Also run: `bundle exec ruby -c fastlane/Fastfile`
Expected: `Syntax OK`

- [ ] **Step 5: Commit**

```bash
git add fastlane/Fastfile fastlane/metadata fastlane/screenshots
git commit -m "Parameterize fastlane lanes by app; move BR2026 metadata/screenshots into their own subfolder"
```

---

### Task 2: Fix the screenshots UI test's hardwired target application

**Files:**
- Modify: `BR2026UITests/SnapshotUITests.swift`

**Interfaces:**
- Consumes: the `TEST_RUNNER_SNAPSHOT_BUNDLE_ID` xcarg set by Task 1's `screenshots` lane (an
  xcodebuild convention: any `TEST_RUNNER_<VAR>` xcarg becomes the environment variable `<VAR>`
  inside the test runner process at runtime).

- [ ] **Step 1: Rewrite `BR2026UITests/SnapshotUITests.swift` in full**

```swift
import XCTest

@MainActor
final class SnapshotUITests: XCTestCase {
    private var targetBundleID: String {
        ProcessInfo.processInfo.environment["SNAPSHOT_BUNDLE_ID"] ?? "com.vibrito.br2026"
    }

    func testCaptureScreenshots() {
        let app = XCUIApplication(bundleIdentifier: targetBundleID)
        setupSnapshot(app)
        app.launch()

        let tabBar = app.tabBars.firstMatch
        _ = tabBar.waitForExistence(timeout: 10)

        tabBar.buttons.element(boundBy: 0).tap()
        sleep(5)
        snapshot("01Matchday")

        tabBar.buttons.element(boundBy: 1).tap()
        sleep(5)
        snapshot("02Fixtures")

        tabBar.buttons.element(boundBy: 2).tap()
        sleep(5)
        snapshot("03Standings")

        tabBar.buttons.element(boundBy: 3).tap()
        sleep(1)
        snapshot("04More")
    }
}
```

- [ ] **Step 2: Regression-verify against BR2026 (the already-shipped app)**

Run: `eval "$(rbenv init -)" && bundle exec fastlane screenshots app:br2026`
Expected: succeeds, writes into `fastlane/screenshots/br2026/<locale>/`, and the images show
BR2026 content (Brasileirão branding) exactly as before this change — confirming the explicit
`bundleIdentifier:` path didn't regress the already-working app.

- [ ] **Step 3: Commit**

```bash
git add BR2026UITests/SnapshotUITests.swift
git commit -m "Fix screenshots lane to target the correct app via explicit bundle ID"
```

---

### Task 3: Firebase per-target file separation (mechanism + apply to BR2026)

**Files:**
- Create: `BR2026/Firebase/BR2026/GoogleService-Info.plist` (copy of the existing file)
- Modify: `BR2026.xcodeproj/project.pbxproj` (via Ruby script — BR2026 target's Resources
  phase now references its own dedicated file instead of the shared one)

**Interfaces:**
- Produces: a reusable Ruby method `give_target_own_firebase_file(project, target_name:,
  source_plist_path:)` — later tasks call this once per new app, passing that app's real
  downloaded plist path.

- [ ] **Step 1: Run the pbxproj surgery script**

```bash
cd /Users/mlbbr-mac-vinicius/projects/footballWhiteLabel
eval "$(rbenv init -)"
bundle exec ruby -e '
require "xcodeproj"
require "fileutils"

def give_target_own_firebase_file(project, target_name:, source_plist_path:)
  target = project.targets.find { |t| t.name == target_name } or raise "No target named #{target_name}"
  dest_dir = "BR2026/Firebase/#{target_name}"
  FileUtils.mkdir_p(dest_dir)
  FileUtils.cp(source_plist_path, "#{dest_dir}/GoogleService-Info.plist")

  resources_phase = target.resources_build_phase
  resources_phase.files.dup.each do |bf|
    next unless bf.file_ref && bf.file_ref.path.to_s.include?("GoogleService-Info")
    resources_phase.remove_build_file(bf)
  end

  group = project.main_group.find_subpath(dest_dir, true)
  group.set_source_tree("<group>")
  new_ref = group.new_reference("GoogleService-Info.plist")
  resources_phase.add_file_reference(new_ref)
end

project = Xcodeproj::Project.open("BR2026.xcodeproj")
give_target_own_firebase_file(project, target_name: "BR2026", source_plist_path: "BR2026/GoogleService-Info.plist")
project.save
puts "Done: BR2026 now references BR2026/Firebase/BR2026/GoogleService-Info.plist"
'
```

Note: the original shared file at `BR2026/GoogleService-Info.plist` is left on disk and still
referenced by `PremierLeague2026`/`Ligue12026`/`PrimeiraLiga2026`'s Resources phases —
untouched by this step. It's only safe to delete once all 3 have been peeled off (end of
Task 6).

- [ ] **Step 2: Verify BR2026 still builds, tests pass, and Firebase still initializes**

Run: `xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation build`
Expected: `** BUILD SUCCEEDED **`

Run: `eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: 67 tests, 0 failures.

Install and launch BR2026 on a simulator; confirm it reaches the Matchday screen rather than
crashing on launch (a missing/misconfigured `GoogleService-Info.plist` causes
`FirebaseApp.configure()` to crash immediately) — reuse the install/launch pattern already
established earlier in this project (fresh `simctl install` + `simctl launch`, checked via
screenshot).

- [ ] **Step 3: Verify the other 3 targets are unaffected**

Run: `xcodebuild -project BR2026.xcodeproj -scheme PremierLeague2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation build` (repeat for `Ligue12026`, `PrimeiraLiga2026`)
Expected: `** BUILD SUCCEEDED **` for all three — they still reference the original shared
file, untouched by this task.

- [ ] **Step 4: Commit**

```bash
git add BR2026.xcodeproj/project.pbxproj BR2026/Firebase
git commit -m "Give BR2026 its own dedicated GoogleService-Info.plist file (mechanism for per-app Firebase separation)"
```

---

### Task 4: Premier League — Firebase, Apple registration, and publish

**Files:**
- Create: `BR2026/Firebase/PremierLeague2026/GoogleService-Info.plist` (from the file you
  download)
- Modify: `BR2026.xcodeproj/project.pbxproj` (via the Task 3 helper)
- Create: `fastlane/metadata/premier_league/<locale>/*.txt` (7 files × 5 locales)
- Create: `website/premier-league/index.html`, `website/premier-league/support/index.html`,
  `website/premier-league/privacy/<locale>/index.html`
- Modify: `website/index.html` (add a Premier League entry)

- [ ] **Step 1: STOP — external action required. Create the Firebase project**

Give the user these exact steps and wait for the resulting file:
1. Go to the Firebase console → Add project → name it (e.g. "Premier League 2026").
2. Inside the new project: Add app → iOS → bundle ID `com.vibrito.premierleague2026` →
   register.
3. Download the generated `GoogleService-Info.plist`.
4. Enable the same products BR2026 uses: Analytics (on by default), Crashlytics, Cloud
   Messaging — no extra console configuration needed for Messaging/Crashlytics beyond having
   added the iOS app.
5. Hand the downloaded file's path to continue.

- [ ] **Step 2: Wire the file in**

```bash
cd /Users/mlbbr-mac-vinicius/projects/footballWhiteLabel
eval "$(rbenv init -)"
bundle exec ruby -e '
require "xcodeproj"
require "fileutils"

def give_target_own_firebase_file(project, target_name:, source_plist_path:)
  target = project.targets.find { |t| t.name == target_name } or raise "No target named #{target_name}"
  dest_dir = "BR2026/Firebase/#{target_name}"
  FileUtils.mkdir_p(dest_dir)
  FileUtils.cp(source_plist_path, "#{dest_dir}/GoogleService-Info.plist")

  resources_phase = target.resources_build_phase
  resources_phase.files.dup.each do |bf|
    next unless bf.file_ref && bf.file_ref.path.to_s.include?("GoogleService-Info")
    resources_phase.remove_build_file(bf)
  end

  group = project.main_group.find_subpath(dest_dir, true)
  group.set_source_tree("<group>")
  new_ref = group.new_reference("GoogleService-Info.plist")
  resources_phase.add_file_reference(new_ref)
end

project = Xcodeproj::Project.open("BR2026.xcodeproj")
give_target_own_firebase_file(project, target_name: "PremierLeague2026", source_plist_path: "<PATH TO DOWNLOADED FILE>")
project.save
'
```

Verify: build `PremierLeague2026`, install + launch on a simulator, confirm it reaches the
Matchday screen (no Firebase-config crash).

- [x] **Step 3: Register the bundle ID; create the App Store Connect app record**

**Correction discovered while executing this step for Premier League:** app creation via API
key is not actually possible — `produce` unconditionally requires a full Apple ID username
even with an API key configured, and talking to `Spaceship::ConnectAPI::App.create` directly
hits `"The resource 'apps' does not allow 'CREATE'"` regardless of the key's role. Apple's
public App Store Connect API has never supported creating new apps via any API key; it's
web-UI (or full Apple ID session) only. `create_app` was rewritten to only register the
bundle ID (which the API does support) and idempotently verify the app record exists.

Run: `eval "$(rbenv init -)" && bundle exec fastlane create_app app:<key> app_name:"<Display Name>"`
first — it registers the bundle ID and tells you whether the app record already exists.
If not, create it manually in App Store Connect: **Apps → + → New App** — iOS, the display
name, English (U.S.), the bundle ID (already registered, selectable from the dropdown), and a
SKU following the `<scheme-lowercase><year>` convention (e.g. `premierleague2026`). Then
re-run the `create_app` command above to confirm it's now found.

- [ ] **Step 4: Add the website section**

Create `website/premier-league/index.html`, `website/premier-league/support/index.html`, and
`website/premier-league/privacy/en/index.html` (+ the other 4 locales), following the exact
structure of the existing `website/index.html` / `website/support/index.html` /
`website/privacy/en/index.html` (same CSS classes, same layout), reworded for Premier League
(title, tagline, accent color reference `#3D195B`) — content only, no new structural elements.
Add one entry to `website/index.html` linking to `/premier-league/`.

Verify: open each new file locally (or via a quick static server) and visually confirm layout
matches the existing site's look.

- [ ] **Step 5: Draft App Store metadata for all 5 locales**

Create `fastlane/metadata/premier_league/<locale>/{description,keywords,marketing_url,
promotional_text,release_notes,subtitle,support_url}.txt` and
`fastlane/metadata/premier_league/copyright.txt`, for `en-US`, `en-GB`, `fr-FR`, `pt-BR`,
`pt-PT` — following the exact tone/structure of
`fastlane/metadata/br2026/en-US/*.txt` (reworded for the Premier League: teams, competition
name, `marketing_url`/`support_url` pointing at the new `/premier-league/` website section).
Present the drafted English copy to the user for approval before running any lane that pushes
it live.

- [ ] **Step 6: Generate and verify screenshots**

Run: `bundle exec fastlane screenshots app:premier_league`
Expected: succeeds, writes into `fastlane/screenshots/premier_league/<locale>/`, images show
real Premier League branding/data (purple accent, real match data) — visually confirm at
least one image per locale set.

- [ ] **Step 7: TestFlight beta**

Run: `bundle exec fastlane beta app:premier_league`
Expected: builds, uploads, and waits for TestFlight processing to complete successfully.

- [ ] **Step 8: Prepare the release**

Run: `bundle exec fastlane prepare_release app:premier_league`
Expected: build attached to the App Store version; metadata and screenshots pushed
(`skip_metadata: false`, `skip_screenshots: false`).

- [ ] **Step 9: STOP — confirm before submitting**

Show the user the app's current App Store Connect version page state (metadata, screenshots,
attached build) and ask for an explicit go-ahead before submitting.

- [ ] **Step 10: Submit for review**

Run: `bundle exec fastlane submit_for_review app:premier_league`
Expected: submission succeeds; App Store Connect shows `WAITING_FOR_REVIEW`.

- [ ] **Step 11: Commit**

```bash
git add BR2026.xcodeproj/project.pbxproj BR2026/Firebase/PremierLeague2026 \
  fastlane/metadata/premier_league fastlane/screenshots/premier_league \
  website/premier-league website/index.html
git commit -m "Give Premier League its own Firebase project; publish through App Store review"
```

---

### Task 5: Ligue 1 — Firebase, Apple registration, and publish

Same shape as Task 4, substituting Ligue 1's own values throughout.

- [ ] **Step 1: STOP — external action required.** Create a new Firebase project for Ligue 1,
  add an iOS app with bundle ID `com.vibrito.ligue12026`, download its
  `GoogleService-Info.plist`.
- [ ] **Step 2:** Run the same Ruby helper with `target_name: "Ligue12026"` and the downloaded
  file's path. Verify: build `Ligue12026`, install + launch, confirm it reaches Matchday
  without crashing.
- [ ] **Step 3:** Run `bundle exec fastlane create_app app:ligue1 app_name:"Ligue 1 2026"` to
  register the bundle ID and check whether the app record exists. It won't yet — app creation
  requires the App Store Connect web UI (Apple's API doesn't support it via any key role, see
  Task 4 Step 3's note). Create it manually: **Apps → + → New App** — iOS, "Ligue 1 2026",
  English (U.S.), bundle ID `com.vibrito.ligue12026`, SKU `ligue12026`. Re-run the same
  `create_app` command to confirm it's now found.
- [ ] **Step 4:** Create `website/ligue-1/index.html`, `website/ligue-1/support/index.html`,
  `website/ligue-1/privacy/<locale>/index.html` (all 5 locales) mirroring the existing site
  structure, reworded for Ligue 1 (accent `#FACC15`). Add an entry to `website/index.html`.
- [ ] **Step 5:** Draft `fastlane/metadata/ligue1/<locale>/*.txt` for all 5 locales, following
  `fastlane/metadata/br2026/en-US/*.txt`'s structure, reworded for Ligue 1. Get user approval
  on the English copy before pushing.
- [ ] **Step 6:** `bundle exec fastlane screenshots app:ligue1` — verify real Ligue 1
  branding/data in the output images.
- [ ] **Step 7:** `bundle exec fastlane beta app:ligue1` — verify TestFlight processing
  succeeds.
- [ ] **Step 8:** `bundle exec fastlane prepare_release app:ligue1` — verify build attached,
  metadata/screenshots pushed.
- [ ] **Step 9: STOP — confirm before submitting.** Show the user the version page state, get
  an explicit go-ahead.
- [ ] **Step 10:** `bundle exec fastlane submit_for_review app:ligue1` — verify
  `WAITING_FOR_REVIEW`.
- [ ] **Step 11: Commit**

```bash
git add BR2026.xcodeproj/project.pbxproj BR2026/Firebase/Ligue12026 \
  fastlane/metadata/ligue1 fastlane/screenshots/ligue1 \
  website/ligue-1 website/index.html
git commit -m "Give Ligue 1 its own Firebase project; publish through App Store review"
```

---

### Task 6: Liga Portugal — Firebase, Apple registration, publish, and final cleanup

Same shape as Tasks 4/5, substituting Liga Portugal's own values, plus a final cleanup step
once all 3 apps have their own Firebase project.

- [ ] **Step 1: STOP — external action required.** Create a new Firebase project for Primeira
  Liga (public app name "Liga Portugal 2026"), add an iOS app with bundle ID
  `com.vibrito.primeiraliga2026`, download its `GoogleService-Info.plist`.
- [ ] **Step 2:** Run the Ruby helper with `target_name: "PrimeiraLiga2026"` and the downloaded
  file's path. Verify: build `PrimeiraLiga2026`, install + launch, confirm it reaches Matchday
  without crashing.
- [ ] **Step 3:** Run `bundle exec fastlane create_app app:primeira_liga app_name:"Liga Portugal 2026"`
  to register the bundle ID and check whether the app record exists. Create it manually in App
  Store Connect (see Task 4 Step 3's note on why): **Apps → + → New App** — iOS,
  "Liga Portugal 2026", English (U.S.), bundle ID `com.vibrito.primeiraliga2026`, SKU
  `primeiraliga2026`. Re-run the same `create_app` command to confirm it's now found.
- [ ] **Step 4:** Create `website/liga-portugal/index.html`,
  `website/liga-portugal/support/index.html`, `website/liga-portugal/privacy/<locale>/index.html`
  (all 5 locales) mirroring the existing site structure, reworded for Liga Portugal (accent
  `#00235A`, or the tab-selection green `#19FF91` if it reads better against the site's own
  background — use judgment, confirm with the user). Add an entry to `website/index.html`.
- [ ] **Step 5:** Draft `fastlane/metadata/primeira_liga/<locale>/*.txt` for all 5 locales,
  following `fastlane/metadata/br2026/en-US/*.txt`'s structure, reworded for Liga Portugal. Get
  user approval on the English copy before pushing.
- [ ] **Step 6:** `bundle exec fastlane screenshots app:primeira_liga` — verify real Liga
  Portugal branding/data in the output images.
- [ ] **Step 7:** `bundle exec fastlane beta app:primeira_liga` — verify TestFlight processing
  succeeds.
- [ ] **Step 8:** `bundle exec fastlane prepare_release app:primeira_liga` — verify build
  attached, metadata/screenshots pushed.
- [ ] **Step 9: STOP — confirm before submitting.** Show the user the version page state, get
  an explicit go-ahead.
- [ ] **Step 10:** `bundle exec fastlane submit_for_review app:primeira_liga` — verify
  `WAITING_FOR_REVIEW`.
- [ ] **Step 11: Final cleanup — remove the now-fully-orphaned shared Firebase file**

All 4 targets now have their own dedicated `GoogleService-Info.plist` under
`BR2026/Firebase/<Target>/`. The original shared file (still on disk at
`BR2026/GoogleService-Info.plist`, no longer referenced by any target's Resources phase since
Task 3 already moved BR2026 off it and this task's Step 2 moved PrimeiraLiga2026 off it) is
now genuinely unused.

All `PBXFileReference` entries for a file named `GoogleService-Info.plist` store the same
bare `path` value regardless of which group they live in — `grep` on the pbxproj text can't
tell the old top-level one apart from the 4 new ones nested under `Firebase/<Target>/`. Use
the `xcodeproj` gem instead, matching on the file reference's *full resolved path*:

```bash
cd /Users/mlbbr-mac-vinicius/projects/footballWhiteLabel
eval "$(rbenv init -)"
bundle exec ruby -e '
require "xcodeproj"
project = Xcodeproj::Project.open("BR2026.xcodeproj")

old_ref = project.files.find { |f| f.real_path.to_s.end_with?("BR2026/GoogleService-Info.plist") }
raise "Old shared GoogleService-Info.plist reference not found" unless old_ref

users = project.targets.select do |t|
  t.respond_to?(:resources_build_phase) && t.resources_build_phase &&
    t.resources_build_phase.files.any? { |bf| bf.file_ref == old_ref }
end
raise "Still referenced by: #{users.map(&:name).join(", ")}" unless users.empty?

old_ref.remove_from_project
project.save
puts "Removed the old shared GoogleService-Info.plist file reference"
'
rm BR2026/GoogleService-Info.plist
```

Verify: all 4 schemes still build (`xcodebuild ... build` for each), full test suite still
passes.

- [ ] **Step 12: Commit**

```bash
git add BR2026.xcodeproj/project.pbxproj BR2026/Firebase/PrimeiraLiga2026 \
  fastlane/metadata/primeira_liga fastlane/screenshots/primeira_liga \
  website/liga-portugal website/index.html BR2026/GoogleService-Info.plist
git commit -m "Give Liga Portugal its own Firebase project; publish through App Store review; remove orphaned shared Firebase file"
```

---

## Final Verification

- [ ] All 4 schemes build (`BR2026`, `PremierLeague2026`, `Ligue12026`, `PrimeiraLiga2026`).
- [ ] Full test suite passes: `bundle exec fastlane test app:br2026` (67+ tests, 0 failures).
- [ ] Each of the 4 targets has its own dedicated `BR2026/Firebase/<Target>/GoogleService-Info.plist`,
  and the old shared file no longer exists.
- [ ] All 3 new apps show `WAITING_FOR_REVIEW` (or later) in App Store Connect.
- [ ] `website/` serves all 4 apps' support/privacy pages at their own subpaths, linked from
  the root `index.html`.
