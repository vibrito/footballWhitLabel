# Launch Screen Design Spec

## Goal

Add a native iOS Launch Screen so the app no longer falls back to a blank/default
screen during cold launch, before any app code (including SwiftUI) has run.

## Scope

- Native Launch Screen only — the OS-rendered screen shown for a fraction of a
  second between tapping the icon and the app's first frame.
- **Not** an in-app animated intro/splash view. No animation, no loading logic,
  no delay added to launch.
- No per-championship theming. Brasileirão is the only wired-up championship
  (per `CLAUDE.md` Scope); the launch screen is static content, not
  `ChampionshipConfig`-driven.

## Why not the full stadium-night gradient

The native Launch Screen mechanism supports only a solid background color plus
one optional static centered image — it renders before any code executes, so
it cannot reproduce `StadiumBackground`'s `RadialGradient` or blurred glow
blobs. A literal reproduction is architecturally impossible here; the design
below is the closest on-brand approximation within that constraint.

## Visual Design

- **Background:** solid `#061325` — the darkest stop of the existing
  stadium-night gradient (`StadiumBackground.swift`), so the transition from
  launch screen into the real app background reads as continuous rather than
  a visible color jump.
- **Centered mark:** the `soccerball` SF Symbol, rendered white, ~120pt wide.
  Reuses the app's existing icon language (the same symbol used for the
  Matchday tab) rather than the bundled `AppIcon` image, which is a green
  ball on a light cream background and would visually clash with a navy
  launch screen.
- No text, no tagline, no loading indicator.

## Implementation Mechanism

This project has no physical `Info.plist` (`GENERATE_INFOPLIST_FILE = YES`,
fully synthesized from `INFOPLIST_KEY_*` build settings). Two mechanisms can
produce an equivalent native Launch Screen; both give an identical result to
the user, so the choice is an implementation detail, not a design one:

1. **Preferred:** flattened `INFOPLIST_KEY_UILaunchScreen_*` build settings
   pointing at a background color asset and an image asset, keeping the
   no-physical-Info.plist convention this project already uses.
2. **Fallback:** a minimal `LaunchScreen.storyboard` (one view, solid
   background color, one centered `UIImageView`) plus the
   `UILaunchStoryboardName` build setting, if (1) doesn't reliably produce a
   populated `UILaunchScreen` dictionary in the built product's Info.plist.

Whichever mechanism is used, the implementation must verify the result by
inspecting the actual built app's Info.plist (or launch screen bundle) for
the expected `UILaunchScreen` dictionary / storyboard reference — not just
assume the build settings took effect, since a wrong key name fails silently
(you just get the default blank screen).

## Assets Needed

- A color asset (e.g. `LaunchBackground`) set to `#061325`.
- A white, ~120pt-equivalent static image rendering of the `soccerball` SF
  Symbol, exported as PNG image set asset(s) (e.g. `LaunchLogo`) — the
  Launch Screen mechanism needs a static image asset, it cannot reference a
  live SF Symbol at OS-render time.

## Out of Scope

- Any animation or transition.
- Per-championship / white-label theming of the launch screen.
- Changing the actual `AppIcon` asset (noted as a visual mismatch during
  design, but that's a separate, unrelated concern from this task).

## Testing

Views aren't unit-tested per `CLAUDE.md` ("unit test ViewModels and Services
— not Views"), and a Launch Screen has no ViewModel or logic. Verification is
a build check (confirming the Info.plist/storyboard artifact is correctly
produced) plus a manual Simulator smoke test (fresh install, cold launch,
confirm the navy background + white ball appears before the app's first
frame, with no white/blank flash).
