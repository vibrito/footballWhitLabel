# Multi-Championship Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add three new Xcode targets (Premier League, Ligue 1, Primeira Liga) sharing all
existing source with `BR2026`, per
`docs/superpowers/specs/2026-07-13-multi-championship-expansion-design.md`.

**Architecture:** Duplicate the `BR2026` native target three times via the `xcodeproj` Ruby
gem (same tool this project already uses for structural pbxproj changes, per `CLAUDE.md`'s
Firebase integration precedent) — copying all build phases, package product dependencies,
and build settings, then overriding only what's target-specific (bundle ID, display name,
compilation condition flag, app icon). `ChampionshipConfig` selection happens via `#if`
compiler flags in the one shared `Championship.swift` entry point.

**Tech Stack:** Xcodeproj Ruby gem (`bundle exec ruby`, via the project's pinned rbenv
toolchain), Swift compiler conditionals, AppKit (`NSImage(systemSymbolName:)` +
`NSBitmapImageRep`) for one-off placeholder icon rendering — not part of the shipped app.

## Global Constraints

- Backend already serves all three leagues end-to-end (verified directly against the live
  API before starting: `PL` → 380 matches, `FL1` → 306 matches, `PPL` → 306 matches, all
  with populated standings) — no backend work in this plan.
- New targets: `PremierLeague2026` (`com.vibrito.premierleague2026`, "Premier League 2026",
  accent `#3D195B`), `Ligue12026` (`com.vibrito.ligue12026`, "Ligue 1 2026", accent
  `#FACC15`), `PrimeiraLiga2026` (`com.vibrito.primeiraliga2026`, "Primeira Liga 2026",
  accent `#00235A`).
- The `CrossAppLink` model/resolver (item #6) is built but explicitly **not** wired into
  any View in this phase — no "Our Other Apps" section ships yet.
- Firebase/App Store Connect/bundle-ID registration for the 3 new apps are manual,
  external steps outside this plan's scope (see spec's "External Setup Required").
  Until the user provides per-target `GoogleService-Info.plist` files, all four targets
  share `BR2026`'s Firebase project (Analytics/Crashlytics/Messaging data from all four
  apps lands in one Firebase project) — this is a known, intentional bootstrap state, not
  a bug.

---

### Task 1: Add new `ChampionshipConfig` values and tests

**Files:**
- Modify: `BR2026/Config/ChampionshipConfig.swift`
- Modify: `BR2026Tests/Config/ChampionshipConfigTests.swift`

- [x] **Step 1:** Add `premierLeague`, `ligue1`, `primeiraLiga` static values to
  `ChampionshipConfig`, sharing `.brasileirao`'s existing `apiBaseURL` via a private
  `sharedAPIBaseURL` constant (all four leagues are served by the same backend).
- [x] **Step 2:** Add one test per new config to `ChampionshipConfigTests`, mirroring
  `brasileiraoDefaults()`'s exact assertion shape (id, competitionCode, displayName,
  accentColorHex, apiBaseURL).
- [x] **Step 3:** Run `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test`
  — verified passing (63 tests at this point, up from 60).
- [x] **Step 4:** Commit.

---

### Task 2: Wire `#if` config selection into `Championship.swift`

**Files:**
- Modify: `BR2026/App/Championship.swift`

- [x] **Step 1:** Replace the hardcoded `let config = ChampionshipConfig.brasileirao` with
  an `#if TARGET_PREMIER_LEAGUE / #elseif TARGET_LIGUE_1 / #elseif TARGET_PRIMEIRA_LIGA /
  #else` selection (the `#else` branch keeps `.brasileirao`, so `BR2026` itself needs no
  new compiler flag).
- [x] **Step 2:** Build `BR2026` scheme — confirm unaffected (still resolves to
  `.brasileirao` via the `#else` branch).
- [x] **Step 3:** Commit alongside Task 3 (the flag has no effect until a target actually
  defines it).

---

### Task 3: Duplicate the `BR2026` target for each new app

