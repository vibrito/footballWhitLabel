# Team Theme Long-Press Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Long-pressing a row in the Team Theme picker previews that theme's colors/background live, scoped to just that screen, without selecting or purchasing it — reverting the instant the press ends.

**Architecture:** `TeamThemeStore` gains a read-only `previewTokens(for:)` that reuses the exact same cached-then-network color resolution `select`/`apply` already use (refactored into one shared helper, removing duplication) but never mutates store state. `TeamThemePickerViewModel` gets a thin passthrough. `TeamThemePickerView` composes a tap gesture (select, unchanged) alongside a long-press gesture (preview) on each row, tracks preview state locally, and shadows the inherited `\.themeTokens` environment value with a local override — so only this screen's own subtree ever reflects the preview.

**Tech Stack:** SwiftUI (iOS 26+), Swift Testing, `@Observable`, `.sensoryFeedback` (SwiftUI-native haptics, no UIKit) — same stack as the rest of the app.

## Global Constraints

- No force-unwraps (`!`) outside of tests (CLAUDE.md).
- Every new `String(localized:)`/`Text(_:comment:)` call site needs entries in all 6 supported locales (`pt-BR`, `pt-PT`, `fr`, `en-US`, `en-GB`, `es`) in `BR2026/Resources/Localizable.xcstrings`. None of this plan's new strings interpolate arguments, so there is no format-specifier risk to verify — still run the JSON-validity check after each script.
- Unit test ViewModels and Services — not Views (CLAUDE.md). No new SwiftUI view tests; `AccessibilityAuditUITests.testTeamThemePickerAudit` (already exists) is the UI-level check this plan touches, and it should still pass unchanged — it audits whatever's currently on screen, so it naturally covers the new hint text and rows' new accessibility labels/actions without needing new interaction steps added to it.
- `previewTokens(for:)` must never call `PurchaseStore`, never call `TeamThemeSetting.setSelectedThemeID(_:)`, and must never mutate `TeamThemeStore.tokens`/`.selectedOption` — it is a pure read returning a value, exactly like the store's existing `cachedTeamThemeColorSet(teamID:)`.
- Removing the row's `Button` wrapper (needed so a tap gesture and a long-press gesture can coexist on the same view) must not regress VoiceOver's existing double-tap-to-select behavior — restore it explicitly via `.accessibilityAddTraits(.isButton)` + `.accessibilityAction(.default) { ... }` rather than assuming a bare `.onTapGesture` preserves it implicitly.

---

### Task 1: `TeamThemeStore` — shared token-building helper, `previewTokens(for:)`

**Files:**
- Modify: `BR2026/Services/TeamThemeStore.swift`
- Test: `BR2026Tests/Services/TeamThemeStoreTests.swift`

