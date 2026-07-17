# Dynamic Type Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every piece of text (and icon glyph sized via `.font(.system(size:))`) in the
app respond to the system Dynamic Type setting, while preserving the app's exact existing
pixel-precise appearance as the default at the standard content size category.

**Architecture:** `@ScaledMetric` property wrappers, one per distinct font/icon size declared
per file (57 total call sites across 15 files), replacing each hardcoded `size:` literal.
A single app-root `.dynamicTypeSize(...DynamicTypeSize.accessibility1)` caps the range.
`AccessibilityAuditUITests` gets `.dynamicType`/`.textClipped` added to its audit set as the
capstone regression gate.

**Tech Stack:** SwiftUI's built-in `@ScaledMetric`/`DynamicTypeSize` (no new dependencies).

## Global Constraints

- Full spec: `docs/superpowers/specs/2026-07-17-dynamic-type-design.md`.
- Every `@ScaledMetric` declaration's base value (the `= <literal>` default, or the seeded
  `wrappedValue:` for `TeamCrestBadge`) must exactly match the current hardcoded value — no
  value changes, only making existing values responsive.
- No `relativeTo:` parameter on any `@ScaledMetric` declaration — uniform default (`.body`)
  scaling curve across all 57 sites, per the design spec.
- Letter-tracking (`.tracking(...)`) values are NOT touched — they stay fixed. Only the
  `size:` argument inside `.font(.system(size: ..., weight: ...))` changes, from a literal to
  a `@ScaledMetric`-backed property reference.
- `Image(systemName:)` icon glyphs sized via `.font(.system(size:))` ARE converted the same
  way as `Text` — per the confirmed scope decision, icons scale too.
- `@ScaledMetric` must be a stored property on the View struct itself — it cannot be
  extracted into a shared helper type or free function. Where the exact same value is reused
  for the exact same semantic role within one file (e.g. two icon-row titles in the same
  picker view), one `@ScaledMetric` property may be shared between call sites in that file.
  Never share a `@ScaledMetric` property across two different files.
- `TeamCrestBadge.swift`'s derived size (`size * 0.4`, where `size` is a caller-supplied
  parameter) is the one exception to the static-literal pattern — seed it via
  `@ScaledMetric(wrappedValue:)` in a custom `init`, per the confirmed design decision.