**Files:**
- Modify: `BR2026.xcodeproj/project.pbxproj` (via Ruby script, not hand-edited)
- Modify: `Generated/BR2026-Info.plist` (bug fix, see Step 0 below)
- Create: `BR2026.xcodeproj/xcshareddata/xcschemes/PremierLeague2026.xcscheme`,
  `Ligue12026.xcscheme`, `PrimeiraLiga2026.xcscheme`

**Interfaces:**
- Consumes: `ChampionshipConfig.premierLeague` / `.ligue1` / `.primeiraLiga` (Task 1), the
  `TARGET_PREMIER_LEAGUE` / `TARGET_LIGUE_1` / `TARGET_PRIMEIRA_LIGA` flags (Task 2).

- [x] **Step 0: Fix a pre-existing display-name bug that blocks this task**

  `Generated/BR2026-Info.plist` (the partial Info.plist merged in via
  `GENERATE_INFOPLIST_FILE = YES`) had `CFBundleDisplayName` hardcoded as the literal
  string `"BR 2026"`, instead of the `$(INFOPLIST_KEY_CFBundleDisplayName)` variable
  substitution every other similar key uses. Since all targets share this one partial
  Info.plist file, this silently overrides each target's own
  `INFOPLIST_KEY_CFBundleDisplayName` build setting — discovered when `PremierLeague2026`
  built successfully but showed "BR 2026" as its name instead of "Premier League 2026".

  Fix: change
  ```xml
  <key>CFBundleDisplayName</key>
  <string>BR 2026</string>
  ```
  to
  ```xml
  <key>CFBundleDisplayName</key>
  <string>$(INFOPLIST_KEY_CFBundleDisplayName)</string>
  ```
  No behavior change for `BR2026` itself (its build setting is already `"BR 2026"`).

- [x] **Step 1: Duplicate the target via `xcodeproj`**

  Run (once per new target — `new_name`/`bundle_id`/`display_name`/`compilation_condition`
  change each time):
  ```ruby
  require "xcodeproj"
  project = Xcodeproj::Project.open("BR2026.xcodeproj")
  source_target = project.targets.find { |t| t.name == "BR2026" }

  def duplicate_target(project, source_target, new_name:, bundle_id:, display_name:, compilation_condition:)
    new_target = project.new(Xcodeproj::Project::Object::PBXNativeTarget)
    new_target.name = new_name
    new_target.product_name = new_name
    new_target.product_type = source_target.product_type
    project.targets << new_target

    products_group = project.products_group
    product_ref = products_group.new_reference("#{new_name}.app")
    product_ref.source_tree = "BUILT_PRODUCTS_DIR"
    product_ref.include_in_index = "0"
    product_ref.explicit_file_type = source_target.product_reference.explicit_file_type
    new_target.product_reference = product_ref

    source_target.build_phases.each do |phase|
      case phase
      when Xcodeproj::Project::Object::PBXSourcesBuildPhase
        new_phase = project.new(Xcodeproj::Project::Object::PBXSourcesBuildPhase)
        phase.files.each { |bf| new_phase.add_file_reference(bf.file_ref) }
        new_target.build_phases << new_phase
      when Xcodeproj::Project::Object::PBXResourcesBuildPhase
        new_phase = project.new(Xcodeproj::Project::Object::PBXResourcesBuildPhase)
        phase.files.each { |bf| new_phase.add_file_reference(bf.file_ref) }
        new_target.build_phases << new_phase
      when Xcodeproj::Project::Object::PBXFrameworksBuildPhase
        new_phase = project.new(Xcodeproj::Project::Object::PBXFrameworksBuildPhase)
        phase.files.each { |bf| new_phase.add_file_reference(bf.file_ref) if bf.file_ref }
        new_target.build_phases << new_phase
      when Xcodeproj::Project::Object::PBXShellScriptBuildPhase
        new_phase = project.new(Xcodeproj::Project::Object::PBXShellScriptBuildPhase)
        new_phase.name = phase.name
        new_phase.shell_path = phase.shell_path
        new_phase.shell_script = phase.shell_script
        new_phase.input_paths = phase.input_paths
        new_phase.output_paths = phase.output_paths
        new_target.build_phases << new_phase
      end
    end

    source_target.package_product_dependencies.each { |dep| new_target.package_product_dependencies << dep }

    new_config_list = project.new(Xcodeproj::Project::Object::XCConfigurationList)
    new_config_list.default_configuration_is_visible = source_target.build_configuration_list.default_configuration_is_visible
    new_config_list.default_configuration_name = source_target.build_configuration_list.default_configuration_name

    source_target.build_configuration_list.build_configurations.each do |source_config|
      new_config = project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
      new_config.name = source_config.name
      new_config.build_settings = source_config.build_settings.dup
      new_config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = bundle_id
      new_config.build_settings["PRODUCT_NAME"] = new_name
      new_config.build_settings["INFOPLIST_KEY_CFBundleDisplayName"] = display_name
      # Always prefix with $(inherited): the source target usually has no explicit
      # target-level override here (it inherits the project-level "DEBUG" default for
      # Debug builds) — setting a bare value at the target level would shadow that
      # inherited default instead of adding to it.
      existing_conditions = new_config.build_settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"]
      parts = ["$(inherited)", existing_conditions, compilation_condition].compact
      new_config.build_settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = parts.join(" ")
      new_config_list.build_configurations << new_config
    end
    new_target.build_configuration_list = new_config_list
    new_target
  end

  duplicate_target(project, source_target, new_name: "PremierLeague2026", bundle_id: "com.vibrito.premierleague2026", display_name: "Premier League 2026", compilation_condition: "TARGET_PREMIER_LEAGUE")
  duplicate_target(project, source_target, new_name: "Ligue12026", bundle_id: "com.vibrito.ligue12026", display_name: "Ligue 1 2026", compilation_condition: "TARGET_LIGUE_1")
  duplicate_target(project, source_target, new_name: "PrimeiraLiga2026", bundle_id: "com.vibrito.primeiraliga2026", display_name: "Primeira Liga 2026", compilation_condition: "TARGET_PRIMEIRA_LIGA")
  project.save
  ```

