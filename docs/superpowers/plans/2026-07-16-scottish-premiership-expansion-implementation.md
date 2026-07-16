# Scottish Premiership Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 5th Xcode target, `ScottishPremiership2026`, to the white-label app family,
per `docs/superpowers/specs/2026-07-16-scottish-premiership-expansion-design.md`.

**Architecture:** Duplicate the `BR2026` native target via the `xcodeproj` Ruby gem — the
exact technique this repo already used for the prior 3-target expansion — copying all
build phases, package product dependencies, and build settings, then overriding only what's
target-specific (bundle ID, display name, compilation condition flag, app icon,
Info.plist). `ChampionshipConfig` selection happens via one more `#if` branch in the
existing shared `Championship.swift` entry point.

**Tech Stack:** Xcodeproj Ruby gem (`bundle exec ruby`, via this project's pinned rbenv
toolchain), Swift compiler conditionals.

## Global Constraints

- Backend already serves this league end-to-end — verified directly against the live API
  before starting: competition code `SPL`, 198 matches, 12 standings rows, all populated.
  No backend work in this plan.
- New target: `ScottishPremiership2026` (`com.vibrito.scottishpremiership2026`,
  "Scottish Premiership 2026", accent `#005EB8`, used directly as both `accentColorHex` and
  `tabSelectionColorHex` — visually confirm on the tab bar once built; swap in a brighter
  `tabSelectionColorHex` only if it reads too dark, same fix already applied twice before
  for Premier League/Liga Portugal).
- No new locale — Scottish Premiership is covered by the existing `en-GB` locale.
- Real icon/splash artwork is already provided: `design/AppIcon-SPL-1024.png` (1024×1024)
  and `design/BR2026/Splash-SPL-1290x2796.png` (1290×2796) — no placeholder generation
  needed for this expansion, unlike the prior one.
- The `CrossAppLink` model gains a `scottishPremiership` entry for consistency but stays
  **not** wired into any View — same deferral as the other 4 apps, until at least one
  sibling app is approved and live.
- No `CFBundleURLTypes`/`LSApplicationQueriesSchemes` Info.plist wiring — verified none of
  the 4 existing targets actually have this either (only the `CrossAppLink` Swift model
  exists), so this stays deferred alongside the UI wiring for all 5 apps at once.
- Firebase/App Store Connect/bundle-ID registration for the new app are manual, external
  steps outside this plan's scope. Until the user provides a
  `GoogleService-Info.plist` for `ScottishPremiership2026`, it shares `BR2026`'s Firebase
  project — a known, intentional bootstrap state, not a bug.
- No force-unwraps outside tests. Full test suite
  (`bundle exec fastlane test`, after `export PATH="$(rbenv root)/shims:$PATH"`) must pass
  at 100% after every task.

---

### Task 1: Add `ChampionshipConfig.scottishPremiership` and tests

**Files:**
- Modify: `BR2026/Config/ChampionshipConfig.swift`
- Modify: `BR2026Tests/Config/ChampionshipConfigTests.swift`

**Interfaces:**
- Produces: `ChampionshipConfig.scottishPremiership` — consumed by Task 2's `#if` wiring.

- [ ] **Step 1: Write the failing test**

Add to `BR2026Tests/Config/ChampionshipConfigTests.swift`, inside the existing
`ChampionshipConfigTests` struct, alongside the other `@Test` functions:

```swift
@Test("Scottish Premiership config has expected values")
func scottishPremiershipDefaults() {
    let config = ChampionshipConfig.scottishPremiership
    #expect(config.id == "scottish-premiership")
    #expect(config.competitionCode == "SPL")
    #expect(config.displayName == "Scottish Premiership")
    #expect(config.accentColorHex == "#005EB8")
    #expect(config.tabSelectionColorHex == "#005EB8")
    #expect(config.apiBaseURL.absoluteString == "https://football-api-production-16d9.up.railway.app")
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:BR2026Tests/ChampionshipConfigTests -quiet
```

Expected: FAIL — `type 'ChampionshipConfig' has no member 'scottishPremiership'`.

- [ ] **Step 3: Write the implementation**