- Every task in this plan is verified by a clean build only (no new unit tests expected —
  `@ScaledMetric` is a pure View-layer mechanism with no ViewModel-layer equivalent to test,
  per this project's established "unit test ViewModels/Services, not Views" convention).
  The final task (Task 8) adds the actual regression coverage, via the existing
  `AccessibilityAuditUITests` UI test infrastructure.
- Do not touch any file's business logic, layout structure, colors, or non-font modifiers —
  this plan is scoped exclusively to making font/icon sizes responsive.

---

### Task 1: App-root Dynamic Type cap

**Files:**
- Modify: `BR2026/Views/Root/ContentView.swift`

- [ ] **Step 1: Add the cap modifier**

In `BR2026/Views/Root/ContentView.swift`, find the end of `body`'s modifier chain:

```swift
        .environment(\.themeTokens, themeStore.tokens)
        .task { await themeStore.loadOnce() }
        .task { await themePurchaseStore.loadOnce() }
        .task { await iconPurchaseStore.loadOnce() }
    }
```

Replace with:

```swift
        .environment(\.themeTokens, themeStore.tokens)
        .task { await themeStore.loadOnce() }
        .task { await themePurchaseStore.loadOnce() }
        .task { await iconPurchaseStore.loadOnce() }
        // Allows the full standard Dynamic Type range plus the first accessibility tier;
        // caps before accessibility2-5, which can be 2-3x+ base size and are most likely to
        // break tightly-constrained layouts like the hero score or table cells.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
```

- [ ] **Step 2: Build to verify it compiles**

Run: `rm -rf ~/Library/Developer/Xcode/DerivedData/BR2026-* && xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation clean build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Run the full test suite**

Run: `eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: all existing tests still pass (no new tests in this task).

- [ ] **Step 4: Commit**

```bash
git add BR2026/Views/Root/ContentView.swift
git commit -m "Cap app-wide Dynamic Type at accessibility1"
```

---

### Task 2: Small components — AccentPill, LiveChip, ScoreRow, TeamCrestBadge

**Files:**
- Modify: `BR2026/Components/AccentPill.swift`
- Modify: `BR2026/Components/LiveChip.swift`
- Modify: `BR2026/Components/ScoreRow.swift`
- Modify: `BR2026/Components/TeamCrestBadge.swift`

- [ ] **Step 1: `AccentPill.swift`**

Find:

```swift
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(0.3)
```

Replace with:

```swift
    @ScaledMetric private var fontSize: CGFloat = 11

    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .bold))
            .tracking(0.3)
```

(Add the `@ScaledMetric` property declaration immediately before `var body`, in the struct's
property list.)

- [ ] **Step 2: `LiveChip.swift`**

Find:

```swift
    @Environment(\.themeTokens) private var themeTokens
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
```

Replace with:

```swift
    @Environment(\.themeTokens) private var themeTokens
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    @ScaledMetric private var fontSize: CGFloat = 11
```

Then find:

```swift
            Text(chipText)
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.5)
```

Replace with:

```swift
            Text(chipText)
                .font(.system(size: fontSize, weight: .heavy))
                .tracking(0.5)
```

- [ ] **Step 3: `ScoreRow.swift`**

Find the struct's property declarations (near the top, before `body`) and add two new
`@ScaledMetric` properties alongside the existing ones (read the file first to find the exact
insertion point — add after the last existing `@Environment`/`@State`/`let`/`var` property
declaration, before `var body`):

```swift
    @ScaledMetric private var teamNameFontSize: CGFloat = 16
    @ScaledMetric private var scoreFontSize: CGFloat = 19
```

Then find:

```swift
    private func teamLabel(_ team: Team) -> some View {
        HStack(spacing: 8) {
            TeamCrestBadge(team: team)
            Text(team.displayName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(themeTokens.textColor)
        }
    }
```

Replace with:

```swift
    private func teamLabel(_ team: Team) -> some View {
        HStack(spacing: 8) {
            TeamCrestBadge(team: team)
            Text(team.displayName)
                .font(.system(size: teamNameFontSize, weight: .semibold))
                .foregroundStyle(themeTokens.textColor)
        }
    }
```

Then find:

```swift
        .font(.system(size: 19, weight: .heavy))
        .monospacedDigit()
        .foregroundStyle(themeTokens.textColor)
    }
```

Replace with:

```swift
        .font(.system(size: scoreFontSize, weight: .heavy))
        .monospacedDigit()
        .foregroundStyle(themeTokens.textColor)
    }
```

- [ ] **Step 4: `TeamCrestBadge.swift`**

Find:

```swift
struct TeamCrestBadge: View {
    let team: Team
    var size: CGFloat = 32

    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeTokens) private var themeTokens
    @State private var imageData: Data?

    var body: some View {
```

Replace with:

```swift
struct TeamCrestBadge: View {
    let team: Team
    var size: CGFloat = 32

    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeTokens) private var themeTokens
    @State private var imageData: Data?
    // Seeded (not a static default) since it's derived from the caller-supplied `size`
    // parameter, not a fixed literal — still responsive to Dynamic Type via the normal
    // @ScaledMetric mechanism, just initialized proportionally instead of with a constant.
    @ScaledMetric private var initialsFontSize: CGFloat

    init(team: Team, size: CGFloat = 32) {
        self.team = team
        self.size = size
        self._initialsFontSize = ScaledMetric(wrappedValue: size * 0.4)
    }

    var body: some View {
```

Then find:

```swift
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundStyle(themeTokens.textColor.opacity(0.55))
```

Replace with:

```swift
                Text(initials)
                    .font(.system(size: initialsFontSize, weight: .bold))
                    .foregroundStyle(themeTokens.textColor.opacity(0.55))
```

- [ ] **Step 5: Build to verify it compiles**

Run: `rm -rf ~/Library/Developer/Xcode/DerivedData/BR2026-* && xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation clean build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Run the full test suite**

Run: `eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: all existing tests still pass.

- [ ] **Step 7: Commit**

```bash
git add BR2026/Components/AccentPill.swift BR2026/Components/LiveChip.swift BR2026/Components/ScoreRow.swift BR2026/Components/TeamCrestBadge.swift
git commit -m "Add Dynamic Type support to AccentPill, LiveChip, ScoreRow, TeamCrestBadge"
```

---

### Task 3: Match display components — FixtureMatchCard, HeroMatchCard, MatchTimelineRow

**Files:**
- Modify: `BR2026/Components/FixtureMatchCard.swift`
- Modify: `BR2026/Components/HeroMatchCard.swift`
- Modify: `BR2026/Components/MatchTimelineRow.swift`

- [ ] **Step 1: `FixtureMatchCard.swift`**

Add three `@ScaledMetric` properties to the struct's property list (before `var body`):

```swift
    @ScaledMetric private var headerFontSize: CGFloat = 11
    @ScaledMetric private var teamNameFontSize: CGFloat = 16
    @ScaledMetric private var scoreFontSize: CGFloat = 19
```

Find:

```swift
        .font(.system(size: 11, weight: .bold))
        .tracking(0.6)
        .foregroundStyle(themeTokens.textColor.opacity(0.5))
    }
```

Replace with:

```swift
        .font(.system(size: headerFontSize, weight: .bold))
        .tracking(0.6)
        .foregroundStyle(themeTokens.textColor.opacity(0.5))
    }
```

Find:

```swift
            Text(team.displayName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(themeTokens.textColor)
                .lineLimit(1)
            Spacer()
```

Replace with:

```swift
            Text(team.displayName)
                .font(.system(size: teamNameFontSize, weight: .semibold))
                .foregroundStyle(themeTokens.textColor)
                .lineLimit(1)
            Spacer()
```

Find:

```swift
            if let score {
                Text("\(score)")
                    .font(.system(size: 19, weight: .heavy))
                    .monospacedDigit()
```

Replace with:

```swift
            if let score {
                Text("\(score)")
                    .font(.system(size: scoreFontSize, weight: .heavy))
                    .monospacedDigit()
```

- [ ] **Step 2: `HeroMatchCard.swift`**

Add five `@ScaledMetric` properties to the struct's property list (before `var body`):

```swift
    @ScaledMetric private var venueFontSize: CGFloat = 13
    @ScaledMetric private var kickoffFontSize: CGFloat = 15
    @ScaledMetric private var teamNameFontSize: CGFloat = 19
    @ScaledMetric private var scoreFontSize: CGFloat = 40
    @ScaledMetric private var vsFontSize: CGFloat = 30
```

Find:

```swift
                Text(venueLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(themeTokens.textColor.opacity(0.5))
                    .lineLimit(1)
```

Replace with:

```swift
                Text(venueLabel)
                    .font(.system(size: venueFontSize, weight: .medium))
                    .foregroundStyle(themeTokens.textColor.opacity(0.5))
                    .lineLimit(1)
```

Find:

```swift
            Text(match.utcDate, style: .time)
                .font(.system(size: 15, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(themeTokens.textColor.opacity(0.65))
```

Replace with:

```swift
            Text(match.utcDate, style: .time)
                .font(.system(size: kickoffFontSize, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(themeTokens.textColor.opacity(0.65))
```

Find:

```swift
            Text(team.displayName)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(themeTokens.textColor)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
```

Replace with:

```swift
            Text(team.displayName)
                .font(.system(size: teamNameFontSize, weight: .bold))
                .foregroundStyle(themeTokens.textColor)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
```

Find:

```swift
            Text("\(home) – \(away)")
                .font(.system(size: 40, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(themeTokens.textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        } else {
            Text("VS")
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(themeTokens.textColor.opacity(0.35))
        }
    }
}
```

Replace with:

```swift
            Text("\(home) – \(away)")
                .font(.system(size: scoreFontSize, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(themeTokens.textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        } else {
            Text("VS")
                .font(.system(size: vsFontSize, weight: .heavy))
                .foregroundStyle(themeTokens.textColor.opacity(0.35))
        }
    }
}
```

- [ ] **Step 3: `MatchTimelineRow.swift`**

Add five `@ScaledMetric` properties to the struct's property list (before `var body`):

```swift
    @ScaledMetric private var timeBadgeFontSize: CGFloat = 13
    @ScaledMetric private var playerNameFontSize: CGFloat = 15
    @ScaledMetric private var subtitleFontSize: CGFloat = 12
    @ScaledMetric private var goalIconSize: CGFloat = 13
    @ScaledMetric private var substitutionIconSize: CGFloat = 11
```

Find:

```swift
    private var timeBadge: some View {
        Text(minuteLabel)
            .font(.system(size: 13, weight: .bold))
            .monospacedDigit()
```

Replace with:

```swift
    private var timeBadge: some View {
        Text(minuteLabel)
            .font(.system(size: timeBadgeFontSize, weight: .bold))
            .monospacedDigit()
```

Find:

```swift
                Text(event.player)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let subtitleText {
                    subtitleText
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
```

Replace with:

```swift
                Text(event.player)
                    .font(.system(size: playerNameFontSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let subtitleText {
                    subtitleText
                        .font(.system(size: subtitleFontSize))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
```

Find:

```swift
        case .goal:
            Image(systemName: "soccerball")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.8))
```

Replace with:

```swift
        case .goal:
            Image(systemName: "soccerball")
                .font(.system(size: goalIconSize))
                .foregroundStyle(.white.opacity(0.8))
```

Find:

```swift
            .font(.system(size: 11, weight: .bold))
        case .unknown:
```

Replace with:

```swift
            .font(.system(size: substitutionIconSize, weight: .bold))
        case .unknown:
```

- [ ] **Step 4: Build to verify it compiles**

Run: `rm -rf ~/Library/Developer/Xcode/DerivedData/BR2026-* && xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation clean build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Run the full test suite**

Run: `eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: all existing tests still pass.

- [ ] **Step 6: Commit**

```bash
git add BR2026/Components/FixtureMatchCard.swift BR2026/Components/HeroMatchCard.swift BR2026/Components/MatchTimelineRow.swift
git commit -m "Add Dynamic Type support to FixtureMatchCard, HeroMatchCard, MatchTimelineRow"
```

---

### Task 4: Fixtures & Matchday views

**Files:**
- Modify: `BR2026/Views/Fixtures/FixturesView.swift`
- Modify: `BR2026/Views/Matchday/MatchdayView.swift`

- [ ] **Step 1: `FixturesView.swift`**

Add two `@ScaledMetric` properties to the struct's property list (near the top, alongside the
existing `@Environment(\.accessibilityReduceMotion) private var reduceMotion` from the
Reduced Motion plan):

