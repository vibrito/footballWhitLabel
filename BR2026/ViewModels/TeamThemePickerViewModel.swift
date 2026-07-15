import Foundation
import Observation

@Observable
@MainActor
final class TeamThemePickerViewModel {
    private(set) var selectedOption: TeamThemeOption?
    private(set) var errorMessage: String?
    private let themeStore: TeamThemeStore
    private let purchaseStore: TeamPurchaseStore
    private let setting: TeamThemeSetting
    private let service: MatchService

    init(themeStore: TeamThemeStore, purchaseStore: TeamPurchaseStore, setting: TeamThemeSetting, service: MatchService) {
        self.themeStore = themeStore
        self.purchaseStore = purchaseStore
        self.setting = setting
        self.service = service
        selectedOption = TeamThemeOption.allCases.first { $0.rawValue == setting.selectedThemeID }
    }

    /// Purchased teams first (so a user's own themes are easy to find), then unpurchased
    /// teams — each group ordered by current league standings position (using whatever's
    /// already cached, no network fetch) rather than the enum's declaration order, which
    /// carries no real-world meaning. A team with no cached standings row (e.g. not yet
    /// loaded) sorts to the end of its group rather than crashing or reordering unpredictably.
    var sortedOptions: [TeamThemeOption] {
        let positionsByTeamID = Dictionary(uniqueKeysWithValues: service.cachedStandings().map { ($0.teamID, $0.position) })
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