- [x] **Step 2: Generate a shared scheme per new target**

  Each is `BR2026.xcscheme` with its `BlueprintIdentifier` and `BuildableName`/
  `BlueprintName` substituted for the new target's UUID and name (`sed` on the existing
  scheme XML is sufficient — the scheme references the same `BR2026Tests`/
  `BR2026UITests` testable targets, since those test shared logic regardless of which app
  target ships it).

- [x] **Step 3: Build each new scheme**

  Run for each: `xcodebuild -project BR2026.xcodeproj -scheme <Name> -destination 'generic/platform=iOS Simulator' -skipMacroValidation build`
  Expected: `** BUILD SUCCEEDED **` for all three, and `BR2026` itself still builds
  unaffected.

- [x] **Step 4: Runtime-verify at least one new target**

  Installed `PremierLeague2026.app` to a Simulator, launched it, confirmed via screenshot:
  real Premier League match data (backend already serves it) and the purple `#3D195B`
  accent color on the tab bar — proving both the target duplication and the `#if` config
  selection work end-to-end, not just "compiles."

- [x] **Step 5: Commit** (`BR2026.xcodeproj/project.pbxproj`, the 3 new `.xcscheme` files,
  `Generated/BR2026-Info.plist`, `Championship.swift`, `ChampionshipConfig.swift` +
  its tests together).

---

### Task 4: Fix `AppIconOption` for non-Brasileirão targets

**Files:**
- Modify: `BR2026/Models/AppIconOption.swift`

Discovered during Task 3 verification: `AppIconOption` (shared code, the More screen's
"App Icon" picker) hardcodes `.brasil`/`.stadium` alongside `.light` — meaning the new
apps would offer a Brasil-flag-themed alternate icon, which is wrong branding for
Premier League/Ligue 1/Primeira Liga.

