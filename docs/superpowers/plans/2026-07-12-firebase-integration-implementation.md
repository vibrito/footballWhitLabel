# Firebase Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire up Firebase Analytics, Firebase Crashlytics, and Firebase Cloud Messaging
scaffolding (no permission prompt) into the BR2026 app, per
`docs/superpowers/specs/2026-07-12-firebase-integration-design.md`.

**Architecture:** Add `firebase-ios-sdk` as a remote Swift package via a one-off Ruby script
using the `xcodeproj` gem (already proven against this exact project file — see Task 1).
Bridge SwiftUI's app lifecycle to Firebase's UIKit-shaped setup via a small `AppDelegate` and
`@UIApplicationDelegateAdaptor`. Commit `GoogleService-Info.plist` directly. Add an
`aps-environment` entitlement and `UIBackgroundModes: [remote-notification]` so silent push
delivery works, without ever requesting notification permission. Add a Crashlytics dSYM
upload Run Script phase. Update the Privacy Policy website (5 locales) and `CLAUDE.md`.

**Tech Stack:** Swift 6, SwiftUI (iOS 26+), SwiftData, `firebase-ios-sdk` 12.16.0 (pinned
`upToNextMajorVersion` from `12.0.0`) via Swift Package Manager, `xcodeproj` Ruby gem 1.28.1
(already installed, transitive dependency of `fastlane`) for the one-off pbxproj edit.

## Global Constraints

