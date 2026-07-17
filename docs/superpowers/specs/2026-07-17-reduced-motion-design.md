# Reduced Motion Support — Design Spec

## Goal

Respect the system Reduce Motion accessibility setting (Settings → Accessibility → Motion)
across all three motion effects currently in the app, so users with vestibular sensitivity
who've enabled it don't see repeating pulses or animated scroll transitions.

This is the first of three remaining items in the broader "Accessibility" roadmap phase
(sequence: Reduced Motion → Contrast → Dynamic Type), following VoiceOver support (shipped
2026-07-17).

## Background

A full-codebase audit found exactly three animations, none of which currently check
`accessibilityReduceMotion`:

1. **`LiveChip`'s live-match pulse** (`BR2026/Components/LiveChip.swift:47-51`) — the dot
   next to a live match's minute/score pulses opacity 1→0.35→1 and scale 1→0.8→1, 1.4s
   ease-in-out, repeating forever. Per CLAUDE.md's documented animation spec.
2. **`RefreshPulseDot`'s refresh-in-progress pulse** (`BR2026/Components/RefreshPulseDot.swift`)
   — same values, muted `white @ 0.5`, shown in Fixtures/Standings' nav bar while a background
   refresh is in flight.
3. **`FixturesView`'s round-picker auto-scroll** (`BR2026/Views/Fixtures/FixturesView.swift:77-82`)
   — a one-shot (non-repeating) `withAnimation { proxy.scrollTo(newValue, anchor: .center) }`
   that smoothly scrolls the newly-selected round pill into view.

Both `LiveChip` and `RefreshPulseDot` are already `.accessibilityHidden(true)` (from the
VoiceOver work), so this is purely a visual/vestibular concern for sighted users — unrelated
to VoiceOver.

## Design

### Pulse animations (LiveChip, RefreshPulseDot)

Both components already hold a `@State private var pulse = false` driving the animated
opacity/scale, set inside `.onAppear`. Add `@Environment(\.accessibilityReduceMotion) private
var reduceMotion` to each, and skip starting the animation when it's true:

```swift
.onAppear {
    guard !reduceMotion else { return }
    withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
        pulse = true
    }
}
```

Since `pulse` never flips to `true` when Reduce Motion is on, the dot renders at its default,
static appearance (opacity 1, scale 1) — no animation, no visual difference from a normal
non-animating dot. This matches the "keep static, fully opaque" behavior confirmed with the
user, and requires no other changes to either view's body.

### Round-picker scroll (FixturesView)

Add the same `@Environment(\.accessibilityReduceMotion)` read to `FixturesView`, and
conditionally wrap the scroll call:

```swift
.onChange(of: viewModel.selectedRound) { _, newValue in
    guard let newValue else { return }
    if reduceMotion {
        proxy.scrollTo(newValue, anchor: .center)
    } else {
        withAnimation {
            proxy.scrollTo(newValue, anchor: .center)
        }
    }
}
```

With Reduce Motion on, the scroll still happens (the round pill still needs to end up
centered) — it just jumps instantly instead of animating, which is the standard iOS
convention for this setting (motion is suppressed, not functionality).

## Testing

This codebase's established convention (CLAUDE.md's Testing section) is to unit-test
ViewModels and Services, not Views — and `@Environment(\.accessibilityReduceMotion)` is a
View-layer SwiftUI environment value with no ViewModel-layer equivalent to unit test. There is
no existing pattern anywhere in this codebase for testing View-level environment-gated
behavior (confirmed: zero references to `accessibilityReduceMotion` or any reduce-motion
testing utility before this change).

Verification is therefore build-plus-manual, matching how the VoiceOver plan's pure
view-wiring tasks (Tasks 6-10) were verified: a clean build confirms the code compiles, and a
manual pass with Reduce Motion toggled on in Settings confirms the dots render static and the
round-picker scroll jumps instantly instead of animating.

## Out of Scope

- Any animation added to the app in the future is not retroactively covered by this spec —
  new animations should independently consider Reduce Motion at the time they're written.
- SwiftUI's implicit/default animations (e.g. any automatic cross-fade on state-driven view
  insertion/removal that isn't wrapped in an explicit `withAnimation`) were not found anywhere
  in the audited codebase and are not addressed here.
- Color contrast and Dynamic Type are separate, already-sequenced roadmap items — not covered
  by this spec.
