# Team Theme Color Contrast Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Guarantee every team theme's text color meets WCAG AA contrast (4.5:1) against the
two surfaces it's actually rendered on, automatically at runtime, replacing the app's current
all-manual/reactive per-team contrast fixes with a systematic backstop.

**Architecture:** A new, plain-Swift (`import Foundation` only — no `import SwiftUI`) WCAG
contrast-ratio utility, consumed by `ThemeTokens.themed(...)`'s existing single choke point
for resolving `textColor`. No View/Component changes — every one of the 12 files reading
`themeTokens.textColor` is protected automatically once `ThemeTokens` is fixed.

**Tech Stack:** Swift Testing (`@Test`), no new dependencies.

## Global Constraints

- Full spec: `docs/superpowers/specs/2026-07-17-team-theme-contrast-design.md`.
- WCAG AA threshold: contrast ratio >= 4.5 (applied uniformly, not split by font
  size/weight).
- The two reference backgrounds a candidate font color hex must pass against: the app's
  fixed darkest gradient stop (`061325`, matching `ThemeTokens.defaultGradientStops[2]`) and
  the team's own `mainColorHex`.
- On failure of either check, fall back to whichever of pure white (`FFFFFF`) or pure black
  (`000000`) scores higher on the *minimum* of its two contrast ratios (against the fixed
  background and against `mainColorHex`) — not the *average*; the minimum is what determines
  whether a candidate is safe against the worse of the two surfaces.
- This validation applies unconditionally inside `ThemeTokens.themed(...)` — to curated
  `fontColorOverrideHex` values and raw API `fontColorHex` values alike. No bypass, no
  exceptions.
- Known inherent limitation, not a defect to fix: if `mainColorHex` itself is very light
  (near-white), no candidate can pass both checks — white fails against the light main
  color, black fails against the fixed dark background — so the fallback picks whichever
  is *least bad*, not a guaranteed-passing color. This hasn't been an issue in practice
  because every team so far with a near-white/near-black brand color already gets a
  toned-down charcoal/gray substitute via `mainColorOverrideHex` specifically to avoid
  this (see `TeamThemeOption`'s doc comments on Corinthians/Santos/Atlético Mineiro). Do
  not try to "solve" this edge case as part of this plan — it's out of scope (background
  colors are explicitly excluded, per the design spec).
- Out of scope (do not touch): `overrideAccentColor`, `overrideTabSelectionColor`,
  `overridePillFillColor` (background-ish surface colors, not text); the app's fixed
  white-opacity design-system tiers; Dynamic Type.
