# La Liga Expansion + Spanish Localization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 6th Xcode target, `LaLiga2026`, add `es` as a supported locale app-wide
with Spanish translations for all 39 shared UI strings, and fix a pre-existing bug where
Terms of Service hardcoded "Brasileirão" across every target — per
`docs/superpowers/specs/2026-07-16-la-liga-expansion-design.md`.

**Architecture:** Duplicate the `BR2026` target via the `xcodeproj` Ruby gem, exactly as
done for `ScottishPremiership2026` — but this time proactively applying both lessons
learned from that expansion (Frameworks-phase package-product link entries, Resources-phase
stale launch-screen reference) as part of the duplication/launch-screen tasks themselves,
not discovered afterward. Spanish localization is a data-only change to
`Localizable.xcstrings` plus a project-level `knownRegions` addition.

**Tech Stack:** Xcodeproj Ruby gem (`bundle exec ruby`, via this project's pinned rbenv
toolchain), Swift compiler conditionals, Python (for the `.xcstrings` JSON edit, matching
the established minimal-diff serialization technique).

## Global Constraints

- Backend already serves this league — verified directly against the live API: `PD`, 380
  matches, 20 standings rows, populated (competition record momentarily showed 0/0 on an
  earlier same-day check; since resolved).
- New target: `LaLiga2026` (`com.vibrito.laliga2026`, "La Liga 2026", accent `#AA151B`,
  tabSelectionColorHex `#F1BF00` — both colors supplied together, used directly for both
  roles per the design, not discovered-then-fixed).
- Real icon/splash artwork already provided: `design/AppIcon-LaLiga-1024.png` (1024×1024),
  `design/Splash-3g-LaLiga-1290x2796.png` (1290×2796).
- `es` (generic, not `es-ES`) is the new locale — matches the existing generic `fr`
  precedent (one Spanish-speaking audience for now).
- All 39 `Localizable.xcstrings` keys get an `es` value — exact text given in Task 8,
  user-approved, not fabricated at implementation time.
- `TermsOfServiceView`'s hardcoded "Brasileirão" is fixed via a `%@` placeholder +
  `ChampionshipConfig.displayName`, across all 6 locales (`en`, `en-GB`, `fr`, `pt-BR`,
  `pt-PT`, `es`).
- The `CrossAppLink` model gains a `laLiga` entry, still not wired into any View.
- No `CFBundleURLTypes`/`LSApplicationQueriesSchemes` Info.plist wiring (same as every
  other target — deferred alongside the UI wiring for all 6 apps at once).
- Firebase/App Store Connect/bundle-ID registration for `LaLiga2026` are manual, external
  steps outside this plan's scope — it shares `BR2026`'s Firebase project until a real
  `GoogleService-Info.plist` is provided, same bootstrap state as every prior new target.
- No force-unwraps outside tests. Full test suite
  (`bundle exec fastlane test`, after `export PATH="$(rbenv root)/shims:$PATH"`) must pass
  at 100% after every task.

---

### Task 1: Add `ChampionshipConfig.laLiga` and tests

**Files:**
- Modify: `BR2026/Config/ChampionshipConfig.swift`
- Modify: `BR2026Tests/Config/ChampionshipConfigTests.swift`

**Interfaces:**
- Produces: `ChampionshipConfig.laLiga` — consumed by Task 2's `#if` wiring.

- [ ] **Step 1: Write the failing test**

Add to `BR2026Tests/Config/ChampionshipConfigTests.swift`, inside the existing
`ChampionshipConfigTests` struct:

```swift
@Test("La Liga config has expected values")
func laLigaDefaults() {
    let config = ChampionshipConfig.laLiga
    #expect(config.id == "la-liga")
    #expect(config.competitionCode == "PD")
    #expect(config.displayName == "La Liga")
    #expect(config.accentColorHex == "#AA151B")
    #expect(config.tabSelectionColorHex == "#F1BF00")
    #expect(config.apiBaseURL.absoluteString == "https://football-api-production-16d9.up.railway.app")
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:BR2026Tests/ChampionshipConfigTests -quiet
```

Expected: FAIL — `type 'ChampionshipConfig' has no member 'laLiga'`.

- [ ] **Step 3: Write the implementation**

Add to `BR2026/Config/ChampionshipConfig.swift`, inside the existing
`extension ChampionshipConfig`, after `.scottishPremiership`:

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

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:BR2026Tests/ChampionshipConfigTests -quiet
```

Expected: PASS, all 6 tests in the suite green.

- [ ] **Step 5: Commit**

```bash
git add BR2026/Config/ChampionshipConfig.swift BR2026Tests/Config/ChampionshipConfigTests.swift
git commit -m "Add ChampionshipConfig.laLiga"
```

---

### Task 2: Wire `#if TARGET_LA_LIGA` into `Championship.swift`

**Files:**
- Modify: `BR2026/App/Championship.swift`

**Interfaces:**
- Consumes: `ChampionshipConfig.laLiga` (Task 1).

- [ ] **Step 1: Add the new `#elseif` branch**

Change:

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
    #elseif TARGET_LA_LIGA
    let config = ChampionshipConfig.laLiga
    #else
    let config = ChampionshipConfig.brasileirao
    #endif
