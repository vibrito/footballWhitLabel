import Testing
import SwiftUI
@testable import BR2026

@Suite("TeamThemeStore")
@MainActor
struct TeamThemeStoreTests {
    private let palmeirasColors = TeamThemeColorSet(
        home: TeamThemeColors(mainColorHex: "225638", fontColorHex: "ffffff"),
        away: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "035336"),
        third: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "2c5434")
    )

    @Test("loadOnce() with no persisted selection leaves tokens at today's defaults")
    func loadOnceWithNoSelectionStaysDefault() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        let store = TeamThemeStore(setting: setting, service: service)

        await store.loadOnce()

        #expect(store.tokens == ThemeTokens())
    }

    @Test("loadOnce() with a persisted palmeirasHome selection resolves that kit's tokens")
    func loadOnceWithPersistedSelectionResolvesTokens() async {
        let setting = StubTeamThemeSetting(selectedThemeID: TeamThemeOption.palmeirasHome.rawValue)
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)

        await store.loadOnce()

        #expect(store.tokens.overrideAccentColor == Color(hex: "225638"))
        #expect(store.tokens.textColor == Color(hex: "ffffff"))
    }

    @Test("select() resolves the matching kit's colors, not always home")
    func selectResolvesMatchingKit() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)

        let succeeded = await store.select(.palmeirasAway)

        #expect(succeeded == true)
        #expect(store.tokens.overrideAccentColor == Color(hex: "ffffff"))
        #expect(store.tokens.textColor == Color(hex: "035336"))
        #expect(setting.selectedThemeID == TeamThemeOption.palmeirasAway.rawValue)
    }

    @Test("select() falls back to fetching when there's no cached entry, and still succeeds")
    func selectFetchesWhenCacheMisses() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.teamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)

        let succeeded = await store.select(.palmeirasHome)

        #expect(succeeded == true)
        #expect(service.fetchTeamThemeColorSetCallCount == 1)
        #expect(store.tokens.overrideAccentColor == Color(hex: "225638"))
    }

    @Test("select(nil) returns tokens to today's defaults and clears the persisted selection")
    func selectNilResetsToDefault() async {
        let setting = StubTeamThemeSetting(selectedThemeID: TeamThemeOption.palmeirasHome.rawValue)
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)
        await store.loadOnce()

        let succeeded = await store.select(nil)

        #expect(succeeded == true)
        #expect(store.tokens == ThemeTokens())
        #expect(setting.selectedThemeID == nil)
    }

    @Test("select() returns false and leaves tokens/persisted id unchanged when both cache and fetch fail")
    func selectFailsWhenResolutionFails() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.shouldThrowOnTeamThemeFetch = true
        let store = TeamThemeStore(setting: setting, service: service)

        let succeeded = await store.select(.palmeirasHome)

        #expect(succeeded == false)
        #expect(store.tokens == ThemeTokens())
        #expect(setting.selectedThemeID == nil)
    }
}

final class StubTeamThemeSetting: TeamThemeSetting {
    private(set) var selectedThemeID: String?

    init(selectedThemeID: String? = nil) {
        self.selectedThemeID = selectedThemeID
    }

    func setSelectedThemeID(_ id: String?) {
        selectedThemeID = id
    }
}
