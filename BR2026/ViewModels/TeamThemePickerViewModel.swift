import Foundation
import Observation

@Observable
@MainActor
final class TeamThemePickerViewModel {
    private(set) var selectedOption: TeamThemeOption?
    private(set) var errorMessage: String?
    private(set) var standings: [Standing]
    private let themeStore: TeamThemeStore
    private let purchaseStore: PurchaseStore<TeamThemeOption>
    private let setting: TeamThemeSetting
    private let service: MatchService
    private var hasLoadedStandingsOnce = false

    init(themeStore: TeamThemeStore, purchaseStore: PurchaseStore<TeamThemeOption>, setting: TeamThemeSetting, service: MatchService) {
        self.themeStore = themeStore
        self.purchaseStore = purchaseStore
        self.setting = setting
        self.service = service
        selectedOption = TeamThemeOption.allCases.first { $0.rawValue == setting.selectedThemeID }
        standings = service.cachedStandings()
    }

    /// Same cached-then-refresh pattern as `StandingsViewModel.loadOnce()`: `standings`
    /// already shows whatever's cached (set in `init`) so `sortedOptions` is never empty on
    /// first render, then this fetches fresh standings once per session — needed because a
    /// user can reach More → Team Theme without ever visiting the Standings tab, in which
    /// case nothing else in the app would have populated the standings cache yet.
    func loadOnce() async {
        guard !hasLoadedStandingsOnce else { return }
        hasLoadedStandingsOnce = true
        if let fresh = try? await service.fetchStandings() {
            standings = fresh
        }
    }

    /// Purchased teams first (so a user's own themes are easy to find), then unpurchased
    /// teams — each group ordered by current league standings position rather than the
    /// enum's declaration order, which carries no real-world meaning. A team with no
    /// standings row (e.g. not yet loaded) sorts to the end of its group rather than
    /// crashing or reordering unpredictably.
    var sortedOptions: [TeamThemeOption] {
        let positionsByTeamID = Dictionary(standings.map { ($0.teamID, $0.position) }, uniquingKeysWith: { first, _ in first })
        return TeamThemeOption.allCases.sorted { lhs, rhs in
            let lhsPurchased = purchaseStore.isPurchased(lhs)
            let rhsPurchased = purchaseStore.isPurchased(rhs)
            guard lhsPurchased == rhsPurchased else { return lhsPurchased }
            let lhsPosition = positionsByTeamID[lhs.teamID] ?? Int.max
            let rhsPosition = positionsByTeamID[rhs.teamID] ?? Int.max
            return lhsPosition < rhsPosition
        }
    }

    func isPurchased(_ option: TeamThemeOption) -> Bool {
        purchaseStore.isPurchased(option)
    }

    func price(for option: TeamThemeOption) -> String? {
        purchaseStore.price(for: option)
    }

    func previewTokens(for option: TeamThemeOption?) async -> ThemeTokens? {
        await themeStore.previewTokens(for: option)
    }

    func select(_ option: TeamThemeOption?) async {
        guard option != selectedOption else { return }
        errorMessage = nil
        if let option, !purchaseStore.isPurchased(option) {
            guard await purchaseStore.purchase(option) else { return }
        }
        guard await themeStore.select(option) else {
            errorMessage = String(localized: "Couldn't apply that team's colors. Try again.")
            return
        }
        selectedOption = option
        errorMessage = nil
    }

    func restorePurchases() async {
        await purchaseStore.restorePurchases()
    }
}