Add to `BR2026/Config/ChampionshipConfig.swift`, inside the existing
`extension ChampionshipConfig`, after `.primeiraLiga`:

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

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:BR2026Tests/ChampionshipConfigTests -quiet
```

Expected: PASS, all 5 tests in the suite green (4 existing + 1 new).

- [ ] **Step 5: Commit**

```bash
git add BR2026/Config/ChampionshipConfig.swift BR2026Tests/Config/ChampionshipConfigTests.swift
git commit -m "Add ChampionshipConfig.scottishPremiership"
```

---

### Task 2: Wire `#if TARGET_SCOTTISH_PREMIERSHIP` into `Championship.swift`

**Files:**
- Modify: `BR2026/App/Championship.swift`

**Interfaces:**
- Consumes: `ChampionshipConfig.scottishPremiership` (Task 1).

- [ ] **Step 1: Add the new `#elseif` branch**

In `BR2026/App/Championship.swift`, change:

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

to:

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

- [ ] **Step 2: Build `BR2026` to confirm it's unaffected**

```bash
xcodebuild build -project BR2026.xcodeproj -scheme BR2026 -destination "generic/platform=iOS Simulator" -quiet
```

Expected: exit 0 (the new flag has no effect until a target actually defines it — `BR2026`
still resolves to `.brasileirao` via the `#else` branch).

- [ ] **Step 3: Commit**

```bash
git add BR2026/App/Championship.swift
git commit -m "Wire TARGET_SCOTTISH_PREMIERSHIP into Championship.swift's config selection"
```

---

### Task 3: Duplicate the `BR2026` target into `ScottishPremiership2026`

**Files:**
- Modify: `BR2026.xcodeproj/project.pbxproj` (via Ruby script, not hand-edited)
- Create: `BR2026.xcodeproj/xcshareddata/xcschemes/ScottishPremiership2026.xcscheme`

**Interfaces:**
- Consumes: `ChampionshipConfig.scottishPremiership` (Task 1),
  `TARGET_SCOTTISH_PREMIERSHIP` (Task 2).
- Produces: the `ScottishPremiership2026` Xcode target itself — consumed by every later
  task in this plan (they all set additional build settings/assets on this target).

- [ ] **Step 1: Duplicate the target via `xcodeproj`**

```bash
export PATH="$(rbenv root)/shims:$PATH"
bundle exec ruby <<'RUBY'
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
    existing_conditions = new_config.build_settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"]
    parts = ["$(inherited)", existing_conditions, compilation_condition].compact
    new_config.build_settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = parts.join(" ")
    new_config_list.build_configurations << new_config
  end
  new_target.build_configuration_list = new_config_list
  new_target
end

new_target = duplicate_target(project, source_target,
  new_name: "ScottishPremiership2026",
  bundle_id: "com.vibrito.scottishpremiership2026",
  display_name: "Scottish Premiership 2026",
  compilation_condition: "TARGET_SCOTTISH_PREMIERSHIP")

puts "New target UUID: #{new_target.uuid}"
project.save
RUBY
```

Note the printed `New target UUID:` — Step 2 needs it.

- [ ] **Step 2: Generate a shared scheme for the new target**

Copy the existing `PremierLeague2026.xcscheme` (same structure works for any of the 3
existing non-`BR2026` targets — they all reference the same shared `BR2026Tests`/
`BR2026UITests` testable targets) and substitute the target-specific values:

```bash
NEW_UUID="<paste the UUID printed by Step 1>"
cp "BR2026.xcodeproj/xcshareddata/xcschemes/PremierLeague2026.xcscheme" \
   "BR2026.xcodeproj/xcshareddata/xcschemes/ScottishPremiership2026.xcscheme"
sed -i '' \
  -e "s/BlueprintIdentifier = \"35780F36EB205906A0BFC802\"/BlueprintIdentifier = \"$NEW_UUID\"/g" \
  -e 's/BuildableName = "PremierLeague2026\.app"/BuildableName = "ScottishPremiership2026.app"/g' \
  -e 's/BlueprintName = "PremierLeague2026"/BlueprintName = "ScottishPremiership2026"/g' \
  "BR2026.xcodeproj/xcshareddata/xcschemes/ScottishPremiership2026.xcscheme"
```