```

- [ ] **Step 2: Build `BR2026` to confirm it's unaffected**

```bash
xcodebuild build -project BR2026.xcodeproj -scheme BR2026 -destination "generic/platform=iOS Simulator" -quiet
```

Expected: exit 0.

- [ ] **Step 3: Commit**

```bash
git add BR2026/App/Championship.swift
git commit -m "Wire TARGET_LA_LIGA into Championship.swift's config selection"
```

---

### Task 3: Duplicate the `BR2026` target into `LaLiga2026`

**Files:**
- Modify: `BR2026.xcodeproj/project.pbxproj` (via Ruby script, not hand-edited)
- Create: `BR2026.xcodeproj/xcshareddata/xcschemes/LaLiga2026.xcscheme`

**Interfaces:**
- Consumes: `ChampionshipConfig.laLiga` (Task 1), `TARGET_LA_LIGA` (Task 2).
- Produces: the `LaLiga2026` Xcode target itself — consumed by every later task.

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
  new_name: "LaLiga2026",
  bundle_id: "com.vibrito.laliga2026",
  display_name: "La Liga 2026",
  compilation_condition: "TARGET_LA_LIGA")

# Lesson learned from the Scottish Premiership expansion: the Frameworks-phase copy step
# above (`if bf.file_ref`) skips every SPM package-product PBXBuildFile, since those use
# `product_ref` instead of `file_ref` — apply the fix proactively this time by copying the
# 3 correct entries from an existing sibling target instead of leaving them missing.
sibling_target = project.targets.find { |t| t.name == "ScottishPremiership2026" }
sibling_frameworks_phase = sibling_target.build_phases.find { |p| p.isa == "PBXFrameworksBuildPhase" }
new_frameworks_phase = new_target.build_phases.find { |p| p.isa == "PBXFrameworksBuildPhase" }
sibling_frameworks_phase.files.each do |bf|
  next unless bf.product_ref
  new_bf = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  new_bf.product_ref = bf.product_ref
  new_frameworks_phase.files << new_bf
end

puts "New target UUID: #{new_target.uuid}"
puts "Frameworks phase file count: #{new_frameworks_phase.files.count}"
project.save
RUBY
```

Note the printed `New target UUID:` (Step 2 needs it) and confirm `Frameworks phase file
count: 3` in the output — that's the Frameworks-phase fix applied inline, not left for
later.

- [ ] **Step 2: Generate a shared scheme for the new target**

```bash
NEW_UUID="<paste the UUID printed by Step 1>"
cp "BR2026.xcodeproj/xcshareddata/xcschemes/ScottishPremiership2026.xcscheme" \
   "BR2026.xcodeproj/xcshareddata/xcschemes/LaLiga2026.xcscheme"
sed -i '' \
  -e "s/BlueprintIdentifier = \"C0F0CBF714476DF8D1ACD0BB\"/BlueprintIdentifier = \"$NEW_UUID\"/g" \
  -e 's/BuildableName = "ScottishPremiership2026\.app"/BuildableName = "LaLiga2026.app"/g' \
  -e 's/BlueprintName = "ScottishPremiership2026"/BlueprintName = "LaLiga2026"/g' \
  "BR2026.xcodeproj/xcshareddata/xcschemes/LaLiga2026.xcscheme"
```

(`C0F0CBF714476DF8D1ACD0BB` is `ScottishPremiership2026`'s own `PBXNativeTarget` UUID,
copied here as the base scheme to substitute from — same technique as before, just
starting from a different sibling's scheme file.)

- [ ] **Step 3: Verify the substitution**

```bash
grep -c "$NEW_UUID" "BR2026.xcodeproj/xcshareddata/xcschemes/LaLiga2026.xcscheme"
grep -c "LaLiga2026" "BR2026.xcodeproj/xcshareddata/xcschemes/LaLiga2026.xcscheme"
grep -c "78C6B9E9B67D1498742D6B7C" "BR2026.xcodeproj/xcshareddata/xcschemes/LaLiga2026.xcscheme"
```

Expected: `4` (new UUID at BuildActionEntry, MacroExpansion, LaunchAction/ProfileAction
`BuildableProductRunnable`s), `8` (`BuildableName`/`BlueprintName` pairs at those 4 sites),
`2` (`BR2026Tests`'s UUID unchanged — BuildActionEntries + Testables).

- [ ] **Step 4: Build the new scheme**

```bash
xcodebuild build -project BR2026.xcodeproj -scheme LaLiga2026 -destination "generic/platform=iOS Simulator" -quiet
```

Expected: exit 0.

- [ ] **Step 5: Run the full test suite**

```bash
export PATH="$(rbenv root)/shims:$PATH"
bundle exec fastlane test
```

Expected: 192/192 passing (191 baseline + 1 from Task 1) — this task adds no new tests
itself, just the target.

- [ ] **Step 6: Commit**

```bash
git add BR2026.xcodeproj/project.pbxproj BR2026.xcodeproj/xcshareddata/xcschemes/LaLiga2026.xcscheme
git commit -m "Duplicate BR2026 target into LaLiga2026, including the Frameworks-phase fix"
```

---

### Task 4: Gate Brasileirão-specific UI for the new target

**Files:**
- Modify: `BR2026/Models/AppIconOption.swift`
- Modify: `BR2026/ViewModels/MoreViewModel.swift`
- Modify: `BR2026/Views/More/AppIconPickerView.swift`

**Interfaces:**
- Consumes: `TARGET_LA_LIGA` (Task 2).

The 8 existing gate sites already read
`#if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA || TARGET_SCOTTISH_PREMIERSHIP)`
(the 4th flag was added in the Scottish Premiership expansion) — every one needs
` || TARGET_LA_LIGA` added, or `LaLiga2026` would incorrectly offer Brasileirão's "Stadium"
alternate icon, "Team Theme" row, and purchasable team icons.

- [ ] **Step 1: Update `AppIconOption.swift`**

There are 4 occurrences of
`#if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA || TARGET_SCOTTISH_PREMIERSHIP)`
in this file. Replace all 4 with:

```swift
#if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA || TARGET_SCOTTISH_PREMIERSHIP || TARGET_LA_LIGA)
```

Also add one more branch to `previewImageName`'s separate positive-selection chain (for
`.light`'s own preview thumbnail):

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
            #elseif TARGET_LA_LIGA
            "AppIconPreview-LaLiga"
            #else
            "AppIconPreview-Light"
            #endif
        #if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA || TARGET_SCOTTISH_PREMIERSHIP || TARGET_LA_LIGA)
        case .stadium: "AppIconPreview-Stadium"
        #endif
        }
    }