- [x] **Step 1:** Wrap the `.brasil`/`.stadium` cases (and their matching arms in every
  `switch self` in the file) in
  `#if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA)` /
  `#endif`, so only `BR2026` gets those two extra options; the 3 new targets only offer
  `.light`.
- [x] **Step 2:** Confirmed `BR2026Tests`'s existing `AppIconPickerViewModelTests` (which
  references `.brasil`/`.stadium` directly) needs no changes — it always compiles against
  the `BR2026` target specifically via `@testable import BR2026`, which never defines any
  of the three `TARGET_*` flags.
- [x] **Step 3:** Build `BR2026` and `PremierLeague2026` — both succeed.
- [x] **Step 4:** Commit alongside Task 5 (discovered while verifying icons).

---

### Task 5: Generate and wire placeholder app icons per new target

**Files:**
- Create: `BR2026/Resources/Assets.xcassets/AppIcon-PremierLeague.appiconset/`,
  `AppIcon-Ligue1.appiconset/`, `AppIcon-PrimeiraLiga.appiconset/` (each with a
  `Contents.json` + one 1024×1024 PNG)
- Modify: `BR2026.xcodeproj/project.pbxproj` (via Ruby script — set each new target's
  `ASSETCATALOG_COMPILER_APPICON_NAME`, clear its
  `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`)

- [x] **Step 1:** Render one 1024×1024 PNG per new target: a radial-gradient background at
  the target's own accent color (same visual language as the existing "Stadium"
  alternate icon) with a centered white `soccerball` SF Symbol at ~55% of the icon's
  width. One-off AppKit rendering script (not committed — only its PNG output is),
  parameterized by hex color and output path.
- [x] **Step 2:** Create each `AppIcon-<League>.appiconset/Contents.json`, mirroring the
  existing `AppIcon.appiconset/Contents.json`'s single-image, `universal`/`ios`/
  `1024x1024` shape exactly.
- [x] **Step 3:** For each new target, set
  `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon-<League>` and delete the
  `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` key entirely (that build setting was
  copied verbatim from `BR2026` by Task 3's duplication and would otherwise reference
  `AppIcon-Brasil`/`AppIcon-Stadium`, which Task 4 already made unreachable in code but
  which would still be dead weight in the build settings).
- [x] **Step 4:** Build all three new schemes — all succeed.
- [x] **Step 5: Manual verification.** Installed all three new apps to a Simulator
  alongside `BR2026` and confirmed via home-screen screenshot: four visually distinct
  icons (green ball/cream for `BR2026`, purple/white for Premier League, yellow/white for
  Ligue 1, navy/white for Primeira Liga), each correctly labeled with its target's
  display name.
- [x] **Step 6:** Commit.

---

### Task 6: `CrossAppLink` model + resolver (item #6) — not wired into any View

**Files:**
- Create: `BR2026/Models/CrossAppLink.swift`
- Create: `BR2026/Services/CrossAppLinkResolver.swift`
- Create: `BR2026Tests/Models/CrossAppLinkTests.swift`
- Create: `BR2026Tests/Services/CrossAppLinkResolverTests.swift`
- Modify: `BR2026.xcodeproj/project.pbxproj` (wire the 2 new source files into all 4 app
  targets; wire the 2 new test files into `BR2026Tests` only)

**Interfaces:**
- Produces: `CrossAppLink` (struct: `id`, `displayName`, `accentColorHex`, `urlScheme`,
  `appStoreID`, computed `customSchemeURL`/`appStoreURL`), static values `.brasileirao`
  `.premierLeague` `.ligue1` `.primeiraLiga`, `CrossAppLink.siblings(excluding:)`.
  `URLOpenabilityChecking` protocol + `UIKitURLOpenabilityChecker` (mirrors the existing
  `AppIconSetting`/`UIKitAppIconSetting` pattern exactly). `CrossAppLinkResolver.url(for:using:)`.