This substitutes the 3 `BuildActionEntry`/`MacroExpansion`/`BuildableProductRunnable`
references to the app product itself (all of which use the *same* UUID,
`35780F36EB205906A0BFC802`, PremierLeague2026's own `PBXNativeTarget` UUID) — the
`BR2026Tests`/`BR2026UITests` `BlueprintIdentifier`s (`78C6B9E9B67D1498742D6B7C`/
`9A932244CA7F4616EF62261C`) are deliberately left untouched, since those shared test
targets don't change per app target.

- [ ] **Step 3: Verify the substitution**

```bash
grep -c "$NEW_UUID" "BR2026.xcodeproj/xcshareddata/xcschemes/ScottishPremiership2026.xcscheme"
grep -c "ScottishPremiership2026" "BR2026.xcodeproj/xcshareddata/xcschemes/ScottishPremiership2026.xcscheme"
grep -c "78C6B9E9B67D1498742D6B7C" "BR2026.xcodeproj/xcshareddata/xcschemes/ScottishPremiership2026.xcscheme"
```

Expected (verified against the actual `PremierLeague2026.xcscheme` file before writing this
plan): `4` (the new UUID appears exactly 4 times — BuildActionEntry, MacroExpansion, and
the LaunchAction/ProfileAction `BuildableProductRunnable`s), `8` (`BuildableName`/
`BlueprintName` pairs at those same 4 sites), `2` (`BR2026Tests`'s UUID unchanged, appears
twice — BuildActionEntries + Testables).

- [ ] **Step 4: Build the new scheme**

```bash
xcodebuild build -project BR2026.xcodeproj -scheme ScottishPremiership2026 -destination "generic/platform=iOS Simulator" -quiet
```

Expected: exit 0. (The app will show "BR 2026"'s default icon/assets and Brasileirão data
at this point, since Task 4/5/6's target-specific gating and assets haven't landed yet —
that's expected, not a bug, at this checkpoint.)

- [ ] **Step 5: Run the full test suite**

```bash
export PATH="$(rbenv root)/shims:$PATH"
bundle exec fastlane test
```

Expected: 191/191 passing (190 baseline + 1 from Task 1) — this task adds no new tests
itself, just the target.

- [ ] **Step 6: Commit**

```bash
git add BR2026.xcodeproj/project.pbxproj BR2026.xcodeproj/xcshareddata/xcschemes/ScottishPremiership2026.xcscheme
git commit -m "Duplicate BR2026 target into ScottishPremiership2026"
```

---

### Task 4: Gate Brasileirão-specific UI for the new target

**Files:**
- Modify: `BR2026/Models/AppIconOption.swift`
- Modify: `BR2026/ViewModels/MoreViewModel.swift`
- Modify: `BR2026/Views/More/AppIconPickerView.swift`

**Interfaces:**
- Consumes: `TARGET_SCOTTISH_PREMIERSHIP` (Task 2).

`AppIconOption`'s `.stadium` case, the More screen's "Team Theme" row, and the App Icon
picker's purchasable team-icon section are all Brasileirão-specific and already gated
behind `#if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA)` in 8 places
across these 3 files (discovered via a full-repo grep before writing this plan) — every one
of them needs `TARGET_SCOTTISH_PREMIERSHIP` added to that same condition, or the new app
would incorrectly offer Brasileirão's "Stadium" alternate icon, "Team Theme" row, and
purchasable team icons.

- [ ] **Step 1: Update `AppIconOption.swift`**

In `BR2026/Models/AppIconOption.swift`, there are 4 occurrences of
`#if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA)` — one gating the
`.stadium` case declaration, one in `displayName`, one in `iconAssetName`, one in
`previewImageName`. Replace all 4 with:

```swift
#if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA || TARGET_SCOTTISH_PREMIERSHIP)
```

(A plain find-and-replace of the old condition string with the new one, applied to all 4
occurrences in this file — the content on the lines around each `#if` doesn't change.)

Also, `previewImageName`'s `.light` case has its own separate `#if TARGET_PREMIER_LEAGUE /
#elseif TARGET_LIGUE_1 / #elseif TARGET_PRIMEIRA_LIGA / #else` chain (each target's
"Default" row shows its own primary icon as the preview thumbnail). Add one more branch:

```swift
    var previewImageName: String {
        switch self {
        case .light:
            #if TARGET_PREMIER_LEAGUE
            "AppIconPreview-PremierLeague"
            #elseif TARGET_LIGUE_1
            "AppIconPreview-Ligue1"
            #elseif TARGET_PRIMEIRA_LIGA
            "AppIconPreview-PrimeiraLiga"
            #elseif TARGET_SCOTTISH_PREMIERSHIP
            "AppIconPreview-ScottishPremiership"
            #else
            "AppIconPreview-Light"
            #endif
        #if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA || TARGET_SCOTTISH_PREMIERSHIP)
        case .stadium: "AppIconPreview-Stadium"
        #endif
        }
    }
```

(`AppIconPreview-ScottishPremiership` is created in Task 5 — this line references an asset
that doesn't exist until then; the file still compiles fine either way since it's just a
string literal, but the picker's "Default" row won't show a real thumbnail image until
Task 5 lands.)

- [ ] **Step 2: Update `MoreViewModel.swift`**

In `BR2026/ViewModels/MoreViewModel.swift`, the single occurrence of
`#if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA)` (gating the "Team
Theme" row in `preferencesRows`) becomes:

```swift
#if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA || TARGET_SCOTTISH_PREMIERSHIP)
```

- [ ] **Step 3: Update `AppIconPickerView.swift`**

In `BR2026/Views/More/AppIconPickerView.swift`, all 3 occurrences of
`#if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA)` (gating the
purchasable team-icon `ForEach`, the "Restore Purchases" button, and the
`.task { await viewModel.loadOnce() }`) become:

```swift
#if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA || TARGET_SCOTTISH_PREMIERSHIP)
```

- [ ] **Step 4: Build both `BR2026` and `ScottishPremiership2026`**

```bash
xcodebuild build -project BR2026.xcodeproj -scheme BR2026 -destination "generic/platform=iOS Simulator" -quiet
xcodebuild build -project BR2026.xcodeproj -scheme ScottishPremiership2026 -destination "generic/platform=iOS Simulator" -quiet
```

Expected: both exit 0.

- [ ] **Step 5: Run the full test suite**

```bash
export PATH="$(rbenv root)/shims:$PATH"
bundle exec fastlane test
```

Expected: still 191/191 — existing tests referencing `.stadium`/Team Theme/Team Icon
directly always compile against the `BR2026` target specifically (via `@testable import
BR2026`), which never defines `TARGET_SCOTTISH_PREMIERSHIP`, so nothing here changes test
behavior.

- [ ] **Step 6: Commit**

```bash
git add BR2026/Models/AppIconOption.swift BR2026/ViewModels/MoreViewModel.swift BR2026/Views/More/AppIconPickerView.swift
git commit -m "Gate Brasileirão-specific UI (Stadium icon, Team Theme, Team Icon) out of ScottishPremiership2026"
```

---

### Task 5: Wire the real app icon

**Files:**
- Create: `BR2026/Resources/Assets.xcassets/AppIcon-ScottishPremiership.appiconset/`
  (`Contents.json` + `AppIcon-ScottishPremiership-1024.png`)
- Create: `BR2026/Resources/Assets.xcassets/AppIconPreview-ScottishPremiership.imageset/`
  (`Contents.json` + `AppIconPreview-ScottishPremiership.png`)
- Modify: `BR2026.xcodeproj/project.pbxproj` (via Ruby script — set
  `ScottishPremiership2026`'s `ASSETCATALOG_COMPILER_APPICON_NAME`, remove its
  `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`)

**Interfaces:**
- Consumes: `design/AppIcon-SPL-1024.png` (already provided, 1024×1024).

- [ ] **Step 1: Create the primary App Icon Set from the provided artwork**

```bash
mkdir -p "BR2026/Resources/Assets.xcassets/AppIcon-ScottishPremiership.appiconset"
cp "design/AppIcon-SPL-1024.png" "BR2026/Resources/Assets.xcassets/AppIcon-ScottishPremiership.appiconset/AppIcon-ScottishPremiership-1024.png"
cat > "BR2026/Resources/Assets.xcassets/AppIcon-ScottishPremiership.appiconset/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "AppIcon-ScottishPremiership-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON
```

- [ ] **Step 2: Create the preview thumbnail Image Set (same artwork, picker-only)**

```bash
mkdir -p "BR2026/Resources/Assets.xcassets/AppIconPreview-ScottishPremiership.imageset"
cp "design/AppIcon-SPL-1024.png" "BR2026/Resources/Assets.xcassets/AppIconPreview-ScottishPremiership.imageset/AppIconPreview-ScottishPremiership.png"
cat > "BR2026/Resources/Assets.xcassets/AppIconPreview-ScottishPremiership.imageset/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "AppIconPreview-ScottishPremiership.png",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON
```

- [ ] **Step 3: Point the target's primary icon at the new asset, and clear the inherited alternate-icon list**

```bash
export PATH="$(rbenv root)/shims:$PATH"
bundle exec ruby <<'RUBY'
require "xcodeproj"
project = Xcodeproj::Project.open("BR2026.xcodeproj")
target = project.targets.find { |t| t.name == "ScottishPremiership2026" }
target.build_configuration_list.build_configurations.each do |config|
  config.build_settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIcon-ScottishPremiership"
  # BR2026's own list of 21 alternate-icon names (Stadium + 20 purchasable team icons) was
  # copied verbatim by Task 3's duplication — irrelevant and must not carry over, since
  # Task 4 already made those options unreachable in code for this target.
  config.build_settings.delete("ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES")
end
project.save
RUBY
```

- [ ] **Step 4: Verify the build setting change**

```bash
grep -A1 "ScottishPremiership2026" BR2026.xcodeproj/project.pbxproj | grep "ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES" || echo "confirmed: no alternate icon names for ScottishPremiership2026"
```

- [ ] **Step 5: Build the new target**

```bash
xcodebuild build -project BR2026.xcodeproj -scheme ScottishPremiership2026 -destination "generic/platform=iOS Simulator" -quiet
```

Expected: exit 0.

- [ ] **Step 6: Commit**

```bash
git add BR2026/Resources/Assets.xcassets/AppIcon-ScottishPremiership.appiconset BR2026/Resources/Assets.xcassets/AppIconPreview-ScottishPremiership.imageset BR2026.xcodeproj/project.pbxproj
git commit -m "Wire ScottishPremiership2026's real app icon"
```

---

### Task 6: Wire the real launch screen

**Files:**
- Create: `BR2026/App/LaunchScreen-ScottishPremiership.storyboard`
- Create: `Generated/ScottishPremiership-Info.plist`
- Create: `BR2026/Resources/Assets.xcassets/LaunchLogo-ScottishPremiership.imageset/`
  (`Contents.json` + 3 identical copies of the provided splash PNG)
- Modify: `BR2026.xcodeproj/project.pbxproj` (via Ruby script —
  `ScottishPremiership2026`'s `INFOPLIST_FILE` build setting)

**Interfaces:**
- Consumes: `design/BR2026/Splash-SPL-1290x2796.png` (already provided, 1290×2796).

- [ ] **Step 1: Create the Launch Logo Image Set from the provided artwork**

The existing pattern for the other 3 non-`BR2026` targets uses 3 physical files (one per
scale slot), all identical bytes — no per-scale variants were provided for those either:

```bash
mkdir -p "BR2026/Resources/Assets.xcassets/LaunchLogo-ScottishPremiership.imageset"
cp "design/BR2026/Splash-SPL-1290x2796.png" "BR2026/Resources/Assets.xcassets/LaunchLogo-ScottishPremiership.imageset/LaunchLogo-ScottishPremiership.png"
cp "design/BR2026/Splash-SPL-1290x2796.png" "BR2026/Resources/Assets.xcassets/LaunchLogo-ScottishPremiership.imageset/LaunchLogo-ScottishPremiership@1x.png"
cp "design/BR2026/Splash-SPL-1290x2796.png" "BR2026/Resources/Assets.xcassets/LaunchLogo-ScottishPremiership.imageset/LaunchLogo-ScottishPremiership@2x.png"
cat > "BR2026/Resources/Assets.xcassets/LaunchLogo-ScottishPremiership.imageset/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "LaunchLogo-ScottishPremiership@1x.png", "idiom" : "universal", "scale" : "1x" },
    { "filename" : "LaunchLogo-ScottishPremiership@2x.png", "idiom" : "universal", "scale" : "2x" },
    { "filename" : "LaunchLogo-ScottishPremiership.png", "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON
```

- [ ] **Step 2: Create the launch screen storyboard**

Structurally identical to `LaunchScreen-PremierLeague.storyboard` — a single full-bleed
`imageView` (frame + autoresizing mask, **not** Auto Layout constraints — the prior
expansion found Auto Layout constraints here silently fail to render the image at all)
over a solid background color matching `#005EB8` as a fallback behind the image:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<document type="com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB" version="3.0" toolsVersion="23504" targetRuntime="iOS.CocoaTouch" propertyAccessControl="none" useAutolayout="YES" launchScreen="YES" useTraitCollections="YES" useSafeAreas="YES" colorMatched="YES" initialViewController="01J-lp-oVM">
    <device id="retina6_12" orientation="portrait" appearance="light"/>
    <dependencies>
        <deployment identifier="iOS"/>
        <plugIn identifier="com.apple.InterfaceBuilder.IBCocoaTouchPlugin" version="23508"/>
        <capability name="Safe area layout guides" minToolsVersion="9.0"/>
        <capability name="documents saved in the Xcode 8 format" minToolsVersion="8.0"/>
    </dependencies>
    <scenes>
        <scene sceneID="EHf-IW-A2E">
            <objects>
                <viewController id="01J-lp-oVM" sceneMemberID="viewController">
                    <view key="view" contentMode="scaleToFill" id="Ze5-6b-2t3">
                        <rect key="frame" x="0.0" y="0.0" width="393" height="852"/>
                        <autoresizingMask key="autoresizingMask" widthSizable="YES" heightSizable="YES"/>
                        <subviews>
                            <imageView contentMode="scaleAspectFill" horizontalHuggingPriority="251" verticalHuggingPriority="251" image="LaunchLogo-ScottishPremiership" translatesAutoresizingMaskIntoConstraints="YES" id="img1">
                                <rect key="frame" x="0.0" y="0.0" width="393" height="852"/>
                                <autoresizingMask key="autoresizingMask" widthSizable="YES" heightSizable="YES"/>
                            </imageView>
                        </subviews>
                        <viewLayoutGuide key="safeArea" id="6Tk-OE-BBY"/>
                        <color key="backgroundColor" red="0.0" green="0.3686274509803922" blue="0.7215686274509804" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>
                    </view>
                </viewController>
                <placeholder placeholderIdentifier="IBFirstResponder" id="iYj-Kq-Ea1" userLabel="First Responder" sceneMemberID="firstResponder"/>
            </objects>
            <point key="canvasLocation" x="53" y="375"/>
        </scene>
    </scenes>
</document>
```

Save this to `BR2026/App/LaunchScreen-ScottishPremiership.storyboard`.

- [ ] **Step 3: Create the per-target partial Info.plist**

Copy `Generated/PremierLeague-Info.plist` and change only the `UILaunchStoryboardName`
value:

```bash
cp Generated/PremierLeague-Info.plist Generated/ScottishPremiership-Info.plist
sed -i '' 's/LaunchScreen-PremierLeague/LaunchScreen-ScottishPremiership/' Generated/ScottishPremiership-Info.plist
```

- [ ] **Step 4: Point the target's `INFOPLIST_FILE` at the new file**

```bash
export PATH="$(rbenv root)/shims:$PATH"
bundle exec ruby <<'RUBY'
require "xcodeproj"
project = Xcodeproj::Project.open("BR2026.xcodeproj")
target = project.targets.find { |t| t.name == "ScottishPremiership2026" }
target.build_configuration_list.build_configurations.each do |config|
  config.build_settings["INFOPLIST_FILE"] = "Generated/ScottishPremiership-Info.plist"
end
project.save
RUBY
```

- [ ] **Step 5: Build the new target**

```bash
xcodebuild build -project BR2026.xcodeproj -scheme ScottishPremiership2026 -destination "generic/platform=iOS Simulator" -quiet
```

Expected: exit 0.

- [ ] **Step 6: Manual verification (real caching pitfall — read before skipping)**

Install onto a Simulator device that has **never** had any of this project's bundle IDs
installed on it before (a fresh/unused device, or `xcrun simctl erase` on a spare one) —
the prior expansion found that reinstalling over a device that previously ran a *broken*
launch screen build keeps showing a stale cached snapshot (a SpringBoard/Simulator-level
cache keyed by bundle ID, separate from the app container) even after a clean reinstall.
Confirm via a screenshot or `simctl io recordVideo` that the launch screen shows the real
splash artwork, not a blank/solid-color screen.

- [ ] **Step 7: Commit**

```bash
git add BR2026/App/LaunchScreen-ScottishPremiership.storyboard Generated/ScottishPremiership-Info.plist BR2026/Resources/Assets.xcassets/LaunchLogo-ScottishPremiership.imageset BR2026.xcodeproj/project.pbxproj
git commit -m "Wire ScottishPremiership2026's real launch screen"
```

---

### Task 7: Add `CrossAppLink.scottishPremiership`

**Files:**
- Modify: `BR2026/Models/CrossAppLink.swift`
- Modify: `BR2026Tests/Models/CrossAppLinkTests.swift`

**Interfaces:**
- Produces: `CrossAppLink.scottishPremiership`, included in `CrossAppLink.all`.

- [ ] **Step 1: Write the failing test**

The existing `siblingsExcludesCurrentApp` test in `BR2026Tests/Models/CrossAppLinkTests.swift`
asserts `siblings.count == 3` (the other 3 apps, excluding Premier League) — this must
become `4` once a 5th app exists. Replace that test and add one more assertion for the new
sibling:

```swift
@Test("siblings(excluding:) returns the other 4 apps, not the current one")
func siblingsExcludesCurrentApp() {
    let siblings = CrossAppLink.siblings(excluding: "premier-league")
    #expect(siblings.count == 4)
    #expect(!siblings.contains { $0.id == "premier-league" })
    #expect(siblings.contains { $0.id == "brasileirao" })
    #expect(siblings.contains { $0.id == "ligue-1" })
    #expect(siblings.contains { $0.id == "primeira-liga" })
    #expect(siblings.contains { $0.id == "scottish-premiership" })
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:BR2026Tests/CrossAppLinkTests -quiet
```

Expected: FAIL — `siblings.count` is `3`, not `4` (no `scottishPremiership` case exists
yet).

- [ ] **Step 3: Write the implementation**

Add to `BR2026/Models/CrossAppLink.swift`'s `extension CrossAppLink`, after
`.primeiraLiga`:

```swift
static let scottishPremiership = CrossAppLink(
    id: "scottish-premiership",
    displayName: "Scottish Premiership",
    accentColorHex: "#005EB8",
    urlScheme: "scottishpremiership2026",
    appStoreID: "0000000000"
)
```

Update the `all` array:

```swift
static let all: [CrossAppLink] = [brasileirao, premierLeague, ligue1, primeiraLiga, scottishPremiership]
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:BR2026Tests/CrossAppLinkTests -quiet
```

Expected: PASS, both tests in the suite green.

- [ ] **Step 5: Commit**

```bash
git add BR2026/Models/CrossAppLink.swift BR2026Tests/Models/CrossAppLinkTests.swift
git commit -m "Add CrossAppLink.scottishPremiership"
```

---

## Final Verification

- [ ] **Full test suite:**

```bash
export PATH="$(rbenv root)/shims:$PATH"
bundle exec fastlane test
```

Expected: 191/191 passing (190 baseline + 1 from Task 1's new `ChampionshipConfig` test).
Task 7 only rewrites `siblingsExcludesCurrentApp`'s existing body/assertions — same
function name, no new `@Test` added — so it doesn't change the total count. No other task
in this plan adds or removes any tests.

- [ ] **All 5 targets build:**

```bash
xcodebuild build -project BR2026.xcodeproj -scheme BR2026 -destination "generic/platform=iOS Simulator" -quiet
xcodebuild build -project BR2026.xcodeproj -scheme PremierLeague2026 -destination "generic/platform=iOS Simulator" -quiet
xcodebuild build -project BR2026.xcodeproj -scheme Ligue12026 -destination "generic/platform=iOS Simulator" -quiet
xcodebuild build -project BR2026.xcodeproj -scheme PrimeiraLiga2026 -destination "generic/platform=iOS Simulator" -quiet
xcodebuild build -project BR2026.xcodeproj -scheme ScottishPremiership2026 -destination "generic/platform=iOS Simulator" -quiet
```

Expected: all five exit 0.

- [ ] **Manual Simulator verification:** install `ScottishPremiership2026.app` alongside
  the other 4, confirm via screenshot: real Scottish Premiership match/standings data
  (backend already serves it), the `#005EB8` accent color on the tab bar (and confirm
  whether it reads legibly as the *selected* tab color, or needs the
  `tabSelectionColorHex` override noted in Global Constraints), the real app icon on the
  home screen, and the real splash artwork on launch (on a never-before-used simulator
  device, per Task 6 Step 6's caching note).
- [ ] **Confirm the More screen** on `ScottishPremiership2026` shows no "Team Theme" row
  and the App Icon picker shows only "Default" (no "Stadium", no purchasable team icons) —
  the Task 4 gating working end-to-end, not just compiling.