```

(`AppIconPreview-LaLiga` is created in Task 5 — referencing it here before it exists is
fine, it's just a string literal.)

- [ ] **Step 2: Update `MoreViewModel.swift`**

The single occurrence becomes:

```swift
#if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA || TARGET_SCOTTISH_PREMIERSHIP || TARGET_LA_LIGA)
```

- [ ] **Step 3: Update `AppIconPickerView.swift`**

All 3 occurrences become:

```swift
#if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA || TARGET_SCOTTISH_PREMIERSHIP || TARGET_LA_LIGA)
```

- [ ] **Step 4: Verify with a repo-wide grep**

```bash
grep -rn "TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA || TARGET_SCOTTISH_PREMIERSHIP)" BR2026/
```

Expected: zero matches (the old 5-flag-missing condition must not remain anywhere).

- [ ] **Step 5: Build both `BR2026` and `LaLiga2026`**

```bash
xcodebuild build -project BR2026.xcodeproj -scheme BR2026 -destination "generic/platform=iOS Simulator" -quiet
xcodebuild build -project BR2026.xcodeproj -scheme LaLiga2026 -destination "generic/platform=iOS Simulator" -quiet
```

Expected: both exit 0.

- [ ] **Step 6: Run the full test suite**

```bash
export PATH="$(rbenv root)/shims:$PATH"
bundle exec fastlane test
```

Expected: still 192/192.

- [ ] **Step 7: Commit**

```bash
git add BR2026/Models/AppIconOption.swift BR2026/ViewModels/MoreViewModel.swift BR2026/Views/More/AppIconPickerView.swift
git commit -m "Gate Brasileirão-specific UI out of LaLiga2026"
```

---

### Task 5: Wire the real app icon

**Files:**
- Create: `BR2026/Resources/Assets.xcassets/AppIcon-LaLiga.appiconset/`
  (`Contents.json` + `AppIcon-LaLiga-1024.png`)
- Create: `BR2026/Resources/Assets.xcassets/AppIconPreview-LaLiga.imageset/`
  (`Contents.json` + `AppIconPreview-LaLiga.png`)
- Modify: `BR2026.xcodeproj/project.pbxproj` (via Ruby script — set `LaLiga2026`'s
  `ASSETCATALOG_COMPILER_APPICON_NAME`, remove its
  `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`)

**Interfaces:**
- Consumes: `design/AppIcon-LaLiga-1024.png` (already provided, 1024×1024).

- [ ] **Step 1: Create the primary App Icon Set from the provided artwork**

```bash
mkdir -p "BR2026/Resources/Assets.xcassets/AppIcon-LaLiga.appiconset"
cp "design/AppIcon-LaLiga-1024.png" "BR2026/Resources/Assets.xcassets/AppIcon-LaLiga.appiconset/AppIcon-LaLiga-1024.png"
cat > "BR2026/Resources/Assets.xcassets/AppIcon-LaLiga.appiconset/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "AppIcon-LaLiga-1024.png",
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
mkdir -p "BR2026/Resources/Assets.xcassets/AppIconPreview-LaLiga.imageset"
cp "design/AppIcon-LaLiga-1024.png" "BR2026/Resources/Assets.xcassets/AppIconPreview-LaLiga.imageset/AppIconPreview-LaLiga.png"
cat > "BR2026/Resources/Assets.xcassets/AppIconPreview-LaLiga.imageset/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "AppIconPreview-LaLiga.png",
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
target = project.targets.find { |t| t.name == "LaLiga2026" }
target.build_configuration_list.build_configurations.each do |config|
  config.build_settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIcon-LaLiga"
  config.build_settings.delete("ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES")