```swift
    @ScaledMetric private var roundLabelFontSize: CGFloat = 10
    @ScaledMetric private var roundNumberFontSize: CGFloat = 17
```

Find:

```swift
                Text("Round")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.4)
                Text("\(round)")
                    .font(.system(size: 17, weight: .heavy))
                    .monospacedDigit()
```

Replace with:

```swift
                Text("Round")
                    .font(.system(size: roundLabelFontSize, weight: .bold))
                    .tracking(0.4)
                Text("\(round)")
                    .font(.system(size: roundNumberFontSize, weight: .heavy))
                    .monospacedDigit()
```

- [ ] **Step 2: `MatchdayView.swift`**

Add five `@ScaledMetric` properties to the struct's property list (before `var body`):

```swift
    @ScaledMetric private var eyebrowFontSize: CGFloat = 11
    @ScaledMetric private var titleFontSize: CGFloat = 32
    @ScaledMetric private var sectionHeaderFontSize: CGFloat = 13
    @ScaledMetric private var emptyStateTitleFontSize: CGFloat = 16
    @ScaledMetric private var emptyStateSubtitleFontSize: CGFloat = 13
```

Find:

```swift
            eyebrowLabel
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(themeTokens.textColor.opacity(0.5))
                .textCase(.uppercase)
            Text(titleLabel)
                .font(.system(size: 32, weight: .heavy))
                .tracking(-0.5)
                .foregroundStyle(themeTokens.textColor)
```