**Interfaces:**
- Produces: `TeamThemeStore.previewTokens(for: TeamThemeOption?) async -> ThemeTokens?`.
- Consumed by: Task 2 (`TeamThemePickerViewModel`'s thin wrapper).

- [ ] **Step 1: Write the failing tests**

```swift
// Append to BR2026Tests/Services/TeamThemeStoreTests.swift, inside the existing @Suite struct
    @Test("previewTokens(nil) returns today's default tokens")
    func previewTokensNilReturnsDefault() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        let store = TeamThemeStore(setting: setting, service: service)

        let previewed = await store.previewTokens(for: nil)

        #expect(previewed == ThemeTokens())
    }

    @Test("previewTokens(for:) resolves the same tokens select() would, without mutating tokens or selectedOption")
    func previewTokensResolvesWithoutMutating() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)

        let previewed = await store.previewTokens(for: .palmeirasHome)

        #expect(previewed?.overrideAccentColor == Color(hex: "006437"))
        #expect(previewed?.overrideAccentColor != Color(hex: "225638"))
        #expect(previewed?.textColor == Color(hex: "ffffff"))
        // Unlike select(), nothing about the store's own state changed.
        #expect(store.tokens == ThemeTokens())
        #expect(store.selectedOption == nil)
        #expect(setting.selectedThemeID == nil)
    }

    @Test("previewTokens(for:) returns nil when both cache and fetch fail")
    func previewTokensFailsWhenResolutionFails() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.shouldThrowOnTeamThemeFetch = true
        let store = TeamThemeStore(setting: setting, service: service)

        let previewed = await store.previewTokens(for: .palmeirasHome)

        #expect(previewed == nil)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BR2026Tests/TeamThemeStoreTests`
Expected: FAIL — `previewTokens(for:)` doesn't exist yet (build error).

- [ ] **Step 3: Refactor `TeamThemeStore` — full file replacement**

```swift
// BR2026/Services/TeamThemeStore.swift
import Foundation
import Observation

@Observable
@MainActor
final class TeamThemeStore {
    private(set) var tokens = ThemeTokens()
    private(set) var selectedOption: TeamThemeOption?
    private let setting: TeamThemeSetting
    private let service: MatchService
    private var hasLoadedOnce = false

    init(setting: TeamThemeSetting, service: MatchService) {
        self.setting = setting
        self.service = service
    }

    func loadOnce() async {
        guard !hasLoadedOnce else { return }
        hasLoadedOnce = true
        guard let selectedID = setting.selectedThemeID,
              let option = TeamThemeOption.allCases.first(where: { $0.rawValue == selectedID }) else { return }
        selectedOption = option
        await apply(option)
    }

    /// Returns `false` (and leaves the current selection/tokens untouched) if resolving colors
    /// for a newly-selected option fails — so a failed first-time fetch never leaves the picker
    /// showing a theme "selected" while the background silently never changed.
    @discardableResult
    func select(_ option: TeamThemeOption?) async -> Bool {
        guard let option else {
            setting.setSelectedThemeID(nil)
            selectedOption = nil
            tokens = ThemeTokens()
            return true
        }
        guard let colors = await resolveColors(teamID: option.teamID)?[option.kit] else { return false }
        setting.setSelectedThemeID(option.rawValue)
        selectedOption = option
        tokens = Self.tokens(for: option, colors: colors)
        return true
    }

    /// Resolves `option`'s colors and returns the `ThemeTokens` they'd produce, without
    /// touching `tokens`, `selectedOption`, or `setting` at all — a pure read, used by the
    /// Team Theme picker's long-press preview gesture. `nil` for `option` returns today's
    /// plain default tokens (matching `select(nil)`'s own reset value). Returns `nil` if
    /// color resolution fails (no cache and the network fetch throws) — the caller simply
    /// doesn't preview in that case, same failure shape as `select(_:)`'s own
    /// `guard ... else { return false }`, just without an error-message side effect (a
    /// failed preview isn't worth surfacing an alert for).
    func previewTokens(for option: TeamThemeOption?) async -> ThemeTokens? {
        guard let option else { return ThemeTokens() }
        guard let colors = await resolveColors(teamID: option.teamID)?[option.kit] else { return nil }
        return Self.tokens(for: option, colors: colors)
    }

    private func apply(_ option: TeamThemeOption) async {
        guard let colors = await resolveColors(teamID: option.teamID)?[option.kit] else { return }
        tokens = Self.tokens(for: option, colors: colors)
    }

    private func resolveColors(teamID: Int) async -> TeamThemeColorSet? {
        if let cached = service.cachedTeamThemeColorSet(teamID: teamID) { return cached }
        return try? await service.fetchTeamThemeColorSet(teamID: teamID)
    }

    /// The one `ThemeTokens.themed(...)` construction every selection path (`select`,
    /// `apply`, `previewTokens`) shares — previously duplicated verbatim between `select`
    /// and `apply`.
    private static func tokens(for option: TeamThemeOption, colors: TeamThemeColors) -> ThemeTokens {
        ThemeTokens.themed(
            mainColorHex: option.mainColorOverrideHex ?? colors.mainColorHex,
            fontColorHex: option.fontColorOverrideHex ?? colors.fontColorHex,
            tabSelectionColorHex: option.tabSelectionColorOverrideHex,
            pillFillColorHex: option.pillFillColorOverrideHex,
            gradientDarkAmount: option.gradientDarkAmountOverride ?? -0.75,
            usesDiagonalSashBackground: option.usesDiagonalSashBackground,
            gradientOuterColorHex: option.gradientOuterColorOverrideHex,
            usesSymmetricBottomGlow: option.usesSymmetricBottomGlow
        )
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BR2026Tests/TeamThemeStoreTests`
Expected: PASS, all tests including the 3 new ones. Every pre-existing test in this file (`select`/`apply`/`loadOnce` behavior) must also still pass unchanged — the refactor must not alter any of their observable behavior, only remove the duplicated `ThemeTokens.themed(...)` call.

- [ ] **Step 5: Build and run the full test suite**

Run: `xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `** BUILD SUCCEEDED **`

Run: `xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BR2026Tests`
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add BR2026/Services/TeamThemeStore.swift BR2026Tests/Services/TeamThemeStoreTests.swift
git commit -m "Add TeamThemeStore.previewTokens(for:), sharing token-building with select/apply"
```

---

### Task 2: `TeamThemePickerViewModel` — thin `previewTokens(for:)` wrapper

**Files:**
- Modify: `BR2026/ViewModels/TeamThemePickerViewModel.swift`
- Test: `BR2026Tests/ViewModels/TeamThemePickerViewModelTests.swift`

**Interfaces:**
- Consumes: `TeamThemeStore.previewTokens(for:)` from Task 1.
- Produces: `TeamThemePickerViewModel.previewTokens(for: TeamThemeOption?) async -> ThemeTokens?`.
- Consumed by: Task 3 (`TeamThemePickerView`'s `beginPreview(_:)`).

- [ ] **Step 1: Write the failing test**

This test file currently has no `import SwiftUI` (needed for `Color(hex:)` comparisons, matching `TeamThemeStoreTests.swift`'s own convention). Add it alongside the existing `import Testing`:

```swift
// BR2026Tests/ViewModels/TeamThemePickerViewModelTests.swift — add after `import Testing`
import SwiftUI
```

Then append this test inside the existing `@Suite` struct:

```swift
    @Test("previewTokens(for:) resolves colors without mutating selectedOption or the store's tokens")
    func previewTokensDoesNotMutateState() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)
        let purchaseStore = PurchaseStore<TeamThemeOption>(service: MockPurchaseService())
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting, service: service)

        let previewed = await viewModel.previewTokens(for: .palmeirasHome)

        #expect(previewed?.overrideAccentColor == Color(hex: "006437"))
        #expect(viewModel.selectedOption == nil)
        #expect(store.selectedOption == nil)
        #expect(store.tokens == ThemeTokens())
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BR2026Tests/TeamThemePickerViewModelTests`
Expected: FAIL — `previewTokens(for:)` doesn't exist on the ViewModel yet.

- [ ] **Step 3: Add the wrapper method**

```swift
// BR2026/ViewModels/TeamThemePickerViewModel.swift — add after price(for:)
    func previewTokens(for option: TeamThemeOption?) async -> ThemeTokens? {
        await themeStore.previewTokens(for: option)
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BR2026Tests/TeamThemePickerViewModelTests`
Expected: PASS, all tests including the new one.

- [ ] **Step 5: Build and run the full test suite**

Run: `xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `** BUILD SUCCEEDED **`

Run: `xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BR2026Tests`
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add BR2026/ViewModels/TeamThemePickerViewModel.swift BR2026Tests/ViewModels/TeamThemePickerViewModelTests.swift
git commit -m "Add TeamThemePickerViewModel.previewTokens(for:) wrapper"
```

---

### Task 3: `TeamThemePickerView` — hint text, gesture composition, preview state, accessibility

**Files:**
- Modify: `BR2026/Views/More/TeamThemePickerView.swift`
- Modify: `BR2026/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `TeamThemePickerViewModel.previewTokens(for:)` from Task 2.
- Produces: the finished preview feature — no later task depends on new interfaces from this one (Task 4 only re-verifies).

- [ ] **Step 1: Add the 3 new localized strings**

```bash
python3 << 'EOF'
import json

path = "BR2026/Resources/Localizable.xcstrings"
with open(path, encoding="utf-8") as f:
    data = json.load(f)

def entry(comment, values):
    return {
        "extractionState": "manual",
        "comment": comment,
        "localizations": {
            locale: {"stringUnit": {"state": "translated", "value": value}}
            for locale, value in values.items()
        }
    }

new_strings = {
    "Long press a theme to preview it": entry(
        "Hint above the Team Theme picker's row list, explaining the long-press-to-preview gesture.",
        {
            "en": "Long press a theme to preview it",
            "en-GB": "Long press a theme to preview it",
            "es": "Mantén pulsado un tema para previsualizarlo",
            "fr": "Appuyez longuement sur un thème pour le prévisualiser",
            "pt-BR": "Toque e segure um tema para pré-visualizá-lo",
            "pt-PT": "Mantenha premido um tema para pré-visualizá-lo",
        }
    ),
    "Preview": entry(
        "VoiceOver custom action name: previews this team theme's colors without selecting it.",
        {
            "en": "Preview",
            "en-GB": "Preview",
            "es": "Vista previa",
            "fr": "Aperçu",
            "pt-BR": "Pré-visualizar",
            "pt-PT": "Pré-visualizar",
        }
    ),
    "Stop Previewing": entry(
        "VoiceOver custom action name: stops previewing this team theme's colors, currently active on this row.",
        {
            "en": "Stop Previewing",
            "en-GB": "Stop Previewing",
            "es": "Dejar de previsualizar",
            "fr": "Arrêter l'aperçu",
            "pt-BR": "Parar pré-visualização",
            "pt-PT": "Parar pré-visualização",
        }
    ),
}

for key, value in new_strings.items():
    if key in data["strings"]:
        raise SystemExit(f"Key already exists, aborting: {key}")
    data["strings"][key] = value

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2, sort_keys=True)
    f.write("\n")
EOF
```

- [ ] **Step 2: Verify JSON validity**

Run: `python3 -c "import json; json.load(open('BR2026/Resources/Localizable.xcstrings'))" && echo "valid JSON"`
Expected: `valid JSON`

- [ ] **Step 3: Rewrite `TeamThemePickerView.swift` — full file replacement**

```swift
// BR2026/Views/More/TeamThemePickerView.swift
import SwiftUI

struct TeamThemePickerView: View {
    @State private var viewModel: TeamThemePickerViewModel
    @Environment(\.themeTokens) private var themeTokens
    @State private var previewState: PreviewState = .idle
    @ScaledMetric private var restoreButtonFontSize: CGFloat = 13
    @ScaledMetric private var errorMessageFontSize: CGFloat = 13
    @ScaledMetric private var rowFontSize: CGFloat = 16
    @ScaledMetric private var lockIconSize: CGFloat = 12
    @ScaledMetric private var priceFontSize: CGFloat = 13
    @ScaledMetric private var checkmarkIconSize: CGFloat = 15

    init(viewModel: TeamThemePickerViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    /// `idle`: nothing being previewed, `effectiveTokens` falls back to the real inherited
    /// environment value. `loading`: a long-press just crossed the 0.5s threshold and color
    /// resolution is in flight — nothing visibly changes yet. `active`: resolution
    /// succeeded and `effectiveTokens` now reflects the preview. `nil` inside either case
    /// means the "Default" row (no team).
    private enum PreviewState: Equatable {
        case idle
        case loading(TeamThemeOption?)
        case active(TeamThemeOption?, ThemeTokens)
    }

    /// What this screen's own background/rows actually render — the active preview's
    /// tokens while one is engaged, otherwise the real, inherited environment value.
    /// Re-injected locally below so only this screen's subtree ever sees the preview; every
    /// other screen in the app keeps reading the real selection from `ContentView`'s own
    /// `.environment(\.themeTokens, themeStore.tokens)`.
    private var effectiveTokens: ThemeTokens {
        if case .active(_, let tokens) = previewState { return tokens }
        return themeTokens
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Long press a theme to preview it", comment: "Hint above the Team Theme picker's row list, explaining the long-press-to-preview gesture.")
                    .font(.system(size: errorMessageFontSize))
                    .foregroundStyle(effectiveTokens.textColor.opacity(0.55))
                GlassCard(cornerRadius: 18, style: .transparent) {
                    VStack(spacing: 10) {
                        rowView(nil)
                        Rectangle().fill(Color.white.opacity(0.16)).frame(height: 0.5)
                        ForEach(Array(viewModel.sortedOptions.enumerated()), id: \.element.id) { index, option in
                            rowView(option)
                            if index < viewModel.sortedOptions.count - 1 {
                                Rectangle().fill(Color.white.opacity(0.16)).frame(height: 0.5)
                            }
                        }
                    }
                }
                Button {
                    Task { await viewModel.restorePurchases() }
                } label: {
                    Text("Restore Purchases")
                        .font(.system(size: restoreButtonFontSize, weight: .semibold))
                        .foregroundStyle(effectiveTokens.textColor.opacity(0.55))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.plain)
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: errorMessageFontSize))
                        .foregroundStyle(effectiveTokens.textColor.opacity(0.55))
                }
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
        .background(StadiumBackground())
        .environment(\.themeTokens, effectiveTokens)
        .navigationTitle("Team Theme")
        .navigationBarTitleDisplayMode(.inline)
        .trackScreen("TeamThemePicker")
        .task { await viewModel.loadOnce() }
        .sensoryFeedback(.impact, trigger: previewState) { _, new in
            if case .active = new { true } else { false }
        }
    }

    private func rowView(_ option: TeamThemeOption?) -> some View {
        HStack(spacing: 12) {
            if let option {
                Text(option.displayName)
            } else {
                Text("Default")
            }
            Spacer()
            trailingSlot(option)
                .accessibilityHidden(true)
        }
        .font(.system(size: rowFontSize, weight: .semibold))
        .foregroundStyle(effectiveTokens.textColor)
        .padding(.vertical, 10)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel(option))
        // A plain view with .onTapGesture doesn't reliably carry the same VoiceOver
        // double-tap-to-activate semantics a real Button provides for free — restored
        // explicitly here now that Button had to be removed to let the tap and long-press
        // gestures coexist on the same row.
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default) {
            Task { await viewModel.select(option) }
        }
        .accessibilityAction(named: isPreviewing(option)
            ? Text("Stop Previewing", comment: "VoiceOver custom action name: stops previewing this team theme's colors, currently active on this row.")
            : Text("Preview", comment: "VoiceOver custom action name: previews this team theme's colors without selecting it.")
        ) {
            Task {
                if isPreviewing(option) {
                    endPreview()
                } else {
                    await beginPreview(option)
                }
            }
        }
    }

    private func isPreviewing(_ option: TeamThemeOption?) -> Bool {
        switch previewState {
        case .idle: false
        case .loading(let loadingOption): loadingOption == option
        case .active(let activeOption, _): activeOption == option
        }
    }

    /// Kicks off color resolution for `option` and, once resolved, activates the preview —
    /// but only if the user (or VoiceOver) is still requesting *this same* option by the
    /// time resolution finishes. A fast release (or a switch to a different row) before the
    /// async fetch completes must not let a stale result clobber whatever's current by then.
    private func beginPreview(_ option: TeamThemeOption?) async {
        previewState = .loading(option)
        guard let tokens = await viewModel.previewTokens(for: option) else {
            if case .loading(option) = previewState { previewState = .idle }
            return
        }
        if case .loading(option) = previewState {
            previewState = .active(option, tokens)
        }
    }

    private func endPreview() {
        previewState = .idle
    }

    private func rowAccessibilityLabel(_ option: TeamThemeOption?) -> String {
        let name = option.map { String(localized: $0.displayName) } ?? String(localized: "Default", comment: "VoiceOver label for the Team Theme picker's non-team default row.")
        if let option, !viewModel.isPurchased(option) {
            let price = viewModel.price(for: option) ?? ""
            return String(
                localized: "\(name), locked, \(price)",
                comment: "VoiceOver label for a locked, purchasable team theme option. Arguments: the option's display name, its price."
            )
        }
        if viewModel.selectedOption == option {
            return String(
                localized: "\(name), selected",
                comment: "VoiceOver label for the currently-selected team theme option (or Default). Argument: the option's display name."
            )
        }
        return name
    }

    @ViewBuilder
    private func trailingSlot(_ option: TeamThemeOption?) -> some View {
        if let option, !viewModel.isPurchased(option) {
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: lockIconSize, weight: .semibold))
                if let price = viewModel.price(for: option) {
                    Text(price)
                        .font(.system(size: priceFontSize, weight: .semibold))
                }
            }
            .foregroundStyle(effectiveTokens.textColor.opacity(0.55))
        } else if viewModel.selectedOption == option {
            Image(systemName: "checkmark")
                .font(.system(size: checkmarkIconSize, weight: .semibold))
                .foregroundStyle(effectiveTokens.textColor)
        }
    }
}
```

Note: `trailingSlot` and the row/button/error text all switch from reading `themeTokens` directly to reading `effectiveTokens` — this is the entire mechanism by which the preview becomes visible on this screen (every color read on this screen now goes through `effectiveTokens`, which resolves to the preview's tokens while one is active).

- [ ] **Step 4: Build**

Run: `xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Run the full test suite**

