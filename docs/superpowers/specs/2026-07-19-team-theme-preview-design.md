# Team Theme Long-Press Preview — Design Spec

## Goal

Let a user long-press a row in the Team Theme picker (`TeamThemePickerView`) to see that
team's colors and background applied live, without selecting it — reverting the instant they
release. Closes the "Preview mode" idea noted (but never built) during the original Team
Theme IAP work.

## Background

`TeamThemePickerView` renders a `Default` row plus one row per `TeamThemeOption`
(`BR2026/Views/More/TeamThemePickerView.swift`). Each row is currently a `Button` whose tap
action calls `TeamThemePickerViewModel.select(_:)`
(`BR2026/ViewModels/TeamThemePickerViewModel.swift`), which — for a locked (unpurchased)
option — immediately calls `PurchaseStore<TeamThemeOption>.purchase(_:)`, a real StoreKit
purchase flow. A preview gesture must never trigger this: it needs a separate path that
resolves and shows colors without purchasing or persisting anything.

Colors themselves come from `TeamThemeStore` (`BR2026/Services/TeamThemeStore.swift`), which
already has a private `resolveColors(teamID:) async -> TeamThemeColorSet?` (cached-first, then
`MatchService.fetchTeamThemeColorSet(teamID:)`) and builds `ThemeTokens` via
`ThemeTokens.themed(...)` in both `select(_:)` and `apply(_:)` — the exact same computation
duplicated twice already. `ThemeTokens` itself is injected once at `ContentView`
(`.environment(\.themeTokens, themeStore.tokens)`) and read via `@Environment(\.themeTokens)`
everywhere, including by `TeamThemePickerView` and `StadiumBackground` today.

## Design

### Interaction

- **Tap**: unchanged — selects (and purchases if locked) exactly as today.
- **Long-press (0.5s)**: engages a preview of that row's theme. Works on every row, including
  `Default` and locked/unpurchased options — locked-theme preview is a deliberate
  "try before you buy" moment, and never calls `PurchaseStore`.
- **Release**: reverts instantly, regardless of whether the long-press threshold was reached
  (so a quick tap-and-release never flashes a preview first).

### Discoverability hint

Long-press has no visual affordance on its own, so a short hint line is added above the row
list (inside `TeamThemePickerView.body`'s outer `VStack`, before the `GlassCard`), reusing this
view's existing muted-caption style (matching `errorMessage`'s own
`Text(...).font(.system(size: errorMessageFontSize)).foregroundStyle(themeTokens.textColor.opacity(0.55))`
— same role, small secondary informational text, just at the top instead of the bottom):

```swift
Text("Long press a theme to preview it", comment: "Hint above the Team Theme picker's row list, explaining the long-press-to-preview gesture.")
    .font(.system(size: errorMessageFontSize))
    .foregroundStyle(themeTokens.textColor.opacity(0.55))
```

Shown unconditionally (not dismissible, not one-time) — it's short enough to not be
intrusive, and a persistent reminder is more useful than a hint that disappears after first
use, given nothing else on this screen otherwise indicates the gesture exists. New localized
string across all 6 locales, no interpolated arguments so no format-specifier risk.

### Gesture composition

Each row's `Button` is replaced with a plain view carrying two independent gesture
recognizers, so a quick tap and a genuine long-press are never confused:

```swift
.contentShape(Rectangle())
.onTapGesture {
    Task { await viewModel.select(option) }
}
.onLongPressGesture(minimumDuration: 0.5, pressing: { isPressing in
    if !isPressing {
        endPreview()
    }
}, perform: {
    Task { await beginPreview(option) }
})
```

`perform` only fires after the full 0.5s hold — a quick tap never reaches it, so `onTapGesture`
alone handles normal selection with no preview flash. `pressing(false)` fires on release
regardless of duration (quick tap or full hold), so `endPreview()` is always the release-time
cleanup, whether or not a preview was ever actually showing.

### Color resolution — new store method, no duplicated logic

`TeamThemeStore` gains:

```swift
func previewTokens(for option: TeamThemeOption?) async -> ThemeTokens? {
    guard let option else { return ThemeTokens() }
    guard let colors = await resolveColors(teamID: option.teamID)?[option.kit] else { return nil }
    return Self.tokens(for: option, colors: colors)
}
```

