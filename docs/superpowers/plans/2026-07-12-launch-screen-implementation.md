# Launch Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a native iOS Launch Screen (solid `#061325` background, centered
white `soccerball` glyph) per
`docs/superpowers/specs/2026-07-12-launch-screen-design.md`, so the app no
longer falls back to a blank/default screen during cold launch.

**Architecture:** This project already has a physical, version-controlled
partial Info.plist at `Generated/BR2026-Info.plist` (merged at build time
with `INFOPLIST_KEY_*` build settings via `GENERATE_INFOPLIST_FILE = YES`).
It already contains an empty `UILaunchScreen` dict — populating it with
`UIColorName`/`UIImageName` keys pointing at two new Asset Catalog entries is
the entire mechanism; no storyboard, no build-setting guessing, no pbxproj
wiring (Asset Catalog sub-entries need no individual pbxproj references,
confirmed against the existing `AppIcon.appiconset`/`AppIconPreview-*`
entries, which work the same way under the single existing `Assets.xcassets`
folder reference).

**Tech Stack:** Xcode Asset Catalog (Color Set + Image Set), Info.plist,
Swift (a throwaway local script to rasterize the SF Symbol to PNG — not
committed, only its PNG output is).

## Global Constraints

- Background color is exactly `#061325` (the darkest stop of
  `StadiumBackground`'s existing gradient).
- Centered mark is the `soccerball` SF Symbol, rendered white, ~120pt
  (120x120 @1x / 240x240 @2x / 360x360 @3x).
- No animation, no loading logic, no per-championship theming — this is a
  static native Launch Screen only.
- Views aren't unit-tested per `CLAUDE.md` ("unit test ViewModels and
  Services — not Views"); verification is a build check plus a manual
  Simulator smoke test.

---

### Task 1: Add the Launch Screen assets and wire them into Info.plist

**Files:**
- Create: `BR2026/Resources/Assets.xcassets/LaunchBackground.colorset/Contents.json`
- Create: `BR2026/Resources/Assets.xcassets/LaunchLogo.imageset/Contents.json`
- Create: `BR2026/Resources/Assets.xcassets/LaunchLogo.imageset/LaunchLogo.png`
- Create: `BR2026/Resources/Assets.xcassets/LaunchLogo.imageset/LaunchLogo@2x.png`
- Create: `BR2026/Resources/Assets.xcassets/LaunchLogo.imageset/LaunchLogo@3x.png`
- Modify: `Generated/BR2026-Info.plist`

**Interfaces:** None — this task is self-contained (static assets + one
Info.plist edit), consumed only by the OS at launch, not by any Swift code.

- [ ] **Step 1: Create the `LaunchBackground` color set**

Run:
```bash
mkdir -p "BR2026/Resources/Assets.xcassets/LaunchBackground.colorset"
```

Create `BR2026/Resources/Assets.xcassets/LaunchBackground.colorset/Contents.json`:
```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0x25",
          "green" : "0x13",
          "red" : "0x06"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

(`0x06 0x13 0x25` is `#061325`, matching `StadiumBackground.swift`'s darkest
gradient stop exactly.)

- [ ] **Step 2: Generate the white `soccerball` PNG renditions**

Run this from the repo root — it writes a throwaway Swift script to `/tmp`,
runs it to rasterize the `soccerball` SF Symbol at 1x/2x/3x in white on a
transparent background, and copies the results into the asset catalog. The
script itself is not committed; only its PNG output is.

