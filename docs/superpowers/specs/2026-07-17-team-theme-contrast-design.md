# Team Theme Color Contrast — Design Spec

## Goal

Guarantee every team theme's text/icon color (`fontColorHex`, exposed as
`ThemeTokens.textColor`) meets WCAG AA contrast (4.5:1) against the surfaces it's actually
rendered on, automatically and at runtime — closing a real, currently-unguarded gap rather
than continuing the app's established pattern of reactive, per-team hand fixes.

This is the second of three remaining items in the "Accessibility" roadmap phase (sequence:
Reduced Motion → Contrast → Dynamic Type). Reduced Motion shipped 2026-07-17.

## Background

`BR2026/Models/TeamThemeOption.swift` defines 20 team themes. Each resolves a `mainColorHex`
and `fontColorHex` — either a curated override in the catalog, or (when no override exists)
whatever `BR2026/Services/TeamThemeStore.swift` fetches live from the API
(`GET v4/competitions/{code}/teams/{id}/colors`). `ThemeTokens.themed(...)`
(`BR2026/Models/ThemeTokens.swift:52-74`) turns these into `overrideAccentColor` (from
`mainColorHex`) and `textColor` (from `fontColorHex`, a **direct hex passthrough with no
validation of any kind**). `textColor` is then read by 12 different View/Component files as
the theme-reactive foreground color for team names, scores, chip text, and icons.

There is no WCAG/contrast-ratio computation anywhere in this codebase. Every contrast problem
found so far was caught by a human looking at a screenshot and hand-picking a replacement hex
into `TeamThemeOption`'s override tables — documented in that file's doc comments:

- **Atlético Mineiro**: charcoal main color read as "nearly invisible" against the tab bar's
  fixed dark glass chrome → `tabSelectionColorOverrideHex` hardcoded to white, which then
  broke the round-pill fill (white text on now-white pill) → a *third* override
  (`pillFillColorOverrideHex`) had to be added just to fix the fix.
- **Mirassol**: API main color (~93% luminance yellow) manually darkened twice because it
  "risked washing out the gradient's top-anchored light source."
- **Black/white-kit clubs** (Atlético Mineiro, Botafogo, Vasco, Corinthians, Santos): literal
  `#000000`/near-white API values "disappear into this app's already-dark background," each
  given a hand-picked charcoal/gray substitute.
- **`LiveChip`**: `chipColor` swaps to `themeTokens.textColor` instead of `Color.accentColor`
  when a theme is active, because an accent-colored chip on the team's own accent-derived
  background "can collapse to near-invisible for saturated team colors."

Every one of these was found visually, after shipping, and fixed by hardcoding a new hex for
one specific team. Nothing prevents the *next* team (or a live API change to any of the 13
teams with no `mainColorOverrideHex`, or the 13 teams with no `fontColorOverrideHex`) from
shipping the same class of bug silently.

## Design

### WCAG contrast math (plain Swift, no UI dependency)