- No `import SwiftUI` in `WCAGContrast.swift` — matches this codebase's convention that
  Model-layer code has no UI imports (CLAUDE.md's Architecture section).

---

### Task 1: `WCAGContrast` utility

**Files:**
- Create: `BR2026/Models/WCAGContrast.swift`
- Create: `BR2026Tests/Models/WCAGContrastTests.swift`

**Interfaces:**
- Produces: `WCAGContrast.relativeLuminance(hex: String) -> Double` and
  `WCAGContrast.contrastRatio(_ hex1: String, _ hex2: String) -> Double` — Task 2 consumes
  `contrastRatio`.

- [ ] **Step 1: Write the failing tests**

```swift
// BR2026Tests/Models/WCAGContrastTests.swift
import Testing
@testable import BR2026

@Suite("WCAGContrast")
struct WCAGContrastTests {
    @Test("Pure black vs. pure white is the maximum possible contrast ratio, 21:1")
    func blackWhiteIsMaximumContrast() {
        let ratio = WCAGContrast.contrastRatio("000000", "FFFFFF")
        #expect(abs(ratio - 21.0) < 0.01)
    }

    @Test("Identical colors have the minimum possible contrast ratio, 1:1")
    func identicalColorsAreMinimumContrast() {
        #expect(abs(WCAGContrast.contrastRatio("2B2B2E", "2B2B2E") - 1.0) < 0.01)
        #expect(abs(WCAGContrast.contrastRatio("FFFFFF", "FFFFFF") - 1.0) < 0.01)
    }

    @Test("contrastRatio is symmetric regardless of argument order")
    func contrastRatioIsSymmetric() {
        let a = WCAGContrast.contrastRatio("061325", "F2F2F2")
        let b = WCAGContrast.contrastRatio("F2F2F2", "061325")
        #expect(abs(a - b) < 0.0001)
    }

    @Test("Off-white F2F2F2 against the app's fixed dark background passes WCAG AA (>= 4.5)")
    func offWhiteAgainstFixedDarkBackgroundPasses() {
        #expect(WCAGContrast.contrastRatio("F2F2F2", "061325") >= 4.5)
    }

    @Test("Pure black against the app's fixed dark background fails WCAG AA — this is the exact bug Corinthians' original API font color (000000) would have shipped with")
    func blackAgainstFixedDarkBackgroundFails() {
        #expect(WCAGContrast.contrastRatio("000000", "061325") < 4.5)
    }

    @Test("relativeLuminance of pure black is 0 and pure white is 1")
    func relativeLuminanceOfBlackAndWhite() {
        #expect(abs(WCAGContrast.relativeLuminance(hex: "000000") - 0.0) < 0.0001)
        #expect(abs(WCAGContrast.relativeLuminance(hex: "FFFFFF") - 1.0) < 0.0001)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: FAIL to build — `Cannot find 'WCAGContrast' in scope`.

- [ ] **Step 3: Write the implementation**

```swift
// BR2026/Models/WCAGContrast.swift
import Foundation

/// WCAG 2.x contrast-ratio math. Plain Swift, no UI dependency, so it's independently
/// testable and reusable from both View-layer color pickers and Model-layer validation
/// (see `ThemeTokens.accessibleFontColorHex(candidateHex:mainColorHex:)`).
enum WCAGContrast {
    /// WCAG 2.x relative luminance: gamma-corrects each sRGB channel, then applies the
    /// standard perceptual weights (0.2126 R, 0.7152 G, 0.0722 B). Returns a value in
    /// [0, 1], where 0 is pure black and 1 is pure white.
    static func relativeLuminance(hex: String) -> Double {
        let (red, green, blue) = rgbComponents(hex: hex)
        return 0.2126 * linearize(red) + 0.7152 * linearize(green) + 0.0722 * linearize(blue)
    }

    /// WCAG 2.x contrast ratio between two colors: `(L1 + 0.05) / (L2 + 0.05)`, where `L1`
    /// is the lighter of the two relative luminances. Always >= 1.0 (identical colors);
    /// WCAG AA requires >= 4.5 for normal text.
    static func contrastRatio(_ hex1: String, _ hex2: String) -> Double {
        let l1 = relativeLuminance(hex: hex1)
        let l2 = relativeLuminance(hex: hex2)
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func linearize(_ channel: Double) -> Double {
        channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }

    // Deliberately not shared with `Color+Hex.swift`'s identical-shaped private helper:
    // that one lives on a `Color` extension (`import SwiftUI`), and this file must stay
    // UI-import-free per this codebase's Model-layer convention. The duplication is a
    // handful of lines of hex parsing.
    private static func rgbComponents(hex: String) -> (red: Double, green: Double, blue: Double) {
        let hexValue = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var rgb: UInt64 = 0
        Scanner(string: hexValue).scanHexInt64(&rgb)
        return (
            Double((rgb & 0xFF0000) >> 16) / 255,
            Double((rgb & 0x00FF00) >> 8) / 255,
            Double(rgb & 0x0000FF) / 255
        )
    }
}
```

- [ ] **Step 4: Register the new files in the Xcode project**

Both `WCAGContrast.swift` (main app target) and `WCAGContrastTests.swift` (test target) are
brand-new files — both must be added to `project.pbxproj` in this same step (this project's
established convention — a skipped registration step has silently left a whole test file
never running before):

```bash
eval "$(rbenv init -)"
bundle exec ruby -e '
require "xcodeproj"
project = Xcodeproj::Project.open("BR2026.xcodeproj")

main_group = project.main_group.find_subpath("BR2026/Models", false)
raise "BR2026/Models group not found" unless main_group
main_ref = main_group.new_reference("WCAGContrast.swift")
main_target = project.targets.find { |t| t.name == "BR2026" } or raise "no BR2026 target"
main_target.source_build_phase.add_file_reference(main_ref)

test_group = project.main_group.find_subpath("BR2026Tests/Models", false)
raise "BR2026Tests/Models group not found" unless test_group
test_ref = test_group.new_reference("WCAGContrastTests.swift")
test_target = project.targets.find { |t| t.name == "BR2026Tests" } or raise "no BR2026Tests target"
test_target.source_build_phase.add_file_reference(test_ref)

project.save
puts "Registered WCAGContrast.swift and WCAGContrastTests.swift"
'
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `rm -rf ~/Library/Developer/Xcode/DerivedData/BR2026-* && eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: all tests pass, including the 6 new ones. Confirm with a fully clean build first
(not incremental).

- [ ] **Step 6: Commit**

```bash
git add BR2026/Models/WCAGContrast.swift BR2026Tests/Models/WCAGContrastTests.swift BR2026.xcodeproj/project.pbxproj
git commit -m "Add WCAGContrast utility for WCAG AA contrast-ratio math"
```

---

### Task 2: Validate and auto-correct team theme text color in `ThemeTokens.themed(...)`

**Files:**
- Modify: `BR2026/Models/ThemeTokens.swift`
- Modify: `BR2026Tests/Models/ThemeTokensTests.swift`

**Interfaces:**
- Consumes: `WCAGContrast.contrastRatio(_:_:)` from Task 1.
- Produces: `ThemeTokens.accessibleFontColorHex(candidateHex: String, mainColorHex: String)
  -> String` — a `static` function on `ThemeTokens`, directly unit-testable, and used
  internally by `themed(...)`. No other public signature changes — `themed(...)`'s existing
  parameter list and return type are unchanged; this task only changes what `textColor`
  resolves to internally.

- [ ] **Step 1: Write the failing tests**

Add to `BR2026Tests/Models/ThemeTokensTests.swift`, inside `@Suite("ThemeTokens") struct
ThemeTokensTests`, after the existing tests:

```swift
    @Test("accessibleFontColorHex returns the candidate unchanged when it passes both contrast checks")
    func accessibleFontColorHexPassesThrough() {
        // F2F2F2 (off-white) against a dark charcoal main color and the fixed dark
        // background both pass WCAG AA comfortably.
        let result = ThemeTokens.accessibleFontColorHex(candidateHex: "F2F2F2", mainColorHex: "2B2B2E")
        #expect(result == "F2F2F2")
    }

    @Test("accessibleFontColorHex replaces a candidate that fails against the fixed dark background — the exact bug Corinthians' original API font color (000000) would have shipped with")
    func accessibleFontColorHexCatchesFixedBackgroundFailure() {
        // 000000 (pure black) fails against 061325 (the fixed dark background) and also
        // fails against a realistic dark main color like 2B2B2E (Atlético Mineiro's
        // charcoal) — this regresses the historical bug. (A near-white mainColorHex here
        // would be a pathological edge case — see the plan's note on this — so this test
        // deliberately uses a realistic dark team color instead.)
        let result = ThemeTokens.accessibleFontColorHex(candidateHex: "000000", mainColorHex: "2B2B2E")
        #expect(result != "000000")
        #expect(result == "FFFFFF")
    }

    @Test("accessibleFontColorHex replaces a candidate that fails against the team's own main color — the exact bug LiveChip's contrast fix addressed")
    func accessibleFontColorHexCatchesMainColorFailure() {
        // A candidate identical to the main color always fails that check (1:1 ratio),
        // regardless of how well it does against the fixed background.
        let result = ThemeTokens.accessibleFontColorHex(candidateHex: "2B2B2E", mainColorHex: "2B2B2E")
        #expect(result != "2B2B2E")
    }

    @Test("accessibleFontColorHex's fallback is always at least white or black, never a color that still fails")
    func accessibleFontColorHexFallbackIsAlwaysWhiteOrBlack() {
        let result = ThemeTokens.accessibleFontColorHex(candidateHex: "808080", mainColorHex: "707070")
        #expect(result == "FFFFFF" || result == "000000")
    }

    @Test("themed(mainColorHex:fontColorHex:) applies the same validation, replacing an unsafe font color automatically")
    func themedFactoryValidatesFontColor() {
        // 000000 against the fixed dark background (061325) fails, so themed(...) must not
        // pass it through as textColor even though it's the literal fontColorHex argument.
        let tokens = ThemeTokens.themed(mainColorHex: "F2F2F2", fontColorHex: "000000")
        #expect(tokens.textColor != Color(hex: "000000"))
    }

    @Test("themed(mainColorHex:fontColorHex:) leaves an already-safe font color unchanged")
    func themedFactoryPassesThroughSafeFontColor() {
        // Matches the existing themedFactoryBuildsActiveTokens test's inputs — confirms
        // this task doesn't change behavior for colors that already pass.
        let tokens = ThemeTokens.themed(mainColorHex: "225638", fontColorHex: "ffffff")
        #expect(tokens.textColor == Color(hex: "ffffff"))
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: FAIL to build — `Value of type 'ThemeTokens.Type' has no member 'accessibleFontColorHex'`.

- [ ] **Step 3: Write the implementation**

In `BR2026/Models/ThemeTokens.swift`, find:

```swift
    static func themed(
        mainColorHex: String,
        fontColorHex: String,
        tabSelectionColorHex: String? = nil,
        pillFillColorHex: String? = nil,
        gradientDarkAmount: Double = -0.75,
        usesDiagonalSashBackground: Bool = false
    ) -> ThemeTokens {
        let accent = Color(hex: mainColorHex)
        return ThemeTokens(
            overrideAccentColor: accent,
            overrideTabSelectionColor: tabSelectionColorHex.map { Color(hex: $0) },
            overridePillFillColor: pillFillColorHex.map { Color(hex: $0) },
            usesDiagonalSashBackground: usesDiagonalSashBackground,
            textColor: Color(hex: fontColorHex),
            gradientStops: [
                Color.shaded(hex: mainColorHex, towardWhite: 0.35),
                accent,
                Color.shaded(hex: mainColorHex, towardWhite: gradientDarkAmount)
            ],
            blobColors: (top: accent, bottom: accent)
        )
    }
}
```

Replace with:

```swift
    static func themed(
        mainColorHex: String,
        fontColorHex: String,
        tabSelectionColorHex: String? = nil,
        pillFillColorHex: String? = nil,
        gradientDarkAmount: Double = -0.75,
        usesDiagonalSashBackground: Bool = false
    ) -> ThemeTokens {
        let accent = Color(hex: mainColorHex)
        let resolvedFontColorHex = accessibleFontColorHex(candidateHex: fontColorHex, mainColorHex: mainColorHex)
        return ThemeTokens(
            overrideAccentColor: accent,
            overrideTabSelectionColor: tabSelectionColorHex.map { Color(hex: $0) },
            overridePillFillColor: pillFillColorHex.map { Color(hex: $0) },
            usesDiagonalSashBackground: usesDiagonalSashBackground,
            textColor: Color(hex: resolvedFontColorHex),
            gradientStops: [
                Color.shaded(hex: mainColorHex, towardWhite: 0.35),
                accent,
                Color.shaded(hex: mainColorHex, towardWhite: gradientDarkAmount)
            ],
            blobColors: (top: accent, bottom: accent)
        )
    }

    /// The app's fixed darkest background stop (see `defaultGradientStops`) — one of two
    /// reference surfaces a team's font color must contrast against.
    private static let fixedDarkBackgroundHex = "061325"

    /// WCAG AA's minimum contrast ratio for normal text.
    private static let minimumContrastRatio = 4.5

    /// Validates `candidateHex` against both the app's fixed dark background and the
    /// team's own main color — the two failure patterns behind every contrast bug found in
    /// this app so far (see `TeamThemeOption`'s doc-comment history: Atlético Mineiro's tab
    /// bar legibility, LiveChip's self-referential chip contrast). If either check fails,
    /// returns whichever of pure white or pure black scores higher on the *minimum* of its
    /// two contrast ratios — the candidate that's least-bad against both surfaces at once.
    /// Otherwise returns `candidateHex` unchanged. Applied unconditionally: curated
    /// overrides and raw API values are validated identically, with no bypass.
    static func accessibleFontColorHex(candidateHex: String, mainColorHex: String) -> String {
        let passesBackground = WCAGContrast.contrastRatio(candidateHex, fixedDarkBackgroundHex) >= minimumContrastRatio
        let passesMainColor = WCAGContrast.contrastRatio(candidateHex, mainColorHex) >= minimumContrastRatio
        guard passesBackground, passesMainColor else {
            let whiteMinRatio = min(
                WCAGContrast.contrastRatio("FFFFFF", fixedDarkBackgroundHex),
                WCAGContrast.contrastRatio("FFFFFF", mainColorHex)
            )
            let blackMinRatio = min(
                WCAGContrast.contrastRatio("000000", fixedDarkBackgroundHex),
                WCAGContrast.contrastRatio("000000", mainColorHex)
            )
            return whiteMinRatio >= blackMinRatio ? "FFFFFF" : "000000"
        }
        return candidateHex
    }
}
```

(Note: only the closing `}` after `themed(...)`'s original body moves to after the two new
members — the struct's own closing `}` stays where it was, now after
`accessibleFontColorHex`.)

- [ ] **Step 4: Run the tests to verify they pass**

Run: `rm -rf ~/Library/Developer/Xcode/DerivedData/BR2026-* && eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: all tests pass, including the 6 new ones and all pre-existing `ThemeTokensTests`
(none of the existing tests' `fontColorHex` inputs are affected — they all use `"ffffff"`
against sufficiently dark `mainColorHex` values, which passes both checks unchanged; verify
this is actually true in the output rather than assuming it).

- [ ] **Step 5: Commit**

```bash
git add BR2026/Models/ThemeTokens.swift BR2026Tests/Models/ThemeTokensTests.swift
git commit -m "Validate and auto-correct team theme text color for WCAG AA contrast"
```

---