end
project.save
RUBY
```

- [ ] **Step 4: Verify the build setting change**

```bash
grep -A1 "LaLiga2026" BR2026.xcodeproj/project.pbxproj | grep "ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES" || echo "confirmed: no alternate icon names for LaLiga2026"
```

- [ ] **Step 5: Build the new target**

```bash
xcodebuild build -project BR2026.xcodeproj -scheme LaLiga2026 -destination "generic/platform=iOS Simulator" -quiet
```

Expected: exit 0.

- [ ] **Step 6: Commit**

```bash
git add BR2026/Resources/Assets.xcassets/AppIcon-LaLiga.appiconset BR2026/Resources/Assets.xcassets/AppIconPreview-LaLiga.imageset BR2026.xcodeproj/project.pbxproj
git commit -m "Wire LaLiga2026's real app icon"
```

---

### Task 6: Wire the real launch screen

**Files:**
- Create: `BR2026/App/LaunchScreen-LaLiga.storyboard`
- Create: `Generated/LaLiga-Info.plist`
- Create: `BR2026/Resources/Assets.xcassets/LaunchLogo-LaLiga.imageset/`
  (`Contents.json` + 3 identical copies of the provided splash PNG)
- Modify: `BR2026.xcodeproj/project.pbxproj` (via Ruby script — `LaLiga2026`'s
  `INFOPLIST_FILE` build setting AND its Resources build phase)

**Interfaces:**
- Consumes: `design/Splash-3g-LaLiga-1290x2796.png` (already provided, 1290×2796).

**Lesson learned from the Scottish Premiership expansion, applied proactively this time:**
duplicating the target in Task 3 also copied `BR2026`'s Resources-phase build-file
entries verbatim, including its `LaunchScreen-BR2026.storyboard` reference. That stale
reference must be explicitly removed from `LaLiga2026`'s own Resources phase (not just
the `INFOPLIST_FILE` setting changed), or the launch screen ships as a blank black frame —
this was only caught last time via real on-device verification, not a build check.

- [ ] **Step 1: Create the Launch Logo Image Set from the provided artwork**

```bash
mkdir -p "BR2026/Resources/Assets.xcassets/LaunchLogo-LaLiga.imageset"
cp "design/Splash-3g-LaLiga-1290x2796.png" "BR2026/Resources/Assets.xcassets/LaunchLogo-LaLiga.imageset/LaunchLogo-LaLiga.png"
cp "design/Splash-3g-LaLiga-1290x2796.png" "BR2026/Resources/Assets.xcassets/LaunchLogo-LaLiga.imageset/LaunchLogo-LaLiga@1x.png"
cp "design/Splash-3g-LaLiga-1290x2796.png" "BR2026/Resources/Assets.xcassets/LaunchLogo-LaLiga.imageset/LaunchLogo-LaLiga@2x.png"
cat > "BR2026/Resources/Assets.xcassets/LaunchLogo-LaLiga.imageset/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "LaunchLogo-LaLiga@1x.png", "idiom" : "universal", "scale" : "1x" },
    { "filename" : "LaunchLogo-LaLiga@2x.png", "idiom" : "universal", "scale" : "2x" },
    { "filename" : "LaunchLogo-LaLiga.png", "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON
```

- [ ] **Step 2: Create the launch screen storyboard**

`#AA151B` converts to `red 0.6667 (170/255), green 0.0824 (21/255), blue 0.1059 (27/255)`:

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
                            <imageView contentMode="scaleAspectFill" horizontalHuggingPriority="251" verticalHuggingPriority="251" image="LaunchLogo-LaLiga" translatesAutoresizingMaskIntoConstraints="YES" id="img1">
                                <rect key="frame" x="0.0" y="0.0" width="393" height="852"/>
                                <autoresizingMask key="autoresizingMask" widthSizable="YES" heightSizable="YES"/>
                            </imageView>
                        </subviews>
                        <viewLayoutGuide key="safeArea" id="6Tk-OE-BBY"/>
                        <color key="backgroundColor" red="0.6666666666666666" green="0.08235294117647059" blue="0.10588235294117647" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>
                    </view>
                </viewController>
                <placeholder placeholderIdentifier="IBFirstResponder" id="iYj-Kq-Ea1" userLabel="First Responder" sceneMemberID="firstResponder"/>
            </objects>
            <point key="canvasLocation" x="53" y="375"/>
        </scene>
    </scenes>
</document>
```

Save this to `BR2026/App/LaunchScreen-LaLiga.storyboard` — note the
`translatesAutoresizingMaskIntoConstraints="YES"` + explicit `frame`/`autoresizingMask` on
the `imageView`, **not** Auto Layout constraints (a documented gotcha: constraints
silently fail to render the image at all).

- [ ] **Step 3: Create the per-target partial Info.plist**

```bash
cp Generated/ScottishPremiership-Info.plist Generated/LaLiga-Info.plist
sed -i '' 's/LaunchScreen-ScottishPremiership/LaunchScreen-LaLiga/' Generated/LaLiga-Info.plist
```

- [ ] **Step 4: Point `INFOPLIST_FILE` at the new file, and register the new storyboard while removing the stale one**

```bash
export PATH="$(rbenv root)/shims:$PATH"
bundle exec ruby <<'RUBY'
require "xcodeproj"
project = Xcodeproj::Project.open("BR2026.xcodeproj")
target = project.targets.find { |t| t.name == "LaLiga2026" }

target.build_configuration_list.build_configurations.each do |config|
  config.build_settings["INFOPLIST_FILE"] = "Generated/LaLiga-Info.plist"
end

# Register the new storyboard file reference (in the same group as the other
# LaunchScreen-*.storyboard files) and add it to LaLiga2026's Resources phase.
app_group = project.main_group.recursive_children.find { |g| g.respond_to?(:path) && g.path == "App" && g.isa == "PBXGroup" }
storyboard_ref = app_group.new_reference("LaunchScreen-LaLiga.storyboard")
resources_phase = target.build_phases.find { |p| p.isa == "PBXResourcesBuildPhase" }
resources_phase.add_file_reference(storyboard_ref)

# Remove the stale LaunchScreen-BR2026.storyboard build-file entry duplication left in
# THIS target's Resources phase only — find BR2026's own storyboard file reference and
# drop any build file in this phase pointing at it.
br2026_storyboard_ref = project.main_group.recursive_children.find do |f|
  f.respond_to?(:path) && f.path == "LaunchScreen-BR2026.storyboard"
end
stale_build_files = resources_phase.files.select { |bf| bf.file_ref == br2026_storyboard_ref }
stale_build_files.each { |bf| resources_phase.remove_build_file(bf) }

puts "Resources phase now has #{resources_phase.files.count} entries; removed #{stale_build_files.count} stale BR2026 storyboard reference(s)"
project.save
RUBY
```

- [ ] **Step 5: Verify the Resources-phase fix**

```bash
grep -n "LaunchScreen-LaLiga\|LaunchScreen-BR2026" BR2026.xcodeproj/project.pbxproj
```

Manually confirm (by reading the surrounding `PBXNativeTarget`/`PBXResourcesBuildPhase`
context) that `LaLiga2026`'s own Resources phase contains `LaunchScreen-LaLiga.storyboard`
and does NOT contain `LaunchScreen-BR2026.storyboard`, while `BR2026`'s own Resources
phase still contains its own `LaunchScreen-BR2026.storyboard` reference, unaffected.

- [ ] **Step 6: Build the new target**

```bash
xcodebuild build -project BR2026.xcodeproj -scheme LaLiga2026 -destination "generic/platform=iOS Simulator" -quiet
```

Expected: exit 0.

- [ ] **Step 7: Manual verification (real caching pitfall — read before skipping)**

Install onto a Simulator device that has **never** had any of this project's bundle IDs
installed on it before. Confirm via screenshot or `simctl io recordVideo` that the launch
screen shows the real La Liga splash artwork, not a blank/solid-color screen. A
SpringBoard/Simulator-level launch-screen snapshot cache keyed by bundle ID can keep
showing a stale cached snapshot on a previously-used device even after a clean reinstall.

- [ ] **Step 8: Commit**

```bash
git add BR2026/App/LaunchScreen-LaLiga.storyboard Generated/LaLiga-Info.plist BR2026/Resources/Assets.xcassets/LaunchLogo-LaLiga.imageset BR2026.xcodeproj/project.pbxproj
git commit -m "Wire LaLiga2026's real launch screen"
```

---

### Task 7: Add `CrossAppLink.laLiga`

**Files:**
- Modify: `BR2026/Models/CrossAppLink.swift`
- Modify: `BR2026Tests/Models/CrossAppLinkTests.swift`

**Interfaces:**
- Produces: `CrossAppLink.laLiga`, included in `CrossAppLink.all`.

- [ ] **Step 1: Write the failing test**

The existing `siblingsExcludesCurrentApp` test asserts `siblings.count == 4` (the other 4
apps, excluding Premier League) — this must become `5`. Replace it:

```swift
@Test("siblings(excluding:) returns the other 5 apps, not the current one")
func siblingsExcludesCurrentApp() {
    let siblings = CrossAppLink.siblings(excluding: "premier-league")
    #expect(siblings.count == 5)
    #expect(!siblings.contains { $0.id == "premier-league" })
    #expect(siblings.contains { $0.id == "brasileirao" })
    #expect(siblings.contains { $0.id == "ligue-1" })
    #expect(siblings.contains { $0.id == "primeira-liga" })
    #expect(siblings.contains { $0.id == "scottish-premiership" })
    #expect(siblings.contains { $0.id == "la-liga" })
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:BR2026Tests/CrossAppLinkTests -quiet
```

Expected: FAIL — `siblings.count` is `4`, not `5`.

- [ ] **Step 3: Write the implementation**

Add to `BR2026/Models/CrossAppLink.swift`'s `extension CrossAppLink`, after
`.scottishPremiership`:

```swift
static let laLiga = CrossAppLink(
    id: "la-liga",
    displayName: "La Liga",
    accentColorHex: "#AA151B",
    urlScheme: "laliga2026",
    appStoreID: "0000000000"
)
```

Update the `all` array:

```swift
static let all: [CrossAppLink] = [brasileirao, premierLeague, ligue1, primeiraLiga, scottishPremiership, laLiga]
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:BR2026Tests/CrossAppLinkTests -quiet
```

Expected: PASS, both tests in the suite green.

- [ ] **Step 5: Commit**

```bash
git add BR2026/Models/CrossAppLink.swift BR2026Tests/Models/CrossAppLinkTests.swift
git commit -m "Add CrossAppLink.laLiga"
```

---

### Task 8: Add `es` as a supported locale, with Spanish translations for all 39 keys

**Files:**
- Modify: `BR2026.xcodeproj/project.pbxproj` (project-level `knownRegions`)
- Modify: `BR2026/Resources/Localizable.xcstrings`

**Interfaces:**
- Produces: `es` localization values for all 39 existing catalog keys — consumed by
  every target's UI when the device language is Spanish.

This task adds `es` using the user-approved translations. `terms_of_service_body`'s `es`
value already uses the `%@` placeholder (see Task 9, which parameterizes the other 5
locales the same way) — both tasks touch this one key's dictionary, but at different
`localizations` sub-keys, so there's no conflict either order.

- [ ] **Step 1: Add `es` to the project's `knownRegions`**

In `BR2026.xcodeproj/project.pbxproj`, change:

```
			knownRegions = (
				Base,
				en,
				"en-GB",
				fr,
				"pt-BR",
				"pt-PT",
			);
```

to:

```
			knownRegions = (
				Base,
				en,
				"en-GB",
				fr,
				"pt-BR",
				"pt-PT",
				es,
			);
```

- [ ] **Step 2: Add the `es` localization to all 39 keys**

Run this Python script from the repo root — it adds an `es` entry to every key's
`localizations` dict, using the exact user-approved text, and re-serializes with the
same minimal-diff formatting already established for this file (`separators=(',', ' : ')`,
trailing newline stripped):

```bash
python3 <<'PYEOF'
import json

with open("BR2026/Resources/Localizable.xcstrings") as f:
    data = json.load(f)

translations = {
    "App Icon": "Icono de la aplicación",
    "Check Fixtures for the full schedule": "Consulta Calendario para ver el horario completo",
    "Couldn't change the app icon. Try again.": "No se pudo cambiar el icono de la aplicación. Inténtalo de nuevo.",
    "Default": "Predeterminado",
    "Finished": "Finalizado",
    "Fixtures": "Calendario",
    "Legal": "Legal",
    "Matchday": "Jornada",
    "More": "Más",
    "More settings coming soon": "Más ajustes próximamente",
    "No events yet": "Aún no hay eventos",
    "No upcoming matches": "No hay próximos partidos",
    "Own Goal": "Autogol",
    "Penalty": "Penalti",
    "Preferences": "Preferencias",
    "Restore Purchases": "Restaurar compras",
    "Round": "Ronda",
    "Stadium": "Estadio",
    "Standings": "Clasificación",
    "Team Theme": "Temas de Equipos",
    "Terms of Service": "Términos de servicio",
    "Timeline": "Cronología",
    "Today": "Hoy",
    "Also Today": "También hoy",
    "Venue TBD": "Sede por confirmar",
    "FT": "FT",
    "LIVE": "EN VIVO",
    "PPD": "PPD",
    "VS": "VS",
    "Also %@": "También %1$@",
    "For %@": "Para %1$@",
    "Round %@": "Ronda %1$@",
    "Half-time %@–%@": "Descanso %1$@–%2$@",
    "%@ · %@": "%1$@ · %2$@",
    "%@ · FT": "%1$@ · FT",
    "%@ – %@": "%1$@ – %2$@",
    "%@": "%@",
    "": "",
    "terms_of_service_body": (
        "Al utilizar esta aplicación, aceptas los siguientes términos.\n\n"
        "1. Sobre esta aplicación\n"
        "Esta aplicación ofrece resultados en directo, calendario y clasificación del campeonato %@. "
        "Los datos de partidos, equipos y competición son proporcionados por una API deportiva de "
        "terceros y se muestran tal como se reciben; no garantizamos su precisión ni su actualización "
        "puntual.\n\n"
        "2. Uso aceptable\n"
        "Aceptas utilizar esta aplicación únicamente con fines lícitos y no intentar interrumpir, "
        "aplicar ingeniería inversa ni acceder sin autorización a sus servicios subyacentes.\n\n"
        "3. Sin garantía\n"
        "Esta aplicación se ofrece \"tal cual\", sin garantías de ningún tipo. No nos hacemos "
        "responsables de posibles inexactitudes en los datos de los partidos, actualizaciones no "
        "realizadas o interrupciones del servicio.\n\n"
        "4. Cambios en estos términos\n"
        "Podemos actualizar estos términos ocasionalmente. El uso continuado de la aplicación tras "
        "dichos cambios constituye la aceptación de los términos actualizados.\n\n"
        "5. Contacto\n"
        "Las preguntas sobre estos términos pueden dirigirse al contacto de soporte de la aplicación "
        "que figura en su página de la App Store."
    ),
}

assert len(translations) == 39, f"expected 39 translations, got {len(translations)}"

for key, es_value in translations.items():
    assert key in data["strings"], f"key {key!r} not found in catalog"
    entry = data["strings"][key]
    entry.setdefault("localizations", {})
    entry["localizations"]["es"] = {
        "stringUnit": {
            "state": "translated",
            "value": es_value
        }
    }

with open("BR2026/Resources/Localizable.xcstrings", "w") as f:
    json.dump(data, f, ensure_ascii=False, indent=2, separators=(',', ' : '))
    # json.dump with indent adds a trailing newline in some Python versions but not
    # others depending on the exact call shape used elsewhere in this codebase; strip
    # and re-add exactly one to match Xcode's own serialization.
f_content = open("BR2026/Resources/Localizable.xcstrings").read()
if not f_content.endswith("\n"):
    with open("BR2026/Resources/Localizable.xcstrings", "a") as f:
        f.write("\n")

print(f"Added 'es' to {len(translations)} keys")
PYEOF
```

- [ ] **Step 3: Verify the catalog is still valid JSON and has the right shape**

```bash
python3 -c "
import json
with open('BR2026/Resources/Localizable.xcstrings') as f:
    data = json.load(f)
es_count = sum(1 for entry in data['strings'].values() if 'es' in entry.get('localizations', {}))
print('Keys with es localization:', es_count)
"
```

Expected: `Keys with es localization: 39`.

- [ ] **Step 4: Build `BR2026` to confirm the catalog still compiles**

```bash
xcodebuild build -project BR2026.xcodeproj -scheme BR2026 -destination "generic/platform=iOS Simulator" -quiet
```

Expected: exit 0.

- [ ] **Step 5: Run the full test suite**

```bash
export PATH="$(rbenv root)/shims:$PATH"
bundle exec fastlane test
```

Expected: still 192/192 (this task adds no new tests — it's a data-only change to a
resource file).

- [ ] **Step 6: Commit**

```bash
git add BR2026.xcodeproj/project.pbxproj BR2026/Resources/Localizable.xcstrings
git commit -m "Add Spanish (es) localization for all 39 shared UI strings"
```

---

### Task 9: Fix Terms of Service's hardcoded championship name

**Files:**
- Modify: `BR2026/Resources/Localizable.xcstrings` (the `terms_of_service_body` key's
  `en`/`en-GB`/`fr`/`pt-BR`/`pt-PT` values — `es` was already added correctly-parameterized
  in Task 8)
- Modify: `BR2026/Views/More/TermsOfServiceView.swift`
- Modify: `BR2026/Views/More/MoreView.swift`
- Modify: `BR2026/Views/Root/ContentView.swift`

**Interfaces:**
- Consumes: `ChampionshipConfig.displayName` (existing).

- [ ] **Step 1: Parameterize the 5 existing locales' `terms_of_service_body` text**

Run this Python script from the repo root:

```bash
python3 <<'PYEOF'
import json

with open("BR2026/Resources/Localizable.xcstrings") as f:
    data = json.load(f)

replacements = {
    "en": ("for the Brasileirão championship", "for the %@ championship"),
    "en-GB": ("for the Brasileirão championship", "for the %@ championship"),
    "fr": ("du Championnat brésilien (Brasileirão)", "du championnat %@"),
    "pt-BR": ("do Campeonato Brasileiro", "do campeonato %@"),
    "pt-PT": ("do Campeonato Brasileiro", "do campeonato %@"),
}

entry = data["strings"]["terms_of_service_body"]
for locale, (old, new) in replacements.items():
    value = entry["localizations"][locale]["stringUnit"]["value"]
    assert old in value, f"{locale}: expected substring {old!r} not found"
    entry["localizations"][locale]["stringUnit"]["value"] = value.replace(old, new)

with open("BR2026/Resources/Localizable.xcstrings", "w") as f:
    json.dump(data, f, ensure_ascii=False, indent=2, separators=(',', ' : '))

f_content = open("BR2026/Resources/Localizable.xcstrings").read()
if not f_content.endswith("\n"):
    with open("BR2026/Resources/Localizable.xcstrings", "a") as f:
        f.write("\n")

print("Parameterized terms_of_service_body in 5 locales")
PYEOF
```

- [ ] **Step 2: Verify the substitution**

```bash
python3 -c "
import json
with open('BR2026/Resources/Localizable.xcstrings') as f:
    data = json.load(f)
entry = data['strings']['terms_of_service_body']
for locale in ['en', 'en-GB', 'fr', 'pt-BR', 'pt-PT', 'es']:
    value = entry['localizations'][locale]['stringUnit']['value']
    assert '%@' in value, f'{locale} missing %@'
    assert 'rasileir' not in value or locale in ('en', 'en-GB'), f'{locale} still hardcodes Brasileirão unexpectedly'
print('All 6 locales contain %@; no hardcoded Brasileirão remains outside the placeholder')
"
```

(The `en`/`en-GB` check is looser because `%@` substituted with `config.displayName ==
"Brasileirão"` for the `BR2026` target itself will legitimately contain "Brasileirão"
again at runtime — this step only confirms the *catalog text* no longer hardcodes it.)

- [ ] **Step 3: Thread `config` into `TermsOfServiceView`**

In `BR2026/Views/More/TermsOfServiceView.swift`, change:

```swift
import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.themeTokens) private var themeTokens

    var body: some View {
        ScrollView {
            Text("terms_of_service_body")
```

to:

```swift
import SwiftUI

struct TermsOfServiceView: View {
    let config: ChampionshipConfig
    @Environment(\.themeTokens) private var themeTokens

    var body: some View {
        ScrollView {
            Text(String(format: String(localized: "terms_of_service_body"), config.displayName))
```

(Everything else in the file — the modifiers on that `Text`, and the rest of `body` — is
unchanged.)

- [ ] **Step 4: Thread `config` through `MoreView`**

In `BR2026/Views/More/MoreView.swift`, add a `config` property and initializer
parameter:

```swift
struct MoreView: View {
    @State private var viewModel: MoreViewModel
    let config: ChampionshipConfig
    let service: MatchService
    let themeStore: TeamThemeStore
    let themePurchaseStore: PurchaseStore<TeamThemeOption>
    let iconPurchaseStore: PurchaseStore<TeamIconOption>
    @Environment(\.themeTokens) private var themeTokens

    init(config: ChampionshipConfig, service: MatchService, themeStore: TeamThemeStore, themePurchaseStore: PurchaseStore<TeamThemeOption>, iconPurchaseStore: PurchaseStore<TeamIconOption>) {
        _viewModel = State(initialValue: MoreViewModel(service: service))
        self.config = config
        self.service = service
        self.themeStore = themeStore
        self.themePurchaseStore = themePurchaseStore
        self.iconPurchaseStore = iconPurchaseStore
    }
```

Update the `TermsOfServiceView` construction site:

```swift
                case .termsOfService:
                    TermsOfServiceView(config: config)
```

- [ ] **Step 5: Thread `config` through `ContentView`**

In `BR2026/Views/Root/ContentView.swift`, update the `MoreView` construction line:

```swift
            MoreView(config: config, service: service, themeStore: themeStore, themePurchaseStore: themePurchaseStore, iconPurchaseStore: iconPurchaseStore)
```

(`ContentView` already has a `config: ChampionshipConfig` property — no new property
needed there, just passing the existing one through.)

- [ ] **Step 6: Build all 6 targets**

```bash
xcodebuild build -project BR2026.xcodeproj -scheme BR2026 -destination "generic/platform=iOS Simulator" -quiet
xcodebuild build -project BR2026.xcodeproj -scheme PremierLeague2026 -destination "generic/platform=iOS Simulator" -quiet
xcodebuild build -project BR2026.xcodeproj -scheme Ligue12026 -destination "generic/platform=iOS Simulator" -quiet
xcodebuild build -project BR2026.xcodeproj -scheme PrimeiraLiga2026 -destination "generic/platform=iOS Simulator" -quiet
xcodebuild build -project BR2026.xcodeproj -scheme ScottishPremiership2026 -destination "generic/platform=iOS Simulator" -quiet
xcodebuild build -project BR2026.xcodeproj -scheme LaLiga2026 -destination "generic/platform=iOS Simulator" -quiet
```

Expected: all six exit 0.

- [ ] **Step 7: Run the full test suite**

```bash
export PATH="$(rbenv root)/shims:$PATH"
bundle exec fastlane test
```

Expected: still 192/192 (Views aren't unit-tested; no test changes in this task).

- [ ] **Step 8: Manual verification**

Run `PremierLeague2026` (or any non-`BR2026` target) in Simulator, navigate to More →
Terms of Service, and confirm the first paragraph now reads "...for the Premier League
championship..." (or that target's own `displayName`) instead of "Brasileirão".

- [ ] **Step 9: Commit**

```bash
git add BR2026/Resources/Localizable.xcstrings BR2026/Views/More/TermsOfServiceView.swift BR2026/Views/More/MoreView.swift BR2026/Views/Root/ContentView.swift
git commit -m "Fix Terms of Service's hardcoded Brasileirão reference for all targets"
```

---

## Final Verification

- [ ] **Full test suite:**

```bash
export PATH="$(rbenv root)/shims:$PATH"
bundle exec fastlane test
```

Expected: 192/192 passing (191 baseline before this plan + 1 from Task 1's
`ChampionshipConfig` test; Tasks 3/4/5/6/8/9 add no new tests, Task 7 only rewrites an
existing test's body).

- [ ] **All 6 targets build:**

```bash
xcodebuild build -project BR2026.xcodeproj -scheme BR2026 -destination "generic/platform=iOS Simulator" -quiet
xcodebuild build -project BR2026.xcodeproj -scheme PremierLeague2026 -destination "generic/platform=iOS Simulator" -quiet
xcodebuild build -project BR2026.xcodeproj -scheme Ligue12026 -destination "generic/platform=iOS Simulator" -quiet
xcodebuild build -project BR2026.xcodeproj -scheme PrimeiraLiga2026 -destination "generic/platform=iOS Simulator" -quiet
xcodebuild build -project BR2026.xcodeproj -scheme ScottishPremiership2026 -destination "generic/platform=iOS Simulator" -quiet
xcodebuild build -project BR2026.xcodeproj -scheme LaLiga2026 -destination "generic/platform=iOS Simulator" -quiet
```

Expected: all six exit 0.

- [ ] **Manual Simulator verification:** install `LaLiga2026.app` alongside the other 5,
  confirm via screenshot: real La Liga match/standings data, the `#AA151B`/`#F1BF00`
  accent/tab-selection colors, the real app icon, the real splash artwork on a
  never-before-used simulator device.
- [ ] **Confirm the More screen** on `LaLiga2026` shows no "Team Theme" row and the App
  Icon picker shows only "Default" (no "Stadium", no purchasable team icons).
- [ ] **Confirm Spanish localization** by setting a Simulator device's language to
  Spanish and spot-checking a few screens (Matchday, Fixtures, Standings tab labels, the
  More screen, Terms of Service) render the new `es` strings.
