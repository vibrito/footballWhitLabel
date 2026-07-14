import Foundation

@MainActor
protocol TeamThemeSetting {
    var selectedThemeID: String? { get }
    func setSelectedThemeID(_ id: String?)
}

@MainActor
final class UserDefaultsTeamThemeSetting: TeamThemeSetting {
    private let defaults: UserDefaults
    private let key = "selectedTeamThemeID"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selectedThemeID: String? { defaults.string(forKey: key) }

    func setSelectedThemeID(_ id: String?) {
        defaults.set(id, forKey: key)
    }
}