Replace with:

```swift
            eyebrowLabel
                .font(.system(size: eyebrowFontSize, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(themeTokens.textColor.opacity(0.5))
                .textCase(.uppercase)
            Text(titleLabel)
                .font(.system(size: titleFontSize, weight: .heavy))
                .tracking(-0.5)
                .foregroundStyle(themeTokens.textColor)
```

Find:

```swift
            title
                .font(.system(size: 13, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(themeTokens.textColor.opacity(0.5))
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
```

Replace with:

```swift
            title
                .font(.system(size: sectionHeaderFontSize, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(themeTokens.textColor.opacity(0.5))
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
```

Find:

```swift
            Text("No upcoming matches")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(themeTokens.textColor.opacity(0.70))
            Text("Check Fixtures for the full schedule")
                .font(.system(size: 13))
                .foregroundStyle(themeTokens.textColor.opacity(0.45))
```

Replace with:

```swift
            Text("No upcoming matches")
                .font(.system(size: emptyStateTitleFontSize, weight: .semibold))
                .foregroundStyle(themeTokens.textColor.opacity(0.70))
            Text("Check Fixtures for the full schedule")
                .font(.system(size: emptyStateSubtitleFontSize))
                .foregroundStyle(themeTokens.textColor.opacity(0.45))
```

- [ ] **Step 3: Build to verify it compiles**

Run: `rm -rf ~/Library/Developer/Xcode/DerivedData/BR2026-* && xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation clean build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Run the full test suite**

Run: `eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: all existing tests still pass.

- [ ] **Step 5: Commit**

```bash
git add BR2026/Views/Fixtures/FixturesView.swift BR2026/Views/Matchday/MatchdayView.swift
git commit -m "Add Dynamic Type support to Fixtures and Matchday views"
```

---

### Task 5: Match Detail view

**Files:**
- Modify: `BR2026/Views/MatchDetail/MatchDetailView.swift`

- [ ] **Step 1: Add all nine `@ScaledMetric` properties**

Add to the struct's property list (before `var body`):

