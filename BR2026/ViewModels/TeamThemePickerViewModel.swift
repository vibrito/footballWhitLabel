import Foundation
import Observation

@Observable
@MainActor
final class TeamThemePickerViewModel {
    private(set) var selectedOption: TeamThemeOption?
    private(set) var errorMessage: String?
    private let themeStore: TeamThemeStore
    private let setting: TeamThemeSetting

    init(themeStore: TeamThemeStore, setting: TeamThemeSetting) {
        self.themeStore = themeStore
        self.setting = setting
        selectedOption = TeamThemeOption.allCases.first { $0.rawValue == setting.selectedThemeID }
    }

    func select(_ option: TeamThemeOption?) async {
        guard option != selectedOption else { return }
        guard await themeStore.select(option) else {
            errorMessage = String(localized: "Couldn't apply that team's colors. Try again.")
            return
        }
        selectedOption = option
        errorMessage = nil
    }
}
