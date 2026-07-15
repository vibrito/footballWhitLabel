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

    init(themeStore: TeamThemeStore, purchaseStore: TeamPurchaseStore, setting: TeamThemeSetting) {
        self.themeStore = themeStore
        self.purchaseStore = purchaseStore
        self.setting = setting
        selectedOption = TeamThemeOption.allCases.first { $0.rawValue == setting.selectedThemeID }
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