Run: `xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BR2026Tests`
Expected: All tests pass. This task adds no new unit tests of its own (View-layer, no SwiftUI view tests per CLAUDE.md) — this step confirms the existing suite (including Tasks 1-2's new tests) still passes with the view wired up.

- [ ] **Step 6: Manual sanity check with mock data (optional but recommended)**

Run the app in the simulator, navigate to More → Team Theme, and confirm: (a) the hint text renders above the row list without clipping, (b) a quick tap on any row still selects it immediately with no visible preview flash first, (c) a press-and-hold (~0.5s+) on a row shifts this screen's background/text colors live, snapping back the instant you release, (d) this works identically on a locked (unpurchased) row without triggering any purchase prompt, (e) releasing while still mid-resolution (a very quick press-release on a team whose colors aren't cached yet) doesn't leave a stale preview stuck on screen.

- [ ] **Step 7: Commit**

```bash
git add BR2026/Views/More/TeamThemePickerView.swift BR2026/Resources/Localizable.xcstrings
git commit -m "Add long-press theme preview to TeamThemePickerView"
```

---

### Task 4: Final verification

**Files:** none — verification only, no code changes expected unless a real regression is found.

**Interfaces:** none — this task depends on Tasks 1-3 and produces nothing further.

- [ ] **Step 1: Run the existing Team Theme picker accessibility audit**

