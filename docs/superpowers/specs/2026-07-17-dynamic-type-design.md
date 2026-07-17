# Dynamic Type Support — Design Spec

## Goal

Make every piece of text in the app respond to the system Dynamic Type setting (Settings →
Accessibility → Display & Text Size → Larger Text), while preserving the app's existing
pixel-precise design language (CLAUDE.md's Typography table) as the *default* appearance at
the standard content size category.

This is the third and final item in the "Accessibility" roadmap phase (sequence: Reduced
Motion → Contrast → Dynamic Type). Reduced Motion and Contrast both shipped 2026-07-17.

## Background

A full-codebase audit found:
- 57 call sites using `.font(.system(size: <literal>))` across 15 files (`Views/` and
  `Components/`) — 100% of all font usage in the app.
- Zero usage of `.dynamicTypeSize`, `@ScaledMetric`, or semantic `Font.TextStyle` APIs
  (`.body`, `.headline`, etc.) anywhere.
- CLAUDE.md's Typography table documents ~13 distinct roles, each with an exact pixel size,
  weight, and (for several roles) letter-tracking value — e.g. Screen title (32pt/800,
  tracking -0.5), Hero score (46pt/800, tabular-nums), Tab label (10pt/600). These are
  deliberate, curated design decisions, not arbitrary defaults.
- `AccessibilityAuditUITests` (built during the VoiceOver phase) already runs
  `performAccessibilityAudit()` across 7 screens, but its `auditTypes` set deliberately
  excludes `.dynamicType` and `.textClipped` — both real, iOS-available audit checks — with
  an explicit code comment marking Dynamic Type as "a separate, not-yet-addressed concern."
  This spec is that concern.

## Design

### Per-role scaling via `@ScaledMetric`

`@ScaledMetric` is a SwiftUI property wrapper that scales a base value according to the
user's current Dynamic Type setting. It must be declared as a stored property on the View
struct itself — it cannot be extracted into a shared free function or plain type, since it
needs to read the environment's content size category at the point of use. Each of the 15
files gets one `@ScaledMetric private var <name>: CGFloat = <base value>` declaration per
distinct font size it uses, replacing the current hardcoded literal in that file's
`.font(.system(size: ..., weight: ...))` calls.

The base value for each declaration is the EXACT value already in CLAUDE.md's Typography
table (e.g. `32` for Screen title, `46` for Hero score) — nothing about the app's appearance
changes at the system's default/standard content size category; only larger or smaller
settings now have any effect. Where the same typographic role appears in multiple files (e.g.
Screen title's 32pt appears in Matchday, Fixtures, Standings, and More), each file declares
its own independent `@ScaledMetric` property — unavoidable given the property-wrapper
constraint — but all instances share the same base value, so they scale identically and stay
visually consistent with each other.

Letter-tracking (`.tracking(...)`) values are NOT scaled — they stay at their fixed,
documented values. Standard Dynamic Type practice scales font size only; tracking is a
fixed visual proportion a human designer chose for a specific size/weight pairing, not
something the system auto-adjusts.

No `relativeTo:` text-style parameter is specified on any `@ScaledMetric` declaration
(defaults to `.body`'s scaling curve uniformly across all 57 sites) — mapping each of the
app's 13 bespoke typographic roles to whichever system `Font.TextStyle` has the closest
scaling curve is a separate, more involved design exercise or its own future refinement, not
needed for a correct first implementation. Uniform scaling is standard, acceptable practice.

### App-wide size cap

A single `.dynamicTypeSize(...DynamicTypeSize.accessibility1)` modifier applied once, at the
app root (`ContentView`), propagates the cap to every descendant view via the environment —
not repeated per-file. This allows the full standard Dynamic Type range plus the first
accessibility tier, while preventing the most extreme sizes (`accessibility2` through
`accessibility5`, which can be 2-3x+ the base size) from reaching tightly-constrained layouts
like the hero score or table cells, where they'd be most likely to cause visual breakage.

### Automated regression coverage

Add `.dynamicType` and `.textClipped` to `AccessibilityAuditUITests`'s existing `auditTypes`
set (both confirmed iOS-available in Task 11's own research into
`XCUIAccessibilityAuditTypes.h`). This is the natural capstone verification, reusing
infrastructure already built and already running across the same 7 screens. If either audit
type surfaces a real issue (a text element that doesn't respond to the setting, or clips at a
larger size), fix the underlying view — same convention as every other finding this
accessibility phase has produced (Standings header in VoiceOver, Bahia's font color in
Contrast).

### Documentation

Update CLAUDE.md's Typography table with a short prefatory note: the listed sizes are base
values at the system's default content size category, scaled via `@ScaledMetric` and capped
at `.accessibility1` app-wide. The table's actual size/weight/tracking values are unchanged —
this is a note about what the numbers now mean, not a change to the numbers themselves.

## Testing

Following this accessibility phase's established convention (CLAUDE.md: "Unit test
ViewModels and Services — not Views"): there is no ViewModel-layer logic to unit test here —
`@ScaledMetric` is a pure View-layer SwiftUI mechanism with no equivalent testable surface.
Verification is a clean build (confirms every call site compiles with the new property
wrapper), the extended `AccessibilityAuditUITests` (automated regression coverage for
Dynamic-Type-related issues across 7 screens), and a manual pass with the system text size
setting adjusted to confirm the app visually scales and nothing clips or overlaps at
`.accessibility1`.

## Out of Scope

- Mapping each typographic role to a specific `relativeTo:` system text style for a more
  Apple-native scaling curve per role — noted above as a possible future refinement.
- Any redesign of the 13 typographic roles themselves, or their base pixel/weight/tracking
  values — this spec only makes the existing values responsive, it doesn't change them.
- Color contrast (shipped) and reduced motion (shipped) — separate, already-completed items
  in this accessibility phase.