- `firebase-ios-sdk` is pinned `upToNextMajorVersion` from `12.0.0` (spec's exact value).
- Exactly three products are linked — `FirebaseAnalytics`, `FirebaseCrashlytics`,
  `FirebaseMessaging` — and **only** to the `BR2026` app target (UUID
  `1159F24D61A995330CC21750`). Never to `BR2026Tests` or `BR2026UITests`.
- `AppDelegate` must call `application.registerForRemoteNotifications()` but must **never**
  call `UNUserNotificationCenter.current().requestAuthorization(...)` anywhere in this app.
- No `Analytics.logEvent(...)` calls anywhere — automatic collection only.
- `GoogleService-Info.plist` is committed directly to the repo (not gitignored, not an
  `.example` template) — source file is at
  `/Users/mlbbr-mac-vinicius/projects/footballWhiteLabel/prints/GoogleService-Info.plist`,
  already verified: `BUNDLE_ID` = `com.vibrito.br2026`, matches this app exactly.
- Entitlement `aps-environment` is the literal string `development` (Xcode's signing
  pipeline substitutes `production` for distribution builds automatically).
- All 5 locale Privacy Policy pages (`en`, `en-gb`, `fr`, `pt-br`, `pt-pt`) get full,
  equivalent translated text — never English-with-a-note in a non-English locale.
- No new automated tests: `AppDelegate` is glue code with no business logic, consistent
  with `CLAUDE.md`'s "unit test ViewModels and Services — not Views." Each task's
  verification is a real `xcodebuild`/`fastlane test` run, not a unit test.
- Every new pbxproj entry must follow this project's established wiring recipe: a
  `PBXBuildFile` (if the file belongs to a build phase), a `PBXFileReference`, a
  `PBXGroup` children entry, and (for Sources/Resources files) a build-phase `files` array
  entry. Generate UUIDs via
  `python3 -c "import secrets; print(secrets.token_hex(12).upper())"` and verify uniqueness
  with `grep -c <UUID> BR2026.xcodeproj/project.pbxproj` (must be 0 before use).

---

### Task 1: Add `firebase-ios-sdk` as a remote Swift package, linked to the `BR2026` target

**Files:**
- Modify: `BR2026.xcodeproj/project.pbxproj` (via script, not hand-editing)

**Interfaces:**
- Produces: `FirebaseCore`, `FirebaseAnalytics`, `FirebaseCrashlytics`, `FirebaseMessaging`
  modules importable from any file in the `BR2026` target (Task 3 consumes these).

This exact script was prototyped and verified against this project on 2026-07-12: it
resolved the package (pinned at `12.16.0`), linked all three products, and produced a
successful `xcodebuild build` for the `BR2026` scheme. Do not modify the target UUID or the
product list — they are Global Constraints.

- [ ] **Step 1: Confirm a clean working tree before scripting a pbxproj change**

Run: `git status --short`
Expected: no output (clean). If not clean, stop and ask before proceeding — do not run a
pbxproj-editing script against uncommitted changes you didn't make.

- [ ] **Step 2: Write the integration script**

Create `/tmp/add_firebase_spm.rb` (not committed to the repo — this is a one-off tool):

```ruby
require 'xcodeproj'

project_path = 'BR2026.xcodeproj'
app_target_name = 'BR2026'
repo_url = 'https://github.com/firebase/firebase-ios-sdk'
min_version = '12.0.0'
products = %w[FirebaseAnalytics FirebaseCrashlytics FirebaseMessaging]

project = Xcodeproj::Project.open(project_path)

app_target = project.native_targets.find { |t| t.name == app_target_name }
raise "Target #{app_target_name} not found" unless app_target

package_ref = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
package_ref.repositoryURL = repo_url
package_ref.requirement = {
  'kind' => 'upToNextMajorVersion',
  'minimumVersion' => min_version,
}
project.root_object.package_references << package_ref

products.each do |product_name|
  product_dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  product_dep.package = package_ref
  product_dep.product_name = product_name
  app_target.package_product_dependencies << product_dep

  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = product_dep
  app_target.frameworks_build_phase.files << build_file
end

project.save

puts "Added package reference: #{package_ref.uuid}"
puts "App target frameworks_build_phase UUID: #{app_target.frameworks_build_phase.uuid}"
puts "Linked products: #{products.join(', ')}"
```

- [ ] **Step 3: Run the script**

Run (from repo root, with rbenv shims on `PATH`):
```bash
export PATH="$HOME/.rbenv/shims:$PATH"
bundle exec ruby /tmp/add_firebase_spm.rb
```
Expected output: three lines — a package reference UUID, a frameworks build phase UUID, and
`Linked products: FirebaseAnalytics, FirebaseCrashlytics, FirebaseMessaging`.

- [ ] **Step 4: Verify the target wiring**

Run: `grep -n "1159F24D61A995330CC21750 /\* BR2026 \*/ = {" -A6 BR2026.xcodeproj/project.pbxproj`
Expected: the `buildPhases` array now includes a third entry ending in `/* Frameworks */`,
alongside the existing `/* Sources */` and `/* Resources */` entries.

Run: `grep -n "78C6B9E9B67D1498742D6B7C /\* BR2026Tests \*/ = {" -A10 BR2026.xcodeproj/project.pbxproj | grep -c packageProductDependencies`
and
`grep -n "9A932244CA7F4616EF62261C /\* BR2026UITests \*/ = {" -A10 BR2026.xcodeproj/project.pbxproj | grep -c packageProductDependencies`
Expected: both print `0` — the test targets must not have gained a
`packageProductDependencies` line (the script only ever touched the `BR2026` app target
object).

- [ ] **Step 5: Resolve the package and do a full build**

Run: `xcodebuild -resolvePackageDependencies -project BR2026.xcodeproj -scheme BR2026`
Expected: ends with a "Resolved source packages" list including
`Firebase: https://github.com/firebase/firebase-ios-sdk @ 12.16.0` (or a later 12.x patch —
the pin is `upToNextMajorVersion`, so a newer 12.x is correct and expected if released since).

Run: `xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation build`
Expected: ends with `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit the resolved package manifest and pbxproj change**

```bash
git add BR2026.xcodeproj/project.pbxproj BR2026.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
git commit -m "Add firebase-ios-sdk SPM package, link Analytics/Crashlytics/Messaging to BR2026 target"
```

- [ ] **Step 7: Delete the one-off script**

Run: `rm /tmp/add_firebase_spm.rb`

---

### Task 2: Commit `GoogleService-Info.plist` and wire it as a Resources build phase entry

**Files:**
- Create: `BR2026/GoogleService-Info.plist` (copied from
  `prints/GoogleService-Info.plist`, already verified for this bundle ID)
- Modify: `BR2026.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces: `GoogleService-Info.plist` present in the app bundle at runtime, found
  automatically by `FirebaseApp.configure()` in Task 3 (Firebase's SDK looks it up by
  filename in the main bundle — no code-level path reference needed).

- [ ] **Step 1: Copy the file into the app source tree**

```bash
cp prints/GoogleService-Info.plist BR2026/GoogleService-Info.plist
```

- [ ] **Step 2: Generate three UUIDs and verify they're unused**

```bash
python3 -c "import secrets; print(secrets.token_hex(12).upper())"
python3 -c "import secrets; print(secrets.token_hex(12).upper())"
```
(One for the `PBXFileReference`, one for the `PBXBuildFile`.) For each UUID printed, run
`grep -c <UUID> BR2026.xcodeproj/project.pbxproj` and confirm it prints `0` before using it.
Call them `FILEREF_UUID` and `BUILDFILE_UUID` below.

- [ ] **Step 3: Add the `PBXFileReference`**

In the `/* Begin PBXFileReference section */` block, add (keeping the section's existing
alphabetical-by-UUID ordering is not required by Xcode, but insert it near the other
top-level `BR2026/` files like `0BF94F1B7FFEA78845976994 /* Championship.swift */` for
readability):

```
		FILEREF_UUID /* GoogleService-Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = "GoogleService-Info.plist"; sourceTree = "<group>"; };
```

- [ ] **Step 4: Add it to the top-level `BR2026` group's children**

Find the group `7057C6184FF2D44AA95632AD /* BR2026 */` (children currently: `App`,
`Components`, `Config`, `MockData`, `Models`, `Resources`, `Services`, `ViewModels`,
`Views`). Add a new child line:

```
				FILEREF_UUID /* GoogleService-Info.plist */,
```

- [ ] **Step 5: Add the `PBXBuildFile`**

In `/* Begin PBXBuildFile section */`, add:

```
		BUILDFILE_UUID /* GoogleService-Info.plist in Resources */ = {isa = PBXBuildFile; fileRef = FILEREF_UUID /* GoogleService-Info.plist */; };
```

- [ ] **Step 6: Add it to the app target's Resources build phase**

Find `0725F692AD27876A0AE3342B /* Resources */` (the `BR2026` app target's
`PBXResourcesBuildPhase`, currently listing `Assets.xcassets` and `Localizable.xcstrings`).
Add:

```
				BUILDFILE_UUID /* GoogleService-Info.plist in Resources */,
```

- [ ] **Step 7: Verify UUID reference counts**

```bash
grep -c "FILEREF_UUID" BR2026.xcodeproj/project.pbxproj   # expect 3 (definition + group + buildfile's fileRef)
grep -c "BUILDFILE_UUID" BR2026.xcodeproj/project.pbxproj # expect 2 (definition + resources-phase entry)
```

- [ ] **Step 8: Build to confirm the resource is picked up**

Run: `xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation build`
Expected: `** BUILD SUCCEEDED **`.

Run: `find /Users/mlbbr-mac-vinicius/Library/Developer/Xcode/DerivedData -name "BR2026.app" -newer BR2026/GoogleService-Info.plist -exec find {} -name "GoogleService-Info.plist" \;`
Expected: a path inside the built `.app` bundle, confirming it was copied.

- [ ] **Step 9: Commit**

```bash
git add BR2026/GoogleService-Info.plist BR2026.xcodeproj/project.pbxproj
git commit -m "Commit GoogleService-Info.plist and wire it into the app bundle"
```

---

### Task 3: `AppDelegate` — initialize Firebase, register for silent remote notifications

**Files:**
- Create: `BR2026/App/AppDelegate.swift`
- Modify: `BR2026/App/Championship.swift`
- Modify: `BR2026.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `FirebaseCore.FirebaseApp`, `FirebaseMessaging.Messaging` (from Task 1's SPM
  products).
- Produces: `AppDelegate` class, wired into `ChampionshipApp` via
  `@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate`.

- [ ] **Step 1: Create `BR2026/App/AppDelegate.swift`**

```swift
import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        // Silent registration: this hands the app an APNs token (below) and lets Firebase
        // mint an FCM token, without ever prompting the user for permission. No permission
        // means no visible alert/banner can show — that's a separate, later step once an
        // actual push-notification feature exists to justify asking.
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        // No consumer yet — this is scaffolding. A future push-notification phase reads this.
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {}
```

- [ ] **Step 2: Wire it into `ChampionshipApp`**

In `BR2026/App/Championship.swift`, add the property adaptor inside `struct ChampionshipApp: App`:

```swift
@main
struct ChampionshipApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let config = ChampionshipConfig.brasileirao
    let modelContainer: ModelContainer
```

(Insert as the first property, before `let config = ...` — matches SwiftUI's documented
`@UIApplicationDelegateAdaptor` placement convention.)

- [ ] **Step 3: Wire the new file into the project**

Generate two UUIDs (`FILEREF_UUID`, `BUILDFILE_UUID`) the same way as Task 2 Step 2,
verifying each with `grep -c` first.

Add to `/* Begin PBXFileReference section */`:
```
		FILEREF_UUID /* AppDelegate.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AppDelegate.swift; sourceTree = "<group>"; };
```

Add to the `App` group's children (`721F0DDE2FADE19F27795CB5`, currently just
`Championship.swift`):
```
				FILEREF_UUID /* AppDelegate.swift */,
```

Add to `/* Begin PBXBuildFile section */`:
```
		BUILDFILE_UUID /* AppDelegate.swift in Sources */ = {isa = PBXBuildFile; fileRef = FILEREF_UUID /* AppDelegate.swift */; };
```

Add to the `BR2026` app target's Sources build phase (`4A4FA446D5F73EAE1C9245D1`):
```
				BUILDFILE_UUID /* AppDelegate.swift in Sources */,
```

Verify: `grep -c "FILEREF_UUID"` → 3, `grep -c "BUILDFILE_UUID"` → 2.

- [ ] **Step 4: Build**

Run: `xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation build`
Expected: `** BUILD SUCCEEDED **`. (This is the first step that actually compiles
`import FirebaseCore` / `import FirebaseMessaging` — if it fails, re-check Task 1's package
linkage before touching this file.)

- [ ] **Step 5: Commit**

```bash
git add BR2026/App/AppDelegate.swift BR2026/App/Championship.swift BR2026.xcodeproj/project.pbxproj
git commit -m "Add AppDelegate: configure Firebase, register for silent remote notifications"
```

---

### Task 4: Entitlements and background mode for silent push delivery

**Files:**
- Create: `BR2026/BR2026.entitlements`
- Modify: `Generated/BR2026-Info.plist`
- Modify: `BR2026.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces: `CODE_SIGN_ENTITLEMENTS` build setting pointing at the new entitlements file;
  `UIBackgroundModes` key in the built `Info.plist`.

- [ ] **Step 1: Create `BR2026/BR2026.entitlements`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>aps-environment</key>
    <string>development</string>
</dict>
</plist>
```

- [ ] **Step 2: Add `UIBackgroundModes` to the generated Info.plist**

In `Generated/BR2026-Info.plist`, add before the closing `</dict>` (after the existing
`UILaunchScreen` key):

```xml
	<key>UIBackgroundModes</key>
	<array>
		<string>remote-notification</string>
	</array>
```

- [ ] **Step 3: Wire the entitlements file into the project (file reference + group only — no build-phase membership; it's referenced purely via the `CODE_SIGN_ENTITLEMENTS` build setting)**

Generate one UUID (`FILEREF_UUID`), verify with `grep -c` first.

Add to `/* Begin PBXFileReference section */`:
```
		FILEREF_UUID /* BR2026.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = BR2026.entitlements; sourceTree = "<group>"; };
```

Add to the top-level `BR2026` group's children (`7057C6184FF2D44AA95632AD`):
```
				FILEREF_UUID /* BR2026.entitlements */,
```

Verify: `grep -c "FILEREF_UUID" BR2026.xcodeproj/project.pbxproj` → 2 (definition + group;
no build-phase entry for entitlements files).

- [ ] **Step 4: Add `CODE_SIGN_ENTITLEMENTS` to both the app target's Debug and Release build configurations**

In `BR2026.xcodeproj/project.pbxproj`, find the two `XCBuildConfiguration` blocks for the
`BR2026` app target — `F6F6E6CD20B27A638E0554A9 /* Release */` and
`FAAFDCAF83355F998AFEEFE8 /* Debug */` (both currently list
`ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`, `ASSETCATALOG_COMPILER_APPICON_NAME`,
`CODE_SIGN_IDENTITY`, etc.). In **both** blocks, add one line:

```
				CODE_SIGN_ENTITLEMENTS = BR2026/BR2026.entitlements;
```

(Alphabetical placement: right after `CODE_SIGN_IDENTITY = "iPhone Developer";` and before
`CURRENT_PROJECT_VERSION = 2;`, matching the existing alphabetical ordering of keys in these
blocks.)

- [ ] **Step 5: Build**

Run: `xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation build`
Expected: `** BUILD SUCCEEDED **`.

Run: `plutil -p /Users/mlbbr-mac-vinicius/Library/Developer/Xcode/DerivedData/BR2026-*/Build/Products/Debug-iphonesimulator/BR2026.app/Info.plist | grep -A2 UIBackgroundModes`
Expected: shows `remote-notification` in the array.

- [ ] **Step 6: Commit**

```bash
git add BR2026/BR2026.entitlements Generated/BR2026-Info.plist BR2026.xcodeproj/project.pbxproj
git commit -m "Add aps-environment entitlement and remote-notification background mode"
```

---

### Task 5: Crashlytics dSYM upload Run Script build phase

**Files:**
- Modify: `BR2026.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces: a `PBXShellScriptBuildPhase` on the `BR2026` app target that uploads dSYMs to
  Crashlytics on every build, so crashes are symbolicated in the Firebase console.

- [ ] **Step 1: Generate a UUID for the new build phase**

```bash
python3 -c "import secrets; print(secrets.token_hex(12).upper())"
```
Verify unused via `grep -c`. Call it `SCRIPT_PHASE_UUID`.

- [ ] **Step 2: Add the `PBXShellScriptBuildPhase`**

Add a new section after `/* End PBXResourcesBuildPhase section */` (or alongside the
existing `PBXFrameworksBuildPhase`/`PBXResourcesBuildPhase` sections — section ordering in
this file doesn't matter to Xcode, only object references do):

```
/* Begin PBXShellScriptBuildPhase section */
		SCRIPT_PHASE_UUID /* Upload Crashlytics dSYMs */ = {
			isa = PBXShellScriptBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			inputPaths = (
				"$(DWARF_DSYM_FOLDER_PATH)/$(DWARF_DSYM_FILE_NAME)",
				"$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)",
			);
			name = "Upload Crashlytics dSYMs";
			outputPaths = (
			);
			runOnlyForDeploymentPostprocessing = 0;
			shellPath = /bin/sh;
			shellScript = "\"${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run\"\n";
		};
/* End PBXShellScriptBuildPhase section */
```

- [ ] **Step 3: Add the phase to the `BR2026` app target's `buildPhases` array**

Find `1159F24D61A995330CC21750 /* BR2026 */` again (its `buildPhases` array now has
`Sources`, `Resources`, `Frameworks` from Task 1). Append as the last phase:

```
				SCRIPT_PHASE_UUID /* Upload Crashlytics dSYMs */,
```

(Run script phases that read the dSYM must come after the binary is built and symbols
exist, so appending last is correct — Xcode already runs Sources/Resources/Frameworks
before any trailing Run Script phase.)

- [ ] **Step 4: Verify UUID reference count**

`grep -c "SCRIPT_PHASE_UUID" BR2026.xcodeproj/project.pbxproj` → 2 (definition + buildPhases
array entry).

- [ ] **Step 5: Build**

Run: `xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation build`
Expected: `** BUILD SUCCEEDED **`, with a `Upload Crashlytics dSYMs` step visible in the
build log (search the output for that phase name).

- [ ] **Step 6: Commit**

```bash
git add BR2026.xcodeproj/project.pbxproj
git commit -m "Add Crashlytics dSYM upload Run Script build phase"
```

---

### Task 6: Update the Privacy Policy website (5 locales) and `CLAUDE.md`

**Files:**
- Modify: `website/privacy/en/index.html`
- Modify: `website/privacy/en-gb/index.html`
- Modify: `website/privacy/fr/index.html`
- Modify: `website/privacy/pt-br/index.html`
- Modify: `website/privacy/pt-pt/index.html`
- Modify: `CLAUDE.md`

**Interfaces:** None — this task only changes prose/docs, no code.

- [ ] **Step 1: Update `website/privacy/en/index.html`**

Replace:
```html
        <h2>2. Analytics and Tracking</h2>
        <p>This app does not use analytics, advertising, or tracking software of any kind.</p>

        <h2>3. Third-Party Services</h2>
        <p>Match, team, and competition data (including team crest images) is loaded from a third-party sports data API. Loading this data may expose your device's IP address to that service, as is standard for any network request. We do not control and are not responsible for that service's own data practices.</p>
```
With:
```html
        <h2>2. Analytics and Tracking</h2>
        <p>This app uses Firebase Analytics and Firebase Crashlytics (both provided by Google) to understand how the app is used and to diagnose crashes. Firebase Analytics collects general usage data such as which screens are viewed and how often the app is opened; Firebase Crashlytics collects crash reports, which may include device model, OS version, and app state at the time of the crash. Neither service is used for advertising, and neither collects your name, email, or other personally identifying information.</p>

        <h2>3. Third-Party Services</h2>
        <p>Match, team, and competition data (including team crest images) is loaded from a third-party sports data API. This app also uses Firebase (Google) for analytics and crash reporting, as described above. Loading data from these services may expose your device's IP address to them, as is standard for any network request. We do not control and are not responsible for these services' own data practices.</p>
```

- [ ] **Step 2: Update `website/privacy/en-gb/index.html`**

Use the identical replacement text as Step 1 (this project's existing `en`/`en-gb` pages
already share verbatim body text — only the `<html lang>` and nav `aria-current` differ).

- [ ] **Step 3: Update `website/privacy/fr/index.html`**

Replace:
```html
        <h2>2. Analyse et suivi</h2>
        <p>Cette application n'utilise aucun logiciel d'analyse, de publicité ou de suivi.</p>

        <h2>3. Services tiers</h2>
        <p>Les données de matchs, d'équipes et de compétition (y compris les images des écussons d'équipe) sont chargées depuis une API sportive tierce. Le chargement de ces données peut exposer l'adresse IP de votre appareil à ce service, comme c'est le cas pour toute requête réseau standard. Nous ne contrôlons pas et ne sommes pas responsables des pratiques de ce service en matière de données.</p>
```
With:
```html
        <h2>2. Analyse et suivi</h2>
        <p>Cette application utilise Firebase Analytics et Firebase Crashlytics (tous deux fournis par Google) pour comprendre l'utilisation de l'application et diagnostiquer les plantages. Firebase Analytics collecte des données d'utilisation générales, comme les écrans consultés et la fréquence d'ouverture de l'application ; Firebase Crashlytics collecte des rapports de plantage, qui peuvent inclure le modèle de l'appareil, la version du système d'exploitation et l'état de l'application au moment du plantage. Aucun de ces services n'est utilisé à des fins publicitaires, et aucun ne collecte votre nom, votre adresse e-mail ou d'autres informations personnelles identifiables.</p>

        <h2>3. Services tiers</h2>
        <p>Les données de matchs, d'équipes et de compétition (y compris les images des écussons d'équipe) sont chargées depuis une API sportive tierce. Cette application utilise également Firebase (Google) pour l'analyse et le diagnostic des plantages, comme décrit ci-dessus. Le chargement de ces données peut exposer l'adresse IP de votre appareil à ces services, comme c'est le cas pour toute requête réseau standard. Nous ne contrôlons pas et ne sommes pas responsables des pratiques de données de ces services.</p>
```

- [ ] **Step 4: Update `website/privacy/pt-br/index.html`**

Replace:
```html
        <h2>2. Análise e rastreamento</h2>
        <p>Este aplicativo não utiliza software de análise, publicidade ou rastreamento de nenhum tipo.</p>

        <h2>3. Serviços de terceiros</h2>
        <p>Os dados de partidas, times e competição (incluindo as imagens dos escudos dos times) são carregados de uma API esportiva de terceiros. O carregamento desses dados pode expor o endereço IP do seu dispositivo a esse serviço, como é padrão em qualquer solicitação de rede. Não controlamos nem somos responsáveis pelas práticas de dados desse serviço.</p>
```
With:
```html
        <h2>2. Análise e rastreamento</h2>
        <p>Este aplicativo utiliza o Firebase Analytics e o Firebase Crashlytics (ambos fornecidos pelo Google) para entender como o aplicativo é usado e diagnosticar falhas. O Firebase Analytics coleta dados de uso gerais, como quais telas são visualizadas e com que frequência o aplicativo é aberto; o Firebase Crashlytics coleta relatórios de falhas, que podem incluir o modelo do dispositivo, a versão do sistema operacional e o estado do aplicativo no momento da falha. Nenhum dos serviços é usado para publicidade, e nenhum coleta seu nome, e-mail ou outras informações de identificação pessoal.</p>

        <h2>3. Serviços de terceiros</h2>
        <p>Os dados de partidas, times e competição (incluindo as imagens dos escudos dos times) são carregados de uma API esportiva de terceiros. Este aplicativo também utiliza o Firebase (Google) para análise e relatórios de falhas, conforme descrito acima. O carregamento de dados desses serviços pode expor o endereço IP do seu dispositivo a eles, como é padrão em qualquer solicitação de rede. Não controlamos nem somos responsáveis pelas práticas de dados desses serviços.</p>
```

- [ ] **Step 5: Update `website/privacy/pt-pt/index.html`**

Replace:
```html
        <h2>2. Análise e monitorização</h2>
        <p>Esta aplicação não utiliza software de análise, publicidade ou monitorização de qualquer tipo.</p>

        <h2>3. Serviços de terceiros</h2>
        <p>Os dados de jogos, equipas e competição (incluindo as imagens dos emblemas das equipas) são carregados a partir de uma API desportiva de terceiros. O carregamento destes dados pode expor o endereço IP do seu dispositivo a esse serviço, tal como é habitual em qualquer pedido de rede. Não controlamos nem somos responsáveis pelas práticas de dados desse serviço.</p>
```
With:
```html
        <h2>2. Análise e monitorização</h2>
        <p>Esta aplicação utiliza o Firebase Analytics e o Firebase Crashlytics (ambos fornecidos pela Google) para compreender a utilização da aplicação e diagnosticar falhas. O Firebase Analytics recolhe dados de utilização gerais, como os ecrãs visualizados e a frequência com que a aplicação é aberta; o Firebase Crashlytics recolhe relatórios de falhas, que podem incluir o modelo do dispositivo, a versão do sistema operativo e o estado da aplicação no momento da falha. Nenhum dos serviços é utilizado para publicidade, e nenhum recolhe o seu nome, e-mail ou outras informações de identificação pessoal.</p>

        <h2>3. Serviços de terceiros</h2>
        <p>Os dados de jogos, equipas e competição (incluindo as imagens dos emblemas das equipas) são carregados a partir de uma API desportiva de terceiros. Esta aplicação utiliza também o Firebase (Google) para análise e relatórios de falhas, conforme descrito acima. O carregamento de dados destes serviços pode expor o endereço IP do seu dispositivo aos mesmos, tal como é habitual em qualquer pedido de rede. Não controlamos nem somos responsáveis pelas práticas de dados destes serviços.</p>
```

- [ ] **Step 6: Update `CLAUDE.md`'s Tech Stack table**

Replace:
```
| External dependencies | None |
```
With:
```
| External dependencies | Firebase (Analytics, Crashlytics, Messaging) via SPM |
```

- [ ] **Step 7: Add a Firebase section to `CLAUDE.md`**, after the `## Backend API` section
(before `## Fastlane / Release Automation`):

```markdown
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
- Analytics collection is automatic-only — no `Analytics.logEvent(...)` calls anywhere in
  the codebase. Crashlytics uploads dSYMs via a Run Script build phase on the app target.
```

- [ ] **Step 8: Update `CLAUDE.md`'s Scope section**

Replace:
```
- No user accounts, no notifications, no watchOS/widgets — future phases.
```
With:
```
- No user accounts, no user-visible notifications, no watchOS/widgets — future phases.
  Firebase Messaging is wired up at the plumbing level (APNs registration, FCM token
  generation) as scaffolding for a future phase, but no permission is requested and no
  push-consuming feature exists yet.
```

- [ ] **Step 9: Commit**

```bash
git add website/privacy CLAUDE.md
git commit -m "Update Privacy Policy (5 locales) and CLAUDE.md for Firebase Analytics/Crashlytics"
```

---

## Final Verification

- [ ] Run the full test suite: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test`
  Expected: all tests pass (no new tests were added, but this confirms nothing broke).
- [ ] Run a full Simulator build and boot to confirm no launch-time crash:
  ```bash
  xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17' -skipMacroValidation build
  xcrun simctl boot "iPhone 17" 2>/dev/null || true
  xcrun simctl install booted /Users/mlbbr-mac-vinicius/Library/Developer/Xcode/DerivedData/BR2026-*/Build/Products/Debug-iphonesimulator/BR2026.app
  xcrun simctl launch booted com.vibrito.br2026
  ```
  Expected: launches without crashing (check `xcrun simctl spawn booted log stream --predicate 'subsystem == "com.vibrito.br2026"' --style compact` briefly, or just confirm the process is running via `xcrun simctl list | grep -A1 "iPhone 17"` / a screenshot).
