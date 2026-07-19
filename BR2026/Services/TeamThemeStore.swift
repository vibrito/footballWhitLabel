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