```bash
mkdir -p "BR2026/Resources/Assets.xcassets/LaunchLogo.imageset"

cat > /tmp/render_launch_logo.swift <<'EOF'
import AppKit

let pointSize: CGFloat = CGFloat(Double(CommandLine.arguments[1])!)
let scale: CGFloat = CGFloat(Double(CommandLine.arguments[2])!)
let outputPath = CommandLine.arguments[3]

let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
guard let symbol = NSImage(systemSymbolName: "soccerball", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) else {
    fatalError("could not load symbol")
}

let pixelSize = pointSize * scale
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(pixelSize),
    pixelsHigh: Int(pixelSize),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
rep.size = NSSize(width: pixelSize, height: pixelSize)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let rect = NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
symbol.isTemplate = true
if let ctx = NSGraphicsContext.current?.cgContext,
   let mask = symbol.cgImage(forProposedRect: nil, context: nil, hints: nil) {
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.clip(to: rect, mask: mask)
    ctx.fill(rect)
}
NSGraphicsContext.restoreGraphicsState()

let data = rep.representation(using: .png, properties: [:])!
try! data.write(to: URL(fileURLWithPath: outputPath))
print("wrote \(outputPath) (\(Int(pixelSize))x\(Int(pixelSize)))")
EOF

swift /tmp/render_launch_logo.swift 120 1 "BR2026/Resources/Assets.xcassets/LaunchLogo.imageset/LaunchLogo.png"
swift /tmp/render_launch_logo.swift 120 2 "BR2026/Resources/Assets.xcassets/LaunchLogo.imageset/LaunchLogo@2x.png"
swift /tmp/render_launch_logo.swift 120 3 "BR2026/Resources/Assets.xcassets/LaunchLogo.imageset/LaunchLogo@3x.png"
```

Expected output: three `wrote ... (NxN)` lines (`120x120`, `240x240`,
`360x360`), and three PNG files present in
`BR2026/Resources/Assets.xcassets/LaunchLogo.imageset/`.

- [ ] **Step 3: Create the `LaunchLogo` image set's `Contents.json`**

Create `BR2026/Resources/Assets.xcassets/LaunchLogo.imageset/Contents.json`:
```json
{
  "images" : [
    {
      "filename" : "LaunchLogo.png",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "filename" : "LaunchLogo@2x.png",
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "filename" : "LaunchLogo@3x.png",
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

- [ ] **Step 4: Populate the `UILaunchScreen` dict in `Generated/BR2026-Info.plist`**

In `Generated/BR2026-Info.plist`, replace:
```xml
	<key>UILaunchScreen</key>
	<dict/>
```
with:
```xml
	<key>UILaunchScreen</key>
	<dict>
		<key>UIColorName</key>
		<string>LaunchBackground</string>
		<key>UIImageName</key>
		<string>LaunchLogo</string>
	</dict>
```

- [ ] **Step 5: Build**

Run:
```bash
xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Verify the built Info.plist actually contains the populated dict**

A successful build doesn't guarantee the asset references resolved
correctly — verify directly:
```bash
plutil -extract UILaunchScreen xml1 -o - \
  "$(xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -showBuildSettings 2>/dev/null | awk -F' = ' '/ CONFIGURATION_BUILD_DIR /{print $2; exit}')/BR2026.app/Info.plist"
```
Expected output contains both `<key>UIColorName</key><string>LaunchBackground</string>`
and `<key>UIImageName</key><string>LaunchLogo</string>`.

- [ ] **Step 7: Manual Simulator smoke test**

Install and cold-launch the app on a booted Simulator (force-quit first if
already running, to get a genuine cold launch):
```bash
xcrun simctl install booted "$(xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -showBuildSettings 2>/dev/null | awk -F' = ' '/ CONFIGURATION_BUILD_DIR /{print $2; exit}')/BR2026.app"
xcrun simctl terminate booted com.vibrito.br2026 2>/dev/null
xcrun simctl launch booted com.vibrito.br2026
```
Immediately after launch (within ~1 second), capture a screenshot:
```bash
xcrun simctl io booted screenshot /tmp/launch-screen-check.png
```
Confirm visually: solid navy (`#061325`) background with a centered white
soccer ball, no white/blank flash, no placeholder text.

- [ ] **Step 8: Commit**

```bash
git add BR2026/Resources/Assets.xcassets/LaunchBackground.colorset BR2026/Resources/Assets.xcassets/LaunchLogo.imageset Generated/BR2026-Info.plist
git commit -m "Add native Launch Screen: solid stadium-navy background with centered soccerball mark"
```

---

## Final Verification

- [ ] Full Simulator build: `xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation build`
  Expected: `** BUILD SUCCEEDED **`.
- [ ] Full test suite: `export PATH="$HOME/.rbenv/shims:$PATH" && bundle exec fastlane test`
  Expected: all tests pass (this change touches no Swift code, so the count
  should be unchanged from before this plan).
