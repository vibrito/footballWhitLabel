# Reduced Motion Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Respect the system Reduce Motion accessibility setting across all three motion
effects in the app — two repeating pulse animations and one auto-scroll transition — so
users with vestibular sensitivity who've enabled it see static UI instead of motion.

**Architecture:** Each of the three affected views reads
`@Environment(\.accessibilityReduceMotion)` and conditionally skips (or replaces) its
existing `withAnimation` call. No new types, no new files, no ViewModel changes — this is a
pure View-layer change confined to three existing files.

**Tech Stack:** SwiftUI's built-in `accessibilityReduceMotion` environment value (no new
dependencies).

## Global Constraints

- Full spec: `docs/superpowers/specs/2026-07-17-reduced-motion-design.md`.
- When Reduce Motion is on, the two pulse dots (`LiveChip`, `RefreshPulseDot`) must render
  static and fully opaque (opacity 1, scale 1) — not dimmed, not hidden, just non-animating.
- When Reduce Motion is on, `FixturesView`'s round-picker must still scroll the selected
  round pill into view — it must jump instantly instead of animating, not skip the scroll
  entirely.
- No new tests are expected — this codebase's Testing convention (CLAUDE.md) scopes unit
  tests to ViewModels/Services, not Views, and there is no existing pattern for testing
  View-level environment-gated behavior. Verification is a clean build plus a manual pass
  with Reduce Motion toggled on in Settings.
- No `UIKit` needed — `accessibilityReduceMotion` is a native SwiftUI `EnvironmentValues`
  member (`import SwiftUI` already present in all three files).

---

### Task 1: Gate all three animations behind Reduce Motion

**Files:**
- Modify: `BR2026/Components/LiveChip.swift`
- Modify: `BR2026/Components/RefreshPulseDot.swift`
- Modify: `BR2026/Views/Fixtures/FixturesView.swift`

**Interfaces:**
- Produces: no new public members — `LiveChip`, `RefreshPulseDot`, and `FixturesView`'s
  existing initializers and bodies are otherwise unchanged; this task only adds an internal
  environment read and conditional to each.

- [ ] **Step 1: Gate `LiveChip`'s pulse**

In `BR2026/Components/LiveChip.swift`, find:

```swift
struct LiveChip: View {
    var minute: Int? = nil
    var isHalftime: Bool = false
    @Environment(\.themeTokens) private var themeTokens
    @State private var pulse = false
```

Replace with:

```swift
struct LiveChip: View {
    var minute: Int? = nil
    var isHalftime: Bool = false
    @Environment(\.themeTokens) private var themeTokens
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
```

Then find:

```swift
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .accessibilityHidden(true)
    }
}
```

Replace with:

```swift
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .accessibilityHidden(true)
    }
}
```

- [ ] **Step 2: Gate `RefreshPulseDot`'s pulse**

In `BR2026/Components/RefreshPulseDot.swift`, find:

```swift
struct RefreshPulseDot: View {
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(.white.opacity(0.5))
            .frame(width: 6, height: 6)
            .opacity(pulse ? 0.35 : 1)
            .scaleEffect(pulse ? 0.8 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
            .accessibilityHidden(true)
    }
}
```

Replace with:

```swift
struct RefreshPulseDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(.white.opacity(0.5))
            .frame(width: 6, height: 6)
            .opacity(pulse ? 0.35 : 1)
            .scaleEffect(pulse ? 0.8 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
            .accessibilityHidden(true)
    }
}
```

- [ ] **Step 3: Gate `FixturesView`'s round-picker scroll animation**

In `BR2026/Views/Fixtures/FixturesView.swift`, find:

```swift
struct FixturesView: View {
    @State private var viewModel: FixturesViewModel
    @State private var selectedMatch: Match?
    let service: MatchService
    @Environment(\.themeTokens) private var themeTokens
    @Environment(\.scenePhase) private var scenePhase
```

Replace with:

```swift
struct FixturesView: View {
    @State private var viewModel: FixturesViewModel
    @State private var selectedMatch: Match?
    let service: MatchService
    @Environment(\.themeTokens) private var themeTokens
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
```

Then find:

```swift
            .onChange(of: viewModel.selectedRound) { _, newValue in
                guard let newValue else { return }
                withAnimation {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
```

Replace with:

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

- [ ] **Step 4: Build to verify it compiles**

Run: `rm -rf ~/Library/Developer/Xcode/DerivedData/BR2026-* && xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation clean build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Run the full test suite**

Run: `eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: all existing tests still pass (no new tests in this task — see Global Constraints).

- [ ] **Step 6: Manual verification**

On a simulator or device, enable Reduce Motion (Settings → Accessibility → Motion → Reduce
Motion). Confirm: the live-match dot in `LiveChip` (visible on a live match's card) renders
static and fully opaque, not pulsing. Confirm: the nav-bar refresh dot (`RefreshPulseDot`,
visible briefly while Fixtures/Standings background-refresh) renders static and fully opaque
when it appears. Confirm: tapping a different round pill in Fixtures still scrolls the
newly-selected pill into view, but instantly rather than with a smooth animation. Then
disable Reduce Motion and confirm all three animations behave exactly as before (pulsing
dots, animated scroll) — this change must be purely additive/conditional, not a regression
to the default (motion-enabled) experience.

- [ ] **Step 7: Commit**

```bash
git add BR2026/Components/LiveChip.swift BR2026/Components/RefreshPulseDot.swift BR2026/Views/Fixtures/FixturesView.swift
git commit -m "Respect Reduce Motion for pulse animations and round-picker scroll"
```

---