```swift
    @ScaledMetric private var roundEyebrowFontSize: CGFloat = 12
    @ScaledMetric private var statusLineFontSize: CGFloat = 13
    @ScaledMetric private var halfTimeFontSize: CGFloat = 12
    @ScaledMetric private var venueFontSize: CGFloat = 13
    @ScaledMetric private var teamNameFontSize: CGFloat = 19
    @ScaledMetric private var scoreFontSize: CGFloat = 48
    @ScaledMetric private var vsFontSize: CGFloat = 32
    @ScaledMetric private var timelineHeaderFontSize: CGFloat = 13
    @ScaledMetric private var emptyEventsFontSize: CGFloat = 14
```

- [ ] **Step 2: Replace each call site**

Find:

```swift
            Text("Round \(match.matchday)")
                .font(.system(size: 12, weight: .bold))
                .tracking(1.2)
```

Replace with:

```swift
            Text("Round \(match.matchday)")
                .font(.system(size: roundEyebrowFontSize, weight: .bold))
                .tracking(1.2)
```

Find:

```swift
            statusLine
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(themeTokens.textColor.opacity(0.6))
```

Replace with:

```swift
            statusLine
                .font(.system(size: statusLineFontSize, weight: .semibold))
                .foregroundStyle(themeTokens.textColor.opacity(0.6))
```

Find:

```swift
                halfTimeText
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(themeTokens.textColor.opacity(0.45))
                    .textCase(.uppercase)
```

Replace with:

```swift
                halfTimeText
                    .font(.system(size: halfTimeFontSize, weight: .semibold))
                    .foregroundStyle(themeTokens.textColor.opacity(0.45))
                    .textCase(.uppercase)
```

Find:

```swift
                .font(.system(size: 13))
                .foregroundStyle(themeTokens.textColor.opacity(0.5))
                .accessibilityElement(children: .combine)
```

Replace with:

```swift
                .font(.system(size: venueFontSize))
                .foregroundStyle(themeTokens.textColor.opacity(0.5))
                .accessibilityElement(children: .combine)
```

Find:

```swift
            Text(team.displayName)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(isDimmed ? themeTokens.textColor.opacity(0.45) : themeTokens.textColor)
```

Replace with:

```swift
            Text(team.displayName)
                .font(.system(size: teamNameFontSize, weight: .bold))
                .foregroundStyle(isDimmed ? themeTokens.textColor.opacity(0.45) : themeTokens.textColor)
```

Find:

```swift
            Text("\(home) – \(away)")
                .font(.system(size: 48, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(themeTokens.textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        } else {
            Text("VS")
                .font(.system(size: 32, weight: .heavy))
                .foregroundStyle(themeTokens.textColor.opacity(0.35))
        }
    }
```

Replace with:

```swift
            Text("\(home) – \(away)")
                .font(.system(size: scoreFontSize, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(themeTokens.textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        } else {
            Text("VS")
                .font(.system(size: vsFontSize, weight: .heavy))
                .foregroundStyle(themeTokens.textColor.opacity(0.35))
        }
    }
```

Find:

```swift
            Text("Timeline")
                .font(.system(size: 13, weight: .bold))
                .tracking(0.8)
```

Replace with:

```swift
            Text("Timeline")
                .font(.system(size: timelineHeaderFontSize, weight: .bold))
                .tracking(0.8)
```

Find:

```swift
                Text("No events yet")
                    .font(.system(size: 14))
                    .foregroundStyle(themeTokens.textColor.opacity(0.45))
```

Replace with:

```swift
                Text("No events yet")
                    .font(.system(size: emptyEventsFontSize))
                    .foregroundStyle(themeTokens.textColor.opacity(0.45))
```

- [ ] **Step 3: Build to verify it compiles**

Run: `rm -rf ~/Library/Developer/Xcode/DerivedData/BR2026-* && xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation clean build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Run the full test suite**

Run: `eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: all existing tests still pass.

- [ ] **Step 5: Commit**

```bash
git add BR2026/Views/MatchDetail/MatchDetailView.swift
git commit -m "Add Dynamic Type support to Match Detail view"
```

---

### Task 6: More screen family — MoreView, AppIconPickerView, TeamThemePickerView, TermsOfServiceView

**Files:**
- Modify: `BR2026/Views/More/MoreView.swift`
- Modify: `BR2026/Views/More/AppIconPickerView.swift`
- Modify: `BR2026/Views/More/TeamThemePickerView.swift`
- Modify: `BR2026/Views/More/TermsOfServiceView.swift`

- [ ] **Step 1: `MoreView.swift`**

Add six `@ScaledMetric` properties to the struct's property list (before `var body`):

```swift
    @ScaledMetric private var competitionNameFontSize: CGFloat = 16
    @ScaledMetric private var logoPlaceholderIconSize: CGFloat = 28
    @ScaledMetric private var sectionTitleFontSize: CGFloat = 13
    @ScaledMetric private var rowIconSize: CGFloat = 16
    @ScaledMetric private var rowTitleFontSize: CGFloat = 16
    @ScaledMetric private var chevronIconSize: CGFloat = 13
```