New file, plain Swift with no `import SwiftUI` — matching this codebase's convention that
Model-layer code has no UI imports (CLAUDE.md's Architecture section): given two hex color
strings, compute their WCAG 2.x contrast ratio.

```swift
enum WCAGContrast {
    /// Relative luminance per WCAG 2.x: gamma-corrects each sRGB channel, then weights
    /// them (0.2126 R, 0.7152 G, 0.0722 B).
    static func relativeLuminance(hex: String) -> Double { ... }

    /// (L1 + 0.05) / (L2 + 0.05), where L1 is the lighter of the two relative luminances.
    /// Always >= 1.0; WCAG AA requires >= 4.5 for normal text.
    static func contrastRatio(_ hex1: String, _ hex2: String) -> Double { ... }
}
```

### Two-background validation, applied uniformly

`ThemeTokens.themed(...)` is the single point where `fontColorHex` becomes `textColor` today.
Add a validation step there, applied to **every** team the same way — curated overrides
included, not just raw API values:

1. Compute `contrastRatio(fontColorHex, "061325")` — against the app's fixed darkest
   background stop (CLAUDE.md's gradient: `#173a68 → #0b2143 → #061325`). Catches the
   Atlético Mineiro-style "color nearly invisible against fixed dark chrome" pattern.
2. Compute `contrastRatio(fontColorHex, pillFillColorHex ?? tabSelectionColorHex ?? mainColorHex)`
   — against whichever color the round pill's fill *actually* resolves to for this team,
   matching the exact fallback chain `ThemeTokens`/`FixturesView` already use for that fill.
   `textColor` is drawn directly on top of that surface (`FixturesView`'s round pill,
   `LiveChip`'s capsule). Catches the LiveChip/round-pill-style "theme color drawn on
   itself" pattern — checking against raw `mainColorHex` unconditionally was tried first
   and rejected: several teams (Corinthians, Santos) override the pill's fill away from
   `mainColorHex` via `pillFillColorOverrideHex`, so validating against the un-overridden
   main color checks a surface that never actually renders, producing false positives
   (Santos: `F2F2F2` scores only 3.44:1 against raw `mainColorHex` `82827F`, but 18.76:1
   against the pill's real, overridden fill `000000`).
3. If **either** check is below 4.5:1, `fontColorHex` is rejected. Pick whichever of pure
   white (`FFFFFF`) or pure black (`000000`) scores the higher *minimum* of the two contrast
   ratios (i.e., the candidate that's safest against both backgrounds at once), and use that
   as `textColor` instead of the rejected value.
4. If both checks pass, `fontColorHex` is used as-is — no behavior change for teams whose
   colors already work.

Because this runs unconditionally inside `themed(...)`, it applies with no exceptions: a
curated `fontColorOverrideHex` that happens to still fail on a surface its original human
curator didn't consider gets caught and corrected automatically, the same as a live
API-supplied value would be. No per-team hardcoding is required for this failure mode again —
for new teams or API changes, the worst case becomes "readable but not the brand's exact
color," never "invisible."

### What this does NOT change

- `overrideAccentColor`, `overrideTabSelectionColor`, `overridePillFillColor` (all
  *background*-ish surface colors, not text) are untouched — this spec is scoped to the one
  color that's read as a foreground/text/icon value app-wide (`textColor`/`fontColorHex`).
- The app's fixed white-opacity design-system tiers (white@0.40 through @1.0, over the fixed
  gradient) are out of scope — deliberately deferred, per the earlier scoping decision, since
  a runtime safety net has no value against colors that are already compile-time constants.
- Existing `TeamThemeOption` override fields and their doc-comment history are left in place
  as-is — they're not being removed or "cleaned up," just backstopped.

## Testing

Unlike Reduced Motion, this has real testable logic with no SwiftUI dependency — belongs in
`BR2026Tests/Models/` per this project's convention (CLAUDE.md: "Unit test ViewModels and
Services — not Views"; `WCAGContrast` and the `themed(...)` validation logic are Model-layer).

- `relativeLuminance`/`contrastRatio` against known WCAG-verified reference pairs (e.g. pure
  black vs. pure white = 21:1, a documented industry-standard sanity check).
- The specific historical failure cases as regression tests: Atlético Mineiro's charcoal main
  color, Mirassol's original ~93%-luminance yellow — confirm each is correctly flagged as
  failing, and that a passing color (e.g. an existing correctly-curated `fontColorOverrideHex`
  like `F2F2F2`) is correctly accepted unchanged.
- `ThemeTokens.themed(...)`'s fallback selection: a `fontColorHex` that fails against the
  fixed background but passes against `mainColorHex` (and vice versa) is still rejected
  (either-check-fails rule); the resulting fallback is whichever of white/black wins the
  *minimum* of the two ratios.

## Out of Scope

- Color contrast for the app's fixed (non-team-themed) design system — a separate,
  deliberately-deferred concern (see "What this does NOT change" above).
- Dynamic Type — the third and final item in this accessibility phase, not yet started.
- Retroactively re-auditing/removing the existing hand-picked `TeamThemeOption` overrides —
  they remain as documentation of past decisions and continue to take precedence when
  present; this spec only adds a backstop for when they're absent or still insufficient.
