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
        tokens = ThemeTokens.themed(
            mainColorHex: option.mainColorOverrideHex ?? colors.mainColorHex,
            fontColorHex: option.fontColorOverrideHex ?? colors.fontColorHex,
            tabSelectionColorHex: option.tabSelectionColorOverrideHex,
            pillFillColorHex: option.pillFillColorOverrideHex,
            gradientDarkAmount: option.gradientDarkAmountOverride ?? -0.75,
            usesDiagonalSashBackground: option.usesDiagonalSashBackground,
            gradientOuterColorHex: option.gradientOuterColorOverrideHex,
            usesSymmetricBottomGlow: option.usesSymmetricBottomGlow
        )
        return true
    }

    private func apply(_ option: TeamThemeOption) async {
        guard let colors = await resolveColors(teamID: option.teamID)?[option.kit] else { return }
        tokens = ThemeTokens.themed(
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

    private func resolveColors(teamID: Int) async -> TeamThemeColorSet? {
        if let cached = service.cachedTeamThemeColorSet(teamID: teamID) { return cached }
        return try? await service.fetchTeamThemeColorSet(teamID: teamID)
    }
}