- Consumes: nothing from earlier tasks (self-contained) — but each `CrossAppLink`'s
  `urlScheme` value must match the custom URL scheme each target's Info.plist will
  eventually declare via `CFBundleURLTypes` (not part of this task — see spec's "Cross-App
  Linking" section; the actual `LSApplicationQueriesSchemes`/`CFBundleURLTypes` Info.plist
  wiring and the More-screen UI are explicitly deferred to a follow-up task once a sibling
  app is live).

- [x] **Step 1:** `CrossAppLink.swift` — struct + 4 static values (`appStoreID` is a
  `"0000000000"` placeholder for all four, since none of the 3 new apps have real App
  Store Connect records yet) + `siblings(excluding:)`.
- [x] **Step 2:** `CrossAppLinkResolver.swift` — `URLOpenabilityChecking` protocol,
  `UIKitURLOpenabilityChecker` concrete implementation, `CrossAppLinkResolver.url(for:using:)`.
- [x] **Step 3:** Tests — `CrossAppLinkTests` (siblings-excludes-current, URL construction)
  and `CrossAppLinkResolverTests` (installed → custom scheme, not installed → App Store
  URL, using a `StubURLOpenabilityChecker`).
- [x] **Step 4:** Wire the 2 source files into all 4 app targets' Sources build phases,
  and the 2 test files into `BR2026Tests`'s Sources build phase, via the `xcodeproj` gem
  (`target.add_file_references`).
- [x] **Step 5:** Run full test suite — 67 tests (60 + 3 `ChampionshipConfig` + 2
  `CrossAppLink` + 2 `CrossAppLinkResolver`), 0 failures.
- [x] **Step 6:** Build all 4 schemes — all succeed.
- [x] **Step 7:** Commit.

---

### Task 7: Full-bleed launch screen storyboards per new target

**Files:**
- Create: `BR2026/App/LaunchScreen-PremierLeague.storyboard`, `LaunchScreen-Ligue1.storyboard`,
  `LaunchScreen-PrimeiraLiga.storyboard`
- Create: `Generated/PremierLeague-Info.plist`, `Generated/Ligue1-Info.plist`,
  `Generated/PrimeiraLiga-Info.plist` (per-target partial Info.plist files)
- Create: `BR2026/Resources/Assets.xcassets/LaunchLogo-PremierLeague.imageset/`,
  `LaunchLogo-Ligue1.imageset/`, `LaunchLogo-PrimeiraLiga.imageset/`
- Modify: `BR2026.xcodeproj/project.pbxproj` (each new target's `INFOPLIST_FILE` build
  setting, plus `.storyboard` file references)