Find:

```swift
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(themeTokens.textColor)
```

Replace with:

```swift
                Text(name)
                    .font(.system(size: competitionNameFontSize, weight: .semibold))
                    .foregroundStyle(themeTokens.textColor)
```

Find:

```swift
                            Image(systemName: "soccerball")
                                .font(.system(size: 28))
                                .foregroundStyle(themeTokens.textColor.opacity(0.55))
```

Replace with:

```swift
                            Image(systemName: "soccerball")
                                .font(.system(size: logoPlaceholderIconSize))
                                .foregroundStyle(themeTokens.textColor.opacity(0.55))
```

Find:

```swift
            Text(section.titleKey)
                .font(.system(size: 13, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(themeTokens.textColor.opacity(0.5))
                .textCase(.uppercase)
```

Replace with:

```swift
            Text(section.titleKey)
                .font(.system(size: sectionTitleFontSize, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(themeTokens.textColor.opacity(0.5))
                .textCase(.uppercase)
```

Find:

```swift
            Image(systemName: row.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 24)
            Text(row.titleKey)
                .font(.system(size: 16, weight: .semibold))
            Spacer()
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(themeTokens.textColor.opacity(0.3))
            }
```

Replace with:

```swift
            Image(systemName: row.systemImage)
                .font(.system(size: rowIconSize, weight: .semibold))
                .frame(width: 24)
            Text(row.titleKey)
                .font(.system(size: rowTitleFontSize, weight: .semibold))
            Spacer()
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: chevronIconSize, weight: .semibold))
                    .foregroundStyle(themeTokens.textColor.opacity(0.3))
            }
```

- [ ] **Step 2: `AppIconPickerView.swift`**

Add six `@ScaledMetric` properties to the struct's property list (before `var body`) — note
`rowTitleFontSize` and `checkmarkIconSize` are each shared between two call sites (the
free-row and team-row variants) per the confirmed grouping:

```swift
    @ScaledMetric private var restoreButtonFontSize: CGFloat = 13
    @ScaledMetric private var errorMessageFontSize: CGFloat = 13
    @ScaledMetric private var rowTitleFontSize: CGFloat = 16
    @ScaledMetric private var checkmarkIconSize: CGFloat = 15
    @ScaledMetric private var lockIconSize: CGFloat = 12
    @ScaledMetric private var priceFontSize: CGFloat = 13
```

Find:

```swift
                    Text("Restore Purchases")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(themeTokens.textColor.opacity(0.55))
```

Replace with:

```swift
                    Text("Restore Purchases")
                        .font(.system(size: restoreButtonFontSize, weight: .semibold))
                        .foregroundStyle(themeTokens.textColor.opacity(0.55))
```

Find:

```swift
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(themeTokens.textColor.opacity(0.55))
```

Replace with:

```swift
                    Text(errorMessage)
                        .font(.system(size: errorMessageFontSize))
                        .foregroundStyle(themeTokens.textColor.opacity(0.55))
```

Find:

```swift
                Text(option.displayName)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }
```

Replace with:

```swift
                Text(option.displayName)
                    .font(.system(size: rowTitleFontSize, weight: .semibold))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: checkmarkIconSize, weight: .semibold))
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }
```

Find:

```swift
                Text(option.displayName)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                teamTrailingSlot(option)
                    .accessibilityHidden(true)
            }
```

Replace with:

```swift
                Text(option.displayName)
                    .font(.system(size: rowTitleFontSize, weight: .semibold))
                Spacer()
                teamTrailingSlot(option)
                    .accessibilityHidden(true)
            }
```

Find:

```swift
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                if let price = viewModel.price(for: option) {
                    Text(price)
                        .font(.system(size: 13, weight: .semibold))
                }
            }
```

Replace with:

```swift
                Image(systemName: "lock.fill")
                    .font(.system(size: lockIconSize, weight: .semibold))
                if let price = viewModel.price(for: option) {
                    Text(price)
                        .font(.system(size: priceFontSize, weight: .semibold))
                }
            }
```

Find:

```swift
        } else if viewModel.isSelected(option) {
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(themeTokens.textColor)
        }
    }
}
```

Replace with:

```swift
        } else if viewModel.isSelected(option) {
            Image(systemName: "checkmark")
                .font(.system(size: checkmarkIconSize, weight: .semibold))
                .foregroundStyle(themeTokens.textColor)
        }
    }
}
```

- [ ] **Step 3: `TeamThemePickerView.swift`**

Add six `@ScaledMetric` properties to the struct's property list (before `var body`):

