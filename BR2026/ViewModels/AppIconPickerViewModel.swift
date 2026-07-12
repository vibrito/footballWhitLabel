import Foundation
import Observation

@Observable
@MainActor
final class AppIconPickerViewModel {
    private(set) var selectedIcon: AppIconOption
    private(set) var errorMessage: String?
    private let iconSetting: AppIconSetting

    init(iconSetting: AppIconSetting) {
        self.iconSetting = iconSetting
        let currentName = iconSetting.currentIconName
        selectedIcon = AppIconOption.allCases.first { $0.iconAssetName == currentName } ?? .light
    }

    func select(_ option: AppIconOption) async {
        guard option != selectedIcon else { return }
        do {
            try await iconSetting.setIconName(option.iconAssetName)
            selectedIcon = option
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Couldn't change the app icon. Try again.")
        }
    }
}
