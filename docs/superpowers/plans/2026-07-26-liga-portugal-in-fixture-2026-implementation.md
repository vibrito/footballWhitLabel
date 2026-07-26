# Liga Portugal in Fixture 2026 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Liga Portugal selectable in the Fixture 2026 app, with a matching alternate app icon.

**Architecture:** Almost everything already exists. The `PPL` entry in `CompetitionCatalog` is fully configured and differs from the two live leagues only by `isEnabled: false`, so enabling it is one flag plus the two tests that assert today's lock state. The app icon is independent of the catalog — it is a Settings picker case — and is included so Liga Portugal is not the only league without one.

**Tech Stack:** SwiftUI (iOS 26), Swift Testing (`@Test`/`@Suite`), Xcode asset catalogs, `xcodebuild`.

## Global Constraints

- **Repo:** `/Users/mlbbr-mac-vinicius/projects/worldcup` (the Fixture 2026 app). The spec and plan live in the *other* repo, `/Users/mlbbr-mac-vinicius/projects/footballWhiteLabel` — do not confuse them.
- **Work directly on `main`.** No branches, no worktrees.
- **Do not push until BOTH Task 1 and Task 2 are committed.** The user explicitly asked for the competition and its icon to ship together, not the wiring first.
- **Do not touch** `Fixture2026App/Models/TeamCrestSymbol.swift` or `Fixture2026App/Components/CrestDisc.swift`. They are byte-shared with the other repo; a changed `// crest-sync:` stamp means something went wrong.
- **No hardcoded user-facing strings.** Everything through the string catalog. The one new string is `settings.appicon.portuguese`, and it needs real translations for all five locales this app covers: `en`, `en-GB`, `fr`, `pt-BR`, `pt-PT`. **This app has no `es`** — do not add one.
- **Never round-trip `Localizable.xcstrings` through a JSON serializer.** An agent did that earlier in this project and reformatted all ~4,700 lines. Edit it as text, surgically.
- **Never run `git checkout`/`git restore`/`git stash` on a catalog file, and never `git add -A`.** An agent destroyed uncommitted catalog content that way earlier in this project.
- **Unit tests cover Models, ViewModels and Services, not Views** (this repo's CLAUDE.md). `CompetitionCatalog` and `AppIconOption` are both Models, so both are in scope for tests.
- **Test command** (run in the FOREGROUND with a 600000 ms Bash timeout — backgrounding `xcodebuild` has repeatedly stalled agents in this project):
  ```
  cd /Users/mlbbr-mac-vinicius/projects/worldcup && set -o pipefail && xcodebuild test -project Fixture2026.xcodeproj -scheme Fixture2026 -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:Fixture2026Tests 2>&1 | tail -30; echo "EXIT: ${pipestatus[1]}"
  ```
  This shell is **zsh**: use `${pipestatus[1]}` (lowercase, 1-indexed). Bash's `${PIPESTATUS[0]}` expands to an empty string here and reads as a pass while checking nothing.

**Spec:** `/Users/mlbbr-mac-vinicius/projects/footballWhiteLabel/docs/superpowers/specs/2026-07-26-liga-portugal-in-fixture-2026-design.md`

---

## File Structure

| File | Change |
|---|---|
| `Fixture2026App/Models/CompetitionCatalog.swift` | Remove `isEnabled: false` from the `PPL` entry |
| `Fixture2026AppTests/Models/CompetitionCatalogTests.swift` | Update the two tests that encode the lock state |
| `Fixture2026App/Assets.xcassets/AppIcon-Portuguese.appiconset/` | **new** — icon set + `Contents.json` |
| `Fixture2026App/Assets.xcassets/AppIconPreview-Portuguese.imageset/` | **new** — picker thumbnail + `Contents.json` |
| `Fixture2026.xcodeproj/project.pbxproj` | Register the new icon in **both** build configurations |
| `Fixture2026App/Models/AppIconOption.swift` | New `portuguese` case, three switch arms |
| `Fixture2026AppTests/Models/AppIconOptionTests.swift` | Extend two tests for the new case |
| `Fixture2026App/Resources/Localizable.xcstrings` | New `settings.appicon.portuguese` key |

No new `.swift` files, so no target-membership work is needed. (Asset catalogs are already target members; adding image sets inside them requires no project change beyond the build setting below.)

---

### Task 1: Enable the Liga Portugal competition

**Files:**
- Modify: `Fixture2026App/Models/CompetitionCatalog.swift:28`
- Test: `Fixture2026AppTests/Models/CompetitionCatalogTests.swift`

**Interfaces:**
- Consumes: `Competition.isEnabled: Bool` — already defaults to `true` (`Fixture2026App/Models/Competition.swift:19`).
- Produces: `CompetitionCatalog.enabled` now returns four competitions. Nothing in Task 2 depends on this.

- [ ] **Step 1: Update the two tests that encode today's lock state**

In `Fixture2026AppTests/Models/CompetitionCatalogTests.swift`, replace these two tests entirely:

```swift
    @Test func onlyWorldCupBrasileiraoAndScottishAreEnabled() {
        let enabledCodes = Set(CompetitionCatalog.all.filter(\.isEnabled).map(\.code))
        #expect(enabledCodes == ["2026", "BSA", "SPL"])
        let lockedCodes = Set(CompetitionCatalog.all.filter { !$0.isEnabled }.map(\.code))
        #expect(lockedCodes == ["PL", "FL1", "PPL", "PD"])
    }

    @Test func enabledReturnsThreeCompetitionsInCatalogOrder() {
        #expect(CompetitionCatalog.enabled.map(\.code) == ["2026", "BSA", "SPL"])
    }
```

with:

```swift
    @Test func onlyWorldCupBrasileiraoScottishAndLigaPortugalAreEnabled() {
        let enabledCodes = Set(CompetitionCatalog.all.filter(\.isEnabled).map(\.code))
        #expect(enabledCodes == ["2026", "BSA", "SPL", "PPL"])
        let lockedCodes = Set(CompetitionCatalog.all.filter { !$0.isEnabled }.map(\.code))
        #expect(lockedCodes == ["PL", "FL1", "PD"])
    }

    @Test func enabledReturnsFourCompetitionsInCatalogOrder() {
        #expect(CompetitionCatalog.enabled.map(\.code) == ["2026", "BSA", "SPL", "PPL"])
    }
```

Leave every other test in the file alone. In particular `leaguesAreOrderedBrasileiraoScottishLigaPortugalFirst` already expects `PPL` third in league order and must keep passing untouched — if it starts failing, the catalog order was changed by mistake.

- [ ] **Step 2: Run the tests to verify they fail**

Run the test command from Global Constraints.
Expected: the two rewritten tests FAIL, because `PPL` is still locked — `enabledCodes` is missing `"PPL"` and `lockedCodes` still contains it.

- [ ] **Step 3: Enable the competition**

In `Fixture2026App/Models/CompetitionCatalog.swift`, the `PPL` entry currently reads:

```swift
        Competition(id: "PPL", code: "PPL", displayNameKey: "competition.ppl",
                    baseURL: leagueBaseURL, format: .league, dataSource: .live,
                    accentHex: "#00235A", tabAccentHex: "#19FF91",
                    flagAssetName: "pt", logoURL: nil, isEnabled: false),
```

Drop the `isEnabled: false` argument so it takes the struct's `true` default:

```swift
        Competition(id: "PPL", code: "PPL", displayNameKey: "competition.ppl",
                    baseURL: leagueBaseURL, format: .league, dataSource: .live,
                    accentHex: "#00235A", tabAccentHex: "#19FF91",
                    flagAssetName: "pt", logoURL: nil),
```

Also update the doc comment on `CompetitionCatalog.enabled`, which currently names the three enabled competitions:

```swift
    /// Competitions whose feature flag is on (currently World Cup, Brasileirão,
    /// Scottish Premiership), in catalog order.
```

becomes:

```swift
    /// Competitions whose feature flag is on (currently World Cup, Brasileirão,
    /// Scottish Premiership, Liga Portugal), in catalog order.
```

- [ ] **Step 4: Run the tests to verify they pass**

Run the test command.
Expected: `** TEST SUCCEEDED **`, `EXIT: 0`. Both rewritten tests pass and the whole suite is green.

- [ ] **Step 5: Commit (do NOT push)**

```bash
cd /Users/mlbbr-mac-vinicius/projects/worldcup
git add Fixture2026App/Models/CompetitionCatalog.swift Fixture2026AppTests/Models/CompetitionCatalogTests.swift
git commit -m "$(cat <<'EOF'
Enable Liga Portugal

The catalog entry was already complete — code, league base URL, live data
source, brand navy and its selection green, the pt flag — and differed
from the two live leagues only by isEnabled: false. Everything it needs
was already in place too: display strings in five locales, the flag
asset, all 18 crest symbols, and live API coverage.

So this is the flag, plus the two tests that asserted the old lock state
by name.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Add the Portuguese app icon

**BLOCKED until the user supplies the icon.** They are creating a new one after the first draft read too similarly to the Brazilian icon (both a football on a similar green; backgrounds only 48 apart in RGB distance). Do not start this task until you have been given the path to the finished PNG. Do not substitute the earlier `design/AppIcon-PPL-1024.png` — it was explicitly rejected.

**Files:**
- Create: `Fixture2026App/Assets.xcassets/AppIcon-Portuguese.appiconset/AppIcon-Portuguese-1024.png`
- Create: `Fixture2026App/Assets.xcassets/AppIcon-Portuguese.appiconset/Contents.json`
- Create: `Fixture2026App/Assets.xcassets/AppIconPreview-Portuguese.imageset/AppIconPreview-Portuguese.png`
- Create: `Fixture2026App/Assets.xcassets/AppIconPreview-Portuguese.imageset/Contents.json`
- Modify: `Fixture2026.xcodeproj/project.pbxproj` (lines ~1783 and ~1813)
- Modify: `Fixture2026App/Models/AppIconOption.swift`
- Modify: `Fixture2026App/Resources/Localizable.xcstrings`
- Test: `Fixture2026AppTests/Models/AppIconOptionTests.swift`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: `AppIconOption.portuguese`, with `iconAssetName == "AppIcon-Portuguese"` and `previewImageName == "AppIconPreview-Portuguese"`.

- [ ] **Step 1: Verify the supplied PNG**

```bash
python3 -c "
from PIL import Image
im = Image.open('<PATH THE USER GAVE YOU>')
print('format:', im.format, 'size:', im.size, 'mode:', im.mode)
assert im.size == (1024, 1024), 'must be exactly 1024x1024'
if im.mode == 'RGBA':
    print('min alpha:', im.getchannel('A').getextrema()[0], '(must be 255 — fully opaque)')
"
```

Expected: PNG, 1024×1024. RGBA is fine and is what the existing icons use — but if there is any alpha below 255, stop and report rather than shipping a transparent app icon.

- [ ] **Step 2: Create the App Icon Set**

Copy the user's PNG to `Fixture2026App/Assets.xcassets/AppIcon-Portuguese.appiconset/AppIcon-Portuguese-1024.png`, then create `Contents.json` beside it with exactly this content (matching `AppIcon-Scottish.appiconset/Contents.json`):

```json
{
  "images" : [
    {
      "filename" : "AppIcon-Portuguese-1024.png",
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
```

- [ ] **Step 3: Create the preview Image Set**

Copy the same PNG to `Fixture2026App/Assets.xcassets/AppIconPreview-Portuguese.imageset/AppIconPreview-Portuguese.png`, then create `Contents.json` beside it with exactly this content (matching `AppIconPreview-Scottish.imageset/Contents.json` — note the empty 2x/3x slots, which is how the existing ones are structured):

```json
{
  "images" : [
    {
      "filename" : "AppIconPreview-Portuguese.png",
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
```

- [ ] **Step 4: Register the icon in BOTH build configurations**

**This is the step most likely to be missed, and skipping it produces a runtime failure rather than a build error.** The asset catalog alone is not enough: `UIApplication.setAlternateIconName("AppIcon-Portuguese")` fails unless the name is in `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`. The user would see the option in the picker, tap it, and get the "Couldn't change the app icon" error.

In `Fixture2026.xcodeproj/project.pbxproj` the setting appears **twice** — once for Debug (~line 1783) and once for Release (~line 1813). Both currently read:

```
				ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = "AppIcon-Brazilian AppIcon-Scottish";
```

Change **both** to:

```
				ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = "AppIcon-Brazilian AppIcon-Scottish AppIcon-Portuguese";
```

Verify with:

```bash
grep -c "AppIcon-Brazilian AppIcon-Scottish AppIcon-Portuguese" Fixture2026.xcodeproj/project.pbxproj
```

Expected: `2`. If it prints `1`, you only updated one configuration and the icon will fail in the other.

- [ ] **Step 5: Add the localized picker label**

Add `settings.appicon.portuguese` to `Fixture2026App/Resources/Localizable.xcstrings` as a **surgical text insertion** — do not reserialize the file. Model it exactly on the existing `settings.appicon.scottish` entry, which reads `Scottish` / `Scottish` / `Écossais` / `Escocês` / `Escocês` across `en` / `en-GB` / `fr` / `pt-BR` / `pt-PT`.

Use these values:

| locale | value |
|---|---|
| `en` | `Portuguese` |
| `en-GB` | `Portuguese` |
| `fr` | `Portugais` |
| `pt-BR` | `Português` |
| `pt-PT` | `Português` |

The file as a whole is not strictly sorted (it starts with empty-string and punctuation keys), but the `settings.appicon.*` group is alphabetical — `settings.appicon`, `.brazilian`, `.error`, `.scottish`, `.stadium` — so insert the new key between `.error` and `.scottish` to keep that group tidy.

Afterwards, confirm the file still parses and no key was lost:

```bash
python3 -c "
import json, subprocess
w = json.load(open('Fixture2026App/Resources/Localizable.xcstrings'))
h = json.loads(subprocess.run(['git','show','HEAD:Fixture2026App/Resources/Localizable.xcstrings'],capture_output=True,text=True).stdout)
print('parses OK; keys', len(h['strings']), '->', len(w['strings']))
print('lost:', [k for k in h['strings'] if k not in w['strings']] or 'none')
print('locales:', sorted(w['strings']['settings.appicon.portuguese']['localizations']))
"
```

Expected: exactly one key added, none lost, and the five locales listed.

- [ ] **Step 6: Extend the two icon tests**

In `Fixture2026AppTests/Models/AppIconOptionTests.swift`, add one assertion to each of two existing tests. Note a new case does **not** break these tests — they name each case explicitly — so without this step `portuguese` would be silently uncovered.

To "Alternate options map to their App Icon Set names", after the `scottish` line:

```swift
        #expect(AppIconOption.portuguese.iconAssetName == "AppIcon-Portuguese")
```

To "Every option has a distinct preview image set", after the `scottish` line:

```swift
        #expect(AppIconOption.portuguese.previewImageName == "AppIconPreview-Portuguese")
```

Leave the `Set(names).count == names.count` distinctness assertion in that second test as-is — it uses `allCases` and keeps working.

- [ ] **Step 7: Run the tests to verify they fail**

Run the test command.
Expected: compile failure — `type 'AppIconOption' has no member 'portuguese'`. That is the correct red state here.

- [ ] **Step 8: Add the enum case**

In `Fixture2026App/Models/AppIconOption.swift`, add the case and its three switch arms. Order matters: `stadium` must stay first (asserted by the "Stadium is offered first" test), and `portuguese` goes after `scottish` so the picker order matches the catalog's league order.

```swift
    case stadium
    case brazilian
    case scottish
    case portuguese
```

In `displayName`:
```swift
        case .portuguese: "settings.appicon.portuguese"
```

In `iconAssetName`:
```swift
        case .portuguese: "AppIcon-Portuguese"
```

In `previewImageName`:
```swift
        case .portuguese: "AppIconPreview-Portuguese"
```

Also update the type's doc comment, which currently names only two alternates:

```swift
/// The alternate app icons the user can pick in Settings. Stadium is the primary
/// (shipped) icon; Brazilian and Scottish are asset-catalog alternates switched via
/// `UIApplication.setAlternateIconName(_:)`.
```

becomes:

```swift
/// The alternate app icons the user can pick in Settings. Stadium is the primary
/// (shipped) icon; Brazilian, Scottish and Portuguese are asset-catalog alternates
/// switched via `UIApplication.setAlternateIconName(_:)`.
```

- [ ] **Step 9: Run the tests to verify they pass**

Run the test command.
Expected: `** TEST SUCCEEDED **`, `EXIT: 0`.

- [ ] **Step 10: Commit (do NOT push yet)**

```bash
cd /Users/mlbbr-mac-vinicius/projects/worldcup
git add Fixture2026App/Assets.xcassets/AppIcon-Portuguese.appiconset \
        Fixture2026App/Assets.xcassets/AppIconPreview-Portuguese.imageset \
        Fixture2026.xcodeproj/project.pbxproj \
        Fixture2026App/Models/AppIconOption.swift \
        Fixture2026AppTests/Models/AppIconOptionTests.swift \
        Fixture2026App/Resources/Localizable.xcstrings
git commit -m "$(cat <<'EOF'
Add the Portuguese app icon

Brasileirão and the Scottish Premiership each ship an alternate icon, so
enabling Liga Portugal without one would have left it the odd league out.
The picker is independent of the competition catalog, so this is additive.

Registered in ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES for both
configurations — the asset catalog alone is not enough, and without it
setAlternateIconName fails at runtime rather than at build time.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

Use exactly those paths with `git add`. Never `git add -A` in this repo — it has untracked files that must not be committed.

---

### Task 3: Verify on device, then push both commits

**Files:** none, unless something is wrong.

- [ ] **Step 1: Build and run**

Build the `Fixture2026` scheme on iPhone 17 Pro and launch it. Builds are pre-approved; run them in the foreground with a 600000 ms timeout.

Note for reaching screens: this sandbox has no working host display, so `screencapture` and `cliclick` are unreliable. Agents in this project have succeeded by adding a temporary XCUITest method to `Fixture2026UITests/SnapshotUITests.swift`, driving navigation with XCUITest taps, and capturing via `xcrun simctl io <udid> screenshot` or `XCTAttachment`. **Revert any temporary test file afterwards** and confirm with `git status`.

- [ ] **Step 2: Check the competition hub**

Confirm Liga Portugal's tile is at full opacity, has no lock badge, and is tappable. Confirm it opens to real data rather than an empty state — its accessibility identifier is `tile-PPL`.

If the current round is genuinely empty or between seasons, the screens will show their empty states. That is correct behaviour, not a bug — report which you saw rather than treating an empty state as a failure.

- [ ] **Step 3: Check the icon picker**

Open Settings and confirm four options appear (Stadium, Brazilian, Scottish, Portuguese), each with a distinct thumbnail. Select Portuguese and confirm it applies **without** the "Couldn't change the app icon" error — that error is the specific symptom of Step 4 of Task 2 having been missed.

- [ ] **Step 4: Capture and report**

Save screenshots of the hub and the icon picker. Report what you actually saw. Do not describe a screen you did not reach.

- [ ] **Step 5: Push both repos' work**

Only after Steps 2 and 3 pass:

```bash
cd /Users/mlbbr-mac-vinicius/projects/worldcup && git push origin main
```

Then confirm:

```bash
git status -sb | head -1
```

Expected: `## main...origin/main` with no `ahead` marker.

---

## Notes for the implementer

**Why enabling a competition is only a flag.** `isEnabled` is read in exactly three places, all in `CompetitionHubView`: whether the tile is wrapped in a `NavigationLink` (line 62), whether the lock badge renders (line 101), and the tile's opacity (line 115). Every league screen — Today, Fixtures, Standings, match detail — is competition-agnostic and already serves Brasileirão and the Scottish Premiership through the same code.

**Why the icon is a separate concern.** `AppIconOption` never reads `CompetitionCatalog`. Liga Portugal works fully without an icon; the icon exists so it is presented consistently with the other two leagues. They are shipped together at the user's explicit request, not because either depends on the other.

**The trap worth repeating:** `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` must list the new icon in both build configurations. Missing it is invisible at build time and fails only when a user taps the option.
