import Testing
import Foundation
@testable import BR2026

@Suite("UserDefaultsTeamThemeSetting")
@MainActor
struct TeamThemeSettingTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "TeamThemeSettingTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test("selectedThemeID is nil when nothing has been set")
    func nilByDefault() {
        let setting = UserDefaultsTeamThemeSetting(defaults: makeDefaults())
        #expect(setting.selectedThemeID == nil)
    }

    @Test("setSelectedThemeID persists and can be read back")
    func setAndReadBack() {
        let setting = UserDefaultsTeamThemeSetting(defaults: makeDefaults())
        setting.setSelectedThemeID("palmeirasHome")
        #expect(setting.selectedThemeID == "palmeirasHome")
    }

    @Test("setSelectedThemeID(nil) clears a previous selection")
    func clearSelection() {
        let setting = UserDefaultsTeamThemeSetting(defaults: makeDefaults())
        setting.setSelectedThemeID("palmeirasHome")
        setting.setSelectedThemeID(nil)
        #expect(setting.selectedThemeID == nil)
    }
}
