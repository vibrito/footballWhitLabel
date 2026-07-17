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
  the round pill's *actual resolved* fill color — `pillFillColorHex ?? tabSelectionColorHex
  ?? mainColorHex`, the same fallback chain `FixturesView`'s round pill already uses. **Not**
  raw `mainColorHex` unconditionally — that was the original design and was corrected after
  implementation revealed it produces false positives: Corinthians and Santos both override
  the pill's fill via `pillFillColorOverrideHex` (to `000000`), so their `fontColorHex`
  never actually renders against raw `mainColorHex` at all. Checking the wrong surface
  flagged Santos's real, working colors (`F2F2F2` on pill fill `000000` = 18.76:1, safe) as
  failing (`F2F2F2` on raw `mainColorHex` `82827F` = 3.44:1) — a false positive from
  validating a color combination that never renders on screen.
- On failure of either check, fall back to whichever of pure white (`FFFFFF`) or pure black
  (`000000`) scores higher on the *minimum* of its two contrast ratios (against the fixed
  background and against the resolved pill-fill color) — not the *average*; the minimum is
  what determines whether a candidate is safe against the worse of the two surfaces.
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
- Produces: `ThemeTokens.accessibleFontColorHex(candidateHex: String, secondaryBackgroundHex:
  String) -> String` — a `static` function on `ThemeTokens`, directly unit-testable, and used
  internally by `themed(...)`, which resolves `secondaryBackgroundHex` to `pillFillColorHex
  ?? tabSelectionColorHex ?? mainColorHex` before calling it (the same fallback chain the
  round pill's fill already uses). No other public signature changes — `themed(...)`'s
  existing parameter list and return type are unchanged; this task only changes what
  `textColor` resolves to internally.

- [ ] **Step 1: Write the failing tests**

Add to `BR2026Tests/Models/ThemeTokensTests.swift`, inside `@Suite("ThemeTokens") struct
ThemeTokensTests`, after the existing tests:

```swift
    @Test("accessibleFontColorHex returns the candidate unchanged when it passes both contrast checks")
    func accessibleFontColorHexPassesThrough() {
        // F2F2F2 (off-white) against a dark charcoal secondary background and the fixed
        // dark background both pass WCAG AA comfortably.
        let result = ThemeTokens.accessibleFontColorHex(candidateHex: "F2F2F2", secondaryBackgroundHex: "2B2B2E")
        #expect(result == "F2F2F2")
    }

    @Test("accessibleFontColorHex replaces a candidate that fails against the fixed dark background — the exact bug Corinthians' original API font color (000000) would have shipped with")
    func accessibleFontColorHexCatchesFixedBackgroundFailure() {
        // 000000 (pure black) fails against 061325 (the fixed dark background) and also
        // fails against a realistic dark secondary background like 2B2B2E (Atlético
        // Mineiro's charcoal) — this regresses the historical bug. (A near-white secondary
        // background here would be a pathological edge case — see the plan's note on this
        // — so this test deliberately uses a realistic dark team color instead.)
        let result = ThemeTokens.accessibleFontColorHex(candidateHex: "000000", secondaryBackgroundHex: "2B2B2E")
        #expect(result != "000000")
        #expect(result == "FFFFFF")
    }

    @Test("accessibleFontColorHex replaces a candidate that fails against its own secondary background — the exact bug LiveChip's contrast fix addressed")
    func accessibleFontColorHexCatchesSecondaryBackgroundFailure() {
        // A candidate identical to the secondary background always fails that check (1:1
        // ratio), regardless of how well it does against the fixed background.
        let result = ThemeTokens.accessibleFontColorHex(candidateHex: "2B2B2E", secondaryBackgroundHex: "2B2B2E")
        #expect(result != "2B2B2E")
    }

    @Test("accessibleFontColorHex's fallback is always white or black, never a color that still fails")
    func accessibleFontColorHexFallbackIsAlwaysWhiteOrBlack() {
        let result = ThemeTokens.accessibleFontColorHex(candidateHex: "808080", secondaryBackgroundHex: "707070")
        #expect(result == "FFFFFF" || result == "000000")
    }

    @Test("themed(...) resolves the secondary background via pillFillColorHex when present, not raw mainColorHex — this is the exact false positive that broke Santos's real, working colors when the check first used raw mainColorHex unconditionally")
    func themedFactoryResolvesSecondaryBackgroundViaPillFillOverride() {
        // Santos's real curated values: mainColorOverrideHex 82827F, fontColorOverrideHex
        // F2F2F2, pillFillColorOverrideHex 000000. F2F2F2 only scores 3.44:1 against raw
        // 82827F (would incorrectly fail), but the pill's fill never actually renders as
        // raw mainColorHex when pillFillColorHex is set — it renders as 000000, against
        // which F2F2F2 scores a very safe 18.76:1. themed(...) must check the surface that
        // actually renders, so F2F2F2 must pass through unchanged here.
        let tokens = ThemeTokens.themed(
            mainColorHex: "82827F",
            fontColorHex: "F2F2F2",
            pillFillColorHex: "000000"
        )
        #expect(tokens.textColor == Color(hex: "F2F2F2"))
    }

    @Test("themed(...) falls back to raw mainColorHex for the secondary-background check when no pillFillColorHex/tabSelectionColorHex override exists, and still replaces an unsafe font color in that case")
    func themedFactoryFallsBackToMainColorWhenNoOverride() {
        // Same fontColorHex/mainColorHex pair as Santos, but with no pillFillColorHex this
        // time — the secondary-background check has nothing but raw mainColorHex (82827F)
        // to fall back to, F2F2F2 fails that (3.44:1 < 4.5), so it must be replaced.
        let tokens = ThemeTokens.themed(mainColorHex: "82827F", fontColorHex: "F2F2F2")
        #expect(tokens.textColor != Color(hex: "F2F2F2"))
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
        // The same fallback chain the round pill's fill already resolves to (see
        // `FixturesView.roundPill`'s `overridePillFillColor ?? overrideTabSelectionColor ??
        // Color.accentColor`) — checking raw mainColorHex unconditionally here would
        // validate a surface that never actually renders whenever a team overrides the
        // pill fill away from its main color (e.g. Corinthians/Santos both override it to
        // black), producing false positives.
        let secondaryBackgroundHex = pillFillColorHex ?? tabSelectionColorHex ?? mainColorHex
        let resolvedFontColorHex = accessibleFontColorHex(candidateHex: fontColorHex, secondaryBackgroundHex: secondaryBackgroundHex)
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

    /// Validates `candidateHex` against both the app's fixed dark background and a second
    /// surface it's actually drawn on top of elsewhere (the round pill's fill, LiveChip's
    /// capsule) — the two failure patterns behind every contrast bug found in this app so
    /// far (see `TeamThemeOption`'s doc-comment history: Atlético Mineiro's tab bar
    /// legibility, LiveChip's self-referential chip contrast). If either check fails,
    /// returns whichever of pure white or pure black scores higher on the *minimum* of its
    /// two contrast ratios — the candidate that's least-bad against both surfaces at once.
    /// Otherwise returns `candidateHex` unchanged. Applied unconditionally: curated
    /// overrides and raw API values are validated identically, with no bypass.
    static func accessibleFontColorHex(candidateHex: String, secondaryBackgroundHex: String) -> String {
        let passesBackground = WCAGContrast.contrastRatio(candidateHex, fixedDarkBackgroundHex) >= minimumContrastRatio
        let passesSecondary = WCAGContrast.contrastRatio(candidateHex, secondaryBackgroundHex) >= minimumContrastRatio
        guard passesBackground, passesSecondary else {
            let whiteMinRatio = min(
                WCAGContrast.contrastRatio("FFFFFF", fixedDarkBackgroundHex),
                WCAGContrast.contrastRatio("FFFFFF", secondaryBackgroundHex)
            )
            let blackMinRatio = min(
                WCAGContrast.contrastRatio("000000", fixedDarkBackgroundHex),
                WCAGContrast.contrastRatio("000000", secondaryBackgroundHex)
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

- [ ] **Step 4: Run the tests to verify they pass — and confirm the ONE expected pre-existing failure**

Run: `rm -rf ~/Library/Developer/Xcode/DerivedData/BR2026-* && eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`

Expected: the 7 new `ThemeTokensTests` pass, all pre-existing `ThemeTokensTests` pass (none
of their `fontColorHex` inputs are affected — they all use `"ffffff"` against sufficiently
dark `mainColorHex` values, which passes both checks unchanged; verify this is actually true
in the output rather than assuming it), and exactly ONE pre-existing test elsewhere in the
suite fails: `TeamThemeStoreTests.selectUsesBahiaColorOverrides` — this is expected and
fixed in Step 4b below, not a sign of a bug in your implementation.

Also confirm `TeamThemeStoreTests.selectUsesSantosColorOverrides` (NOT in this task's file
list, must NOT need modification) passes as-is — it asserts `store.tokens.textColor ==
Color(hex: "F2F2F2")` for Santos's real curated values (`mainColorOverrideHex: "82827F"`,
`fontColorOverrideHex: "F2F2F2"`, `pillFillColorOverrideHex: "000000"`), and
`TeamThemeStore.select(_:)` already passes `pillFillColorHex:
option.pillFillColorOverrideHex` through to `themed(...)` — so with the secondary-background
chain resolving to `"000000"` (not raw `mainColorHex` `"82827F"`), `F2F2F2` passes through
unchanged. If Santos fails, or if any test OTHER than Bahia fails, that's a signal something
diverged from the plan — stop and report rather than editing tests to match.

- [ ] **Step 4b: Fix the one real, second contrast bug this task's validation correctly finds — Bahia**

Full audit (all 20 teams, done by hand with a Python reference implementation of the exact
WCAG formula, before this step was written) confirms exactly ONE team's currently-shipped,
pre-existing test breaks under the corrected (resolved-chain) validation: **Bahia**.
Everything else either passes cleanly or resolves to the *same* value it already had via the
fallback path (e.g. Vitória and Grêmio's white API font color scores just under 4.5 against
their main color but the fallback still lands on white, since white remains the best
available option — no test changes needed for those).

Bahia's real curated values: `mainColorOverrideHex: "006CB5"`, `fontColorOverrideHex:
"F2F2F2"`, `tabSelectionColorOverrideHex: "ED3237"`, no `pillFillColorOverrideHex`. The
secondary background resolves to `tabSelectionColorHex` (`"ED3237"`, a red) since there's no
pill-fill override — this is the exact surface the round pill's fill actually renders as for
Bahia (per `overridePillFillColor ?? overrideTabSelectionColor ?? Color.accentColor`).
`F2F2F2` only scores 3.67:1 against `ED3237` — a real, previously-uncaught contrast gap
(nobody had a systematic check before this task), the same class of bug as every other
historical fix in `TeamThemeOption`'s doc comments, just never noticed for this specific
team/surface pairing. The corrected fallback resolves to `FFFFFF` (white scores better than
black across both reference surfaces here, even though it doesn't fully clear 4.5 against
`ED3237` either — 4.11:1 — matching this plan's documented "known inherent limitation":
white is still the least-bad available choice).

Update `BR2026Tests/Services/TeamThemeStoreTests.swift`'s `selectUsesBahiaColorOverrides`
test (found via `grep -n "selectUsesBahiaColorOverrides" -A 20`) — change its
`store.tokens.textColor` assertion from `Color(hex: "F2F2F2")` to `Color(hex: "FFFFFF")`,
and add a one-line comment noting this value changed because the new contrast validation
(this plan) found Bahia's original curated font color didn't actually clear WCAG AA against
its own tab-selection-color-derived pill fill. This is the ONLY pre-existing test anywhere in
the codebase that needs updating — do not touch any other test file. If your own test run
surfaces a DIFFERENT pre-existing test failure beyond Bahia, stop and report rather than
guessing at a fix — that would mean this audit missed something and needs to be redone with
fresh eyes, not patched over.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `rm -rf ~/Library/Developer/Xcode/DerivedData/BR2026-* && eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: all tests pass — the 7 new `ThemeTokensTests`, all pre-existing `ThemeTokensTests`,
the corrected `selectUsesBahiaColorOverrides`, `selectUsesSantosColorOverrides` (confirm this
one explicitly by test name in the output — it must pass unmodified), and every other
pre-existing `TeamThemeStoreTests` test unmodified and passing.

- [ ] **Step 6: Commit**

```bash
git add BR2026/Models/ThemeTokens.swift BR2026Tests/Models/ThemeTokensTests.swift BR2026Tests/Services/TeamThemeStoreTests.swift
git commit -m "Validate and auto-correct team theme text color for WCAG AA contrast"
```

---
