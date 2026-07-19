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
                    // This hint describes a sighted-only gesture — VoiceOver's actual
                    // equivalent is each row's "Preview" custom action (discoverable via
                    // the actions rotor), not a literal long press, so the hint doesn't
                    // apply and would just be confusing noise if spoken.
                    .accessibilityHidden(true)
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
        // Animates every effectiveTokens-driven color change on this screen (background,
        // row text, hint, buttons) when previewState changes — both engaging a preview and
        // reverting back snap smoothly instead of an instant color jump.
        .animation(.easeInOut(duration: 0.3), value: previewState)
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