`select(_:)` and `apply(_:)`'s existing near-identical `ThemeTokens.themed(...)` calls are
refactored into the same shared `Self.tokens(for:colors:)` helper `previewTokens` now also
calls — removing the duplication rather than adding a third copy. `previewTokens` never
mutates `tokens`, `selectedOption`, or calls into `TeamThemeSetting` — purely a read that
returns a value, matching this class's existing `cachedTeamThemeColorSet`-style read-only
methods. Returns `nil` on a resolution failure (e.g. no cache and the network fetch throws) —
the caller simply doesn't preview in that case, mirroring `select(_:)`'s existing
`guard let colors = ... else { return false }` failure handling, just without the error message
surface (a failed preview isn't worth interrupting the user with an alert for).

`TeamThemePickerViewModel` gains a thin passthrough (matching its existing
`isPurchased(_:)`/`price(for:)` wrappers around `purchaseStore`, the same "View never reaches
past its ViewModel to touch a Store directly" convention):

```swift
func previewTokens(for option: TeamThemeOption?) async -> ThemeTokens? {
    await themeStore.previewTokens(for: option)
}
```

### Preview state and scope

`TeamThemePickerView` gains local state:

```swift
private enum PreviewState: Equatable {
    case idle
    case loading(TeamThemeOption?)              // nil = Default
    case active(TeamThemeOption?, ThemeTokens)
}
@State private var previewState: PreviewState = .idle
```

The view's own background/row text now read an *effective* tokens value instead of the
environment directly:

```swift
private var effectiveTokens: ThemeTokens {
    if case .active(_, let tokens) = previewState { return tokens }
    return themeTokens  // the real, inherited environment value
}
```

...and re-injects it locally so only this screen's own subtree sees the preview:

```swift
.environment(\.themeTokens, effectiveTokens)
```

This is why the preview never leaks to other screens: every other view in the app (including
the rest of More, and all other tabs) still reads the real `themeTokens` set once at
`ContentView` — this view alone shadows it locally, and only while `previewState` is
`.active`.

`beginPreview(_:)`/`endPreview()`:

```swift
private func beginPreview(_ option: TeamThemeOption?) async {
    previewState = .loading(option)
    guard let tokens = await viewModel.previewTokens(for: option) else {
        if case .loading(option) = previewState { previewState = .idle }
        return
    }
    // Only commit if the user is still holding *this* row's press when the fetch resolves —
    // a fast release-before-resolution shouldn't leave a stale preview active.
    if case .loading(option) = previewState {
        previewState = .active(option, tokens)
    }
}

private func endPreview() {
    previewState = .idle
}
```

### Locked themes

No change to `isPurchased`/`purchase` gating anywhere in this feature — `previewTokens(for:)`
resolves colors via the same `resolveColors(teamID:)` path regardless of ownership (that
method has never checked purchase state; only `select(_:)`'s separate purchase-gating branch
does). A locked row's preview looks identical to an owned row's — the lock icon and price stay
visible in the row's trailing slot throughout, so it's clear the theme still isn't owned.

### Accessibility

VoiceOver has no long-press-and-hold equivalent, so each row gets a custom accessibility
action instead of relying on the gesture:

```swift
.accessibilityAction(named: isPreviewingThisRow ? "Stop Previewing" : "Preview") {
    Task {
        if isPreviewingThisRow {
            endPreview()
        } else {
            await beginPreview(option)
        }
    }
}
```

Invoking "Preview" on a different row while one is already active simply switches — the same
`beginPreview(_:)` call handles it, no separate teardown step needed since `previewState` is
just overwritten. New localized strings ("Preview" / "Stop Previewing") in all 6 locales.

### Feedback

```swift
.sensoryFeedback(.impact, trigger: previewState) { old, new in
    if case .active = new { true } else { false }
}
```

A light haptic fires exactly when a preview actually engages (color resolution succeeded) —
not on press-down, not on a failed/still-loading attempt. SwiftUI-native (`.sensoryFeedback`,
iOS 17+), no UIKit `UIImpactFeedbackGenerator`.

### Out of Scope

- App-wide preview (every screen shifting live) — explicitly rejected in favor of a
  screen-scoped preview; see the design discussion above.
- Auto-reverting a VoiceOver-triggered preview after a timeout — it stays active until
  explicitly toggled off or the screen is left, matching how a sighted long-press only reverts
  on an explicit release.
- Any change to the actual selection/purchase flow (`select(_:)` is untouched).

## Testing

- **`TeamThemeStore`**: `previewTokens(for:)` tested for (a) `nil` option → default
  `ThemeTokens()`, (b) a cached team → resolved tokens matching `Self.tokens(for:colors:)`'s
  output directly (same assertions style as the existing `select()`/`apply()` tests already
  cover per-team curated overrides), (c) resolution failure → `nil`, (d) confirms `tokens`/
  `selectedOption` are unchanged after a `previewTokens` call — the one behavior that
  distinguishes it from `select`.
- **`TeamThemePickerView`**: no new SwiftUI view tests per CLAUDE.md's "Unit test ViewModels
  and Services — not Views" — the gesture composition and `PreviewState` transitions are
  View-local and not independently testable without a UI harness; verified via build + the
  existing `AccessibilityAuditUITests.testTeamThemePickerAudit` (which should be extended to
  exercise the new "Preview" custom action once implemented, confirming it's discoverable and
  doesn't itself trigger any audit finding) plus a manual pass.