```swift
    @ScaledMetric private var restoreButtonFontSize: CGFloat = 13
    @ScaledMetric private var errorMessageFontSize: CGFloat = 13
    @ScaledMetric private var rowFontSize: CGFloat = 16
    @ScaledMetric private var lockIconSize: CGFloat = 12
    @ScaledMetric private var priceFontSize: CGFloat = 13
    @ScaledMetric private var checkmarkIconSize: CGFloat = 15
```

Find:

```swift
                    Text("Restore Purchases")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(themeTokens.textColor.opacity(0.55))
```

Replace with:

```swift
                    Text("Restore Purchases")
                        .font(.system(size: restoreButtonFontSize, weight: .semibold))
                        .foregroundStyle(themeTokens.textColor.opacity(0.55))
```

Find:

```swift
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(themeTokens.textColor.opacity(0.55))
```

Replace with:

```swift
                    Text(errorMessage)
                        .font(.system(size: errorMessageFontSize))
                        .foregroundStyle(themeTokens.textColor.opacity(0.55))
```

Find:

```swift
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(themeTokens.textColor)
```

Replace with:

```swift
            .font(.system(size: rowFontSize, weight: .semibold))
            .foregroundStyle(themeTokens.textColor)
```

Find:

```swift
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                if let price = viewModel.price(for: option) {
                    Text(price)
                        .font(.system(size: 13, weight: .semibold))
                }
            }
```

Replace with:

```swift
                Image(systemName: "lock.fill")
                    .font(.system(size: lockIconSize, weight: .semibold))
                if let price = viewModel.price(for: option) {
                    Text(price)
                        .font(.system(size: priceFontSize, weight: .semibold))
                }
            }
```

Find:

```swift
        } else if viewModel.selectedOption == option {
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(themeTokens.textColor)
        }
    }
}
```

Replace with:

```swift
        } else if viewModel.selectedOption == option {
            Image(systemName: "checkmark")
                .font(.system(size: checkmarkIconSize, weight: .semibold))
                .foregroundStyle(themeTokens.textColor)
        }
    }
}
```

- [ ] **Step 4: `TermsOfServiceView.swift`**

Add one `@ScaledMetric` property to the struct's property list (before `var body`):

```swift
    @ScaledMetric private var bodyFontSize: CGFloat = 14
```

Find:

```swift
            Text(String(format: String(localized: "terms_of_service_body"), config.displayName))
                .font(.system(size: 14))
                .foregroundStyle(themeTokens.textColor.opacity(0.85))
```

Replace with:

```swift
            Text(String(format: String(localized: "terms_of_service_body"), config.displayName))
                .font(.system(size: bodyFontSize))
                .foregroundStyle(themeTokens.textColor.opacity(0.85))
```

- [ ] **Step 5: Build to verify it compiles**

Run: `rm -rf ~/Library/Developer/Xcode/DerivedData/BR2026-* && xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation clean build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Run the full test suite**

Run: `eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: all existing tests still pass.

- [ ] **Step 7: Commit**

```bash
git add BR2026/Views/More/MoreView.swift BR2026/Views/More/AppIconPickerView.swift BR2026/Views/More/TeamThemePickerView.swift BR2026/Views/More/TermsOfServiceView.swift
git commit -m "Add Dynamic Type support to the More screen family"
```

---

### Task 7: Standings view + CLAUDE.md documentation update

**Files:**
- Modify: `BR2026/Views/Standings/StandingsView.swift`
- Modify: `CLAUDE.md`

- [ ] **Step 1: `StandingsView.swift`**

Add two `@ScaledMetric` properties to the struct's property list (before `var body`):

```swift
    @ScaledMetric private var columnHeaderFontSize: CGFloat = 11
    @ScaledMetric private var rowFontSize: CGFloat = 14
```

Find:

```swift
    private func columnHeader(_ text: String, width: CGFloat = columnWidth) -> some View {
        Text(text)
            .lineLimit(1)
            .frame(width: width)
            .font(.system(size: 11, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(themeTokens.textColor.opacity(0.5))
    }
```

Replace with:

```swift
    private func columnHeader(_ text: String, width: CGFloat = columnWidth) -> some View {
        Text(text)
            .lineLimit(1)
            .frame(width: width)
            .font(.system(size: columnHeaderFontSize, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(themeTokens.textColor.opacity(0.5))
    }
```

Find:

```swift
        .font(.system(size: 14, weight: .semibold))
        .monospacedDigit()
        .foregroundStyle(themeTokens.textColor)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(standing.accessibilityLabel)
    }
```

Replace with:

```swift
        .font(.system(size: rowFontSize, weight: .semibold))
        .monospacedDigit()
        .foregroundStyle(themeTokens.textColor)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(standing.accessibilityLabel)
    }
```