User supplied one full-bleed splash design per league (`design/Splash-PL-1290x2796.png`,
`Splash-FL1-1290x2796.png`, `Splash-PPL-1290x2796.png`) — each a 1290×2796 gradient
background (matching the league's own accent) with a centered glowing ball + league name.
These replace generated placeholder icons as the launch screen content for the 3 new
targets. `BR2026` itself keeps its existing small-centered-mark `UILaunchScreen` Info.plist
launch screen unchanged.

- [x] **Step 1: Rule out the `UILaunchScreen` Info.plist mechanism for full-bleed images.**
  Tried extending the existing small-mark approach (`UIColorName`/`UIImageName` dict keys,
  driven by custom `LAUNCH_SCREEN_COLOR_NAME`/`LAUNCH_SCREEN_IMAGE_NAME` build settings) with
  the new 1290×2796 splash images. Result: blank white screen at runtime — confirmed via
  screenshots on two different simulator devices (ruling out a simulator cache), and
  confirmed via `assetutil --info` on the compiled `Assets.car` and `plutil -extract` on
  the built Info.plist that the assets and per-target values were both correctly present.
  Conclusion: this mechanism only supports small centered marks, not full-bleed opaque
  backgrounds. Switched to a `LaunchScreen.storyboard` per new target instead — `BR2026`
  itself is unaffected, since it isn't switching mechanisms.
- [x] **Step 2:** Create one minimal `LaunchScreen-<League>.storyboard` per new target: a
  single `UIViewController` whose root view's `backgroundColor` is the design's sampled
  corner color (PL `#3d195b`, FL1 `#091c3e`, PPL `#046a38`, as literal RGB in the storyboard
  XML — not a named color asset) with one full-bleed `UIImageView` subview
  (`contentMode="scaleAspectFill"`, `image="LaunchLogo-<League>"`). The image view uses the
  legacy `translatesAutoresizingMaskIntoConstraints="YES"` + explicit `frame` matching the
  root view's size + `autoresizingMask` (`widthSizable`/`heightSizable`) — **not** Auto
  Layout constraints. An earlier attempt with
  `translatesAutoresizingMaskIntoConstraints="NO"` plus 4 explicit leading/trailing/top/
  bottom `NSLayoutConstraint` XML elements produced a background-color-only render (image
  never appeared, in any captured frame, at any timing) — switching to the frame +
  autoresizing-mask form fixed it.
- [x] **Step 3:** Add each splash PNG to a new `LaunchLogo-<League>.imageset` (1x/2x/3x
  slots all pointing at the same source file — a single 1290×2796 asset, no per-scale
  variants were provided).
- [x] **Step 4:** Create `Generated/<League>-Info.plist` per new target: a copy of
  `Generated/BR2026-Info.plist` with the `UILaunchScreen` dict replaced by
  `UILaunchStoryboardName = LaunchScreen-<League>`. Point each new target's `INFOPLIST_FILE`
  build setting at its own file (previously all 4 targets shared `BR2026-Info.plist`).
- [x] **Step 5:** Build all 3 new schemes — all succeed.
- [x] **Step 6: Manual verification, including a real caching pitfall.** Installing over an
  already-used simulator device (one that had the earlier broken build installed) kept
  showing the stale blank/color-only launch snapshot even after `simctl uninstall` +
  `simctl install` of the fixed build — a system-level (SpringBoard/Simulator) launch-screen
  snapshot cache keyed by bundle ID, distinct from the app container itself, that a plain
  reinstall doesn't invalidate. Confirmed the fix actually worked by installing fresh onto a
  simulator device that had never had any of these bundle IDs installed before (`iPhone 17
  Pro`, previously shut down/unused) — all three launch screens rendered correctly (ball +
  league name + gradient) via `simctl io recordVideo` + `ffmpeg` frame extraction. Takeaway
  for future launch-screen iteration: verify on a never-used device/bundle-ID combination,
  not by reinstalling over a device that already ran an earlier broken build.
- [x] **Step 7:** Remove the now-orphaned `LaunchBackground-PremierLeague/Ligue1/
  PrimeiraLiga.colorset` assets (created for the abandoned Info.plist-image approach in
  Step 1; the storyboard approach sets its background color inline in the XML instead of
  referencing a named color asset). Confirmed unreferenced first via
  `grep -rn "LaunchBackground" BR2026.xcodeproj/project.pbxproj BR2026/App/*.storyboard
  Generated/*.plist` (only `BR2026`'s own unrelated `LaunchBackground` colorset, used by its
  unchanged small-mark launch screen, matched).
- [x] **Step 8:** Run full test suite — still 67 tests, 0 failures (this task touches no
  Swift source, only storyboards/Info.plist/assets/build settings).
- [x] **Step 9:** Commit.

---

## Final Verification

- [x] Full test suite: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test`
  → 67 tests, 0 failures.
- [x] All 4 schemes build: `BR2026`, `PremierLeague2026`, `Ligue12026`, `PrimeiraLiga2026`
  (each via `xcodebuild ... -skipMacroValidation build`) → `** BUILD SUCCEEDED **`.
- [x] Manual Simulator verification: all 4 apps installable side-by-side with correct,
  distinct icons and display names; `PremierLeague2026` confirmed showing real league
  data and its own accent color at runtime.
- [x] All 3 new targets' full-bleed launch screens (ball + league name + gradient) verified
  rendering correctly on a never-before-used simulator device, via video-frame extraction.
