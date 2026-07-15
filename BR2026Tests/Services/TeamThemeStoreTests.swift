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

    @Test("select() resolves the home kit's colors from a cache hit")
    func selectResolvesFromCache() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)

        let succeeded = await store.select(.palmeirasHome)

        #expect(succeeded == true)
        #expect(store.tokens.overrideAccentColor == Color(hex: "225638"))
        #expect(store.tokens.textColor == Color(hex: "ffffff"))
        #expect(setting.selectedThemeID == TeamThemeOption.palmeirasHome.rawValue)
    }

    @Test("select() threads the option's gradientStyle into the resolved tokens")
    func selectThreadsGradientStyle() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = TeamThemeColorSet(
            home: TeamThemeColors(mainColorHex: "fcfbee", fontColorHex: "000000")
        )
        let store = TeamThemeStore(setting: setting, service: service)

        _ = await store.select(.corinthiansHome)

        #expect(store.tokens.gradientCenter == .center)
        #expect(store.tokens.gradientEndRadius == 320)
    }

    @Test("select() uses the option's curated accentOverrideHex instead of the near-white mainColorHex")
    func selectUsesAccentOverride() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = TeamThemeColorSet(
            home: TeamThemeColors(mainColorHex: "fcfbee", fontColorHex: "000000")
        )
        let store = TeamThemeStore(setting: setting, service: service)

        _ = await store.select(.corinthiansHome)

        #expect(store.tokens.overrideAccentColor == Color(hex: TeamThemeOption.corinthiansHome.accentOverrideHex!))
        #expect(store.tokens.overrideAccentColor != Color(hex: "fcfbee"))
        // The background gradient still reflects the actual (near-white) mainColorHex.
        #expect(store.tokens.gradientStops[0] == Color(hex: "fcfbee"))
    }

    @Test("select() falls back to the fetched mainColorHex as accent when accentOverrideHex is nil")
    func selectFallsBackToMainColorAsAccent() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)

        _ = await store.select(.palmeirasHome)

        #expect(store.tokens.overrideAccentColor == Color(hex: "225638"))
    }

    @Test("select() defaults to a top-anchored gradient for options that don't request centering")
    func selectDefaultsToTopAnchoredGradient() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)

        _ = await store.select(.palmeirasHome)

        #expect(store.tokens.gradientCenter == .top)
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