(Note: `statCell(_:width:emphasized:)`'s `.fontWeight(emphasized ? .heavy : .regular)` — a
separate, pre-existing modifier that overrides weight for the Points column — is unaffected
by this change and must not be touched; it still applies on top of whatever `rowFontSize`
resolves the inherited font's size to.)

- [ ] **Step 2: Update `CLAUDE.md`'s Typography section**

In `CLAUDE.md`, find the Typography section's introductory line (immediately before the
table):

```
### Typography (SF Pro via system font)
```

Replace with:

```
### Typography (SF Pro via system font)

All sizes below are base values at the system's default Dynamic Type content size category —
every font/icon size in the app is wired through `@ScaledMetric` (see `docs/superpowers/specs/
2026-07-17-dynamic-type-design.md`) and responds to the user's text-size setting, capped
app-wide at `.accessibility1`. Letter-tracking values are fixed and do not scale.
```

- [ ] **Step 3: Build to verify it compiles**

Run: `rm -rf ~/Library/Developer/Xcode/DerivedData/BR2026-* && xcodebuild -project BR2026.xcodeproj -scheme BR2026 -destination 'generic/platform=iOS Simulator' -skipMacroValidation clean build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Run the full test suite**

Run: `eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: all existing tests still pass.

- [ ] **Step 5: Commit**

```bash
git add BR2026/Views/Standings/StandingsView.swift CLAUDE.md
git commit -m "Add Dynamic Type support to Standings view; document the change in CLAUDE.md"
```

---

### Task 8: Extend the accessibility audit + full 6-target verification

**Files:**
- Modify: `BR2026UITests/AccessibilityAuditUITests.swift`

**Interfaces:**
- Consumes: all of Tasks 1-7's `@ScaledMetric` wiring — this task is the regression gate for
  all of them, mirroring how Task 11 of the VoiceOver plan closed out that phase.

- [ ] **Step 1: Extend the audit type set**

In `BR2026UITests/AccessibilityAuditUITests.swift`, find:

```swift
    private static let auditTypes: XCUIAccessibilityAuditType = [
        .sufficientElementDescription, .trait, .elementDetection
    ]
```

Replace with:

```swift
    private static let auditTypes: XCUIAccessibilityAuditType = [
        .sufficientElementDescription, .trait, .elementDetection, .dynamicType, .textClipped
    ]
```

- [ ] **Step 2: Run the full unit + UI test suite (fully clean)**

Run: `rm -rf ~/Library/Developer/Xcode/DerivedData/BR2026-* && eval "$(rbenv init -)" && bundle exec fastlane test app:br2026`
Expected: all tests pass, including the existing 7 UI audit tests now also checking
`.dynamicType`/`.textClipped` across all 7 screens.

**If any audit finds a real issue** (a text element that doesn't respond to Dynamic Type, or
clips/truncates at a larger size) that Tasks 1-7 should have already fixed: treat it as a
regression in this plan's own work, following this project's systematic-debugging
convention — read the actual audit failure output (it names the specific element and issue),
find the corresponding SwiftUI view code, and fix it properly. Do NOT weaken `auditTypes`,
skip the failing test, or delete/loosen an assertion to route around a real finding. If a
finding requires a fix outside this task's own file list, that's expected and fine — report
exactly what you changed and why, the same way Task 11 handled its own real finding
(Standings' header row).

- [ ] **Step 3: Build all 6 targets (fully clean)**

Run (repeat for each scheme — `BR2026`, `PremierLeague2026`, `Ligue12026`,
`PrimeiraLiga2026`, `ScottishPremiership2026`, `LaLiga2026`):

```bash
xcodebuild -project BR2026.xcodeproj -scheme <Scheme> -destination 'generic/platform=iOS Simulator' -skipMacroValidation clean build
```

Expected: `** BUILD SUCCEEDED **` for all six — confirms Tasks 1-7's `@ScaledMetric`
additions (all in shared files) don't break any of the other 5 white-label targets.

- [ ] **Step 4: Manual verification**

On a simulator or device, adjust Settings → Accessibility → Display & Text Size → Larger
Text to a large setting (and separately, to the smallest setting). Confirm across Matchday,
Fixtures, Standings, More, Match Detail, and both pickers: text and icons visibly grow/shrink
proportionally, nothing clips or overlaps at the capped maximum
(`.accessibility1`)-equivalent system setting, and the app looks visually identical to before
this plan at the system's default text size setting.

- [ ] **Step 5: Commit**

```bash
git add BR2026UITests/AccessibilityAuditUITests.swift
git commit -m "Extend accessibility audit to cover Dynamic Type and text clipping"
```

---