Run: `xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BR2026UITests/AccessibilityAuditUITests/testTeamThemePickerAudit`
Expected: PASS, unchanged. This test audits whatever's currently rendered on the Team Theme picker screen — it already exercises the new hint text and every row's new accessibility label/actions structurally, with no new interaction steps needed. If it fails with a genuine finding (not the documented `isDynamicTypeCapFalsePositive` pattern), root-cause and fix the underlying view per systematic-debugging — do not weaken or skip the audit.

- [ ] **Step 2: Run the complete test suite (unit + UI) one final time**

Run: `xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: All tests pass, 0 failures.

- [ ] **Step 3: Verify all 6 targets still build**

This feature only modifies existing, already-multi-target files (`TeamThemeStore.swift`, `TeamThemePickerViewModel.swift`, `TeamThemePickerView.swift`) and adds no new files — so the usual new-file-registered-in-only-1-target regression class doesn't apply here. Still, verify nothing else broke:

```bash
for scheme in PremierLeague2026 Ligue12026 PrimeiraLiga2026 ScottishPremiership2026 LaLiga2026; do
  echo "=== $scheme ==="
  xcodebuild -project BR2026.xcodeproj -scheme "$scheme" -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
done
```

Expected: `** BUILD SUCCEEDED **` for every scheme.

- [ ] **Step 4: No commit for this task** (verification only — if Step 1 or 2 finds and requires fixing a real regression, that fix gets its own commit, described inline at the point it's made, not pre-specified here since the plan doesn't know in advance whether one will be needed).
