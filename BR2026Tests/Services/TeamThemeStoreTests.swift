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

    @Test("loadOnce() with a persisted palmeirasHome selection resolves that kit's tokens, using the curated override over the API's mainColorHex")
    func loadOnceWithPersistedSelectionResolvesTokens() async {
        let setting = StubTeamThemeSetting(selectedThemeID: TeamThemeOption.palmeirasHome.rawValue)
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)

        await store.loadOnce()

        #expect(store.tokens.overrideAccentColor == Color(hex: "006437"))
        #expect(store.tokens.overrideAccentColor != Color(hex: "225638"))
        #expect(store.tokens.textColor == Color(hex: "ffffff"))
    }

    @Test("select() resolves the home kit's colors from a cache hit, using the curated override over the API's mainColorHex")
    func selectResolvesFromCache() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)

        let succeeded = await store.select(.palmeirasHome)

        #expect(succeeded == true)
        #expect(store.tokens.overrideAccentColor == Color(hex: "006437"))
        #expect(store.tokens.overrideAccentColor != Color(hex: "225638"))
        #expect(store.tokens.textColor == Color(hex: "ffffff"))
        #expect(setting.selectedThemeID == TeamThemeOption.palmeirasHome.rawValue)
    }

    @Test("select() uses Flamengo's curated main color override instead of the API's mainColorHex")
    func selectUsesFlamengoColorOverrides() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = TeamThemeColorSet(
            home: TeamThemeColors(mainColorHex: "ab1b10", fontColorHex: "ffffff")
        )
        let store = TeamThemeStore(setting: setting, service: service)

        _ = await store.select(.flamengoHome)

        #expect(store.tokens.overrideAccentColor == Color(hex: "C52613"))
        #expect(store.tokens.overrideAccentColor != Color(hex: "ab1b10"))
    }

    @Test("select() uses Fluminense's curated main/tab-selection color overrides instead of the API's mainColorHex")
    func selectUsesFluminenseColorOverrides() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = TeamThemeColorSet(
            home: TeamThemeColors(mainColorHex: "6e202e", fontColorHex: "ffffff")
        )
        let store = TeamThemeStore(setting: setting, service: service)

        _ = await store.select(.fluminenseHome)

        #expect(store.tokens.overrideAccentColor == Color(hex: "870A28"))
        #expect(store.tokens.overrideAccentColor != Color(hex: "6e202e"))
        #expect(store.tokens.overrideTabSelectionColor == Color(hex: "00613C"))
    }

    @Test("select() leaves overrideTabSelectionColor nil for options without a tab selection override")
    func selectLeavesTabSelectionColorNilByDefault() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)

        _ = await store.select(.palmeirasHome)

        #expect(store.tokens.overrideTabSelectionColor == nil)
    }

    @Test("select() uses Athletico Paranaense's curated main/font color overrides instead of the API's values")
    func selectUsesAthleticoParanaenseColorOverrides() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = TeamThemeColorSet(
            home: TeamThemeColors(mainColorHex: "cc0000", fontColorHex: "6c6360")
        )
        let store = TeamThemeStore(setting: setting, service: service)

        _ = await store.select(.athleticoParanaenseHome)

        #expect(store.tokens.overrideAccentColor == Color(hex: "CE181E"))
        #expect(store.tokens.overrideAccentColor != Color(hex: "cc0000"))
        #expect(store.tokens.textColor == Color(hex: "F2F2F2"))
        #expect(store.tokens.textColor != Color(hex: "6c6360"))
    }

    @Test("select() uses Bahia's curated main/tab-selection/font color overrides instead of the API's values")
    func selectUsesBahiaColorOverrides() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = TeamThemeColorSet(
            home: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "043a73")
        )
        let store = TeamThemeStore(setting: setting, service: service)

        _ = await store.select(.bahiaHome)

        #expect(store.tokens.overrideAccentColor == Color(hex: "006CB5"))
        #expect(store.tokens.overrideAccentColor != Color(hex: "ffffff"))
        #expect(store.tokens.overrideTabSelectionColor == Color(hex: "ED3237"))
        #expect(store.tokens.textColor == Color(hex: "F2F2F2"))
        #expect(store.tokens.textColor != Color(hex: "043a73"))
    }

    @Test("select() uses Red Bull Bragantino's curated main/tab-selection/font color overrides instead of the API's values")
    func selectUsesRedBullBragantinoColorOverrides() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = TeamThemeColorSet(
            home: TeamThemeColors(mainColorHex: "fcfcfc", fontColorHex: "f50000")
        )
        let store = TeamThemeStore(setting: setting, service: service)

        _ = await store.select(.redBullBragantinoHome)

        #expect(store.tokens.overrideAccentColor == Color(hex: "001D46"))
        #expect(store.tokens.overrideAccentColor != Color(hex: "fcfcfc"))
        #expect(store.tokens.overrideTabSelectionColor == Color(hex: "D2003C"))
        #expect(store.tokens.textColor == Color(hex: "FFFFFF"))
        #expect(store.tokens.textColor != Color(hex: "f50000"))
    }

    @Test("select() uses Coritiba's curated main/font color overrides, with tab-selection falling back to the main color")
    func selectUsesCoritibaColorOverrides() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = TeamThemeColorSet(
            home: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "000000")
        )
        let store = TeamThemeStore(setting: setting, service: service)

        _ = await store.select(.coritibaHome)

        #expect(store.tokens.overrideAccentColor == Color(hex: "00544D"))
        #expect(store.tokens.overrideAccentColor != Color(hex: "ffffff"))
        #expect(store.tokens.overrideTabSelectionColor == nil)
        #expect(store.tokens.textColor == Color(hex: "F2F2F2"))
        #expect(store.tokens.textColor != Color(hex: "000000"))
    }

    @Test("select() uses São Paulo's curated main/tab-selection/font color overrides instead of the API's values")
    func selectUsesSaoPauloColorOverrides() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = TeamThemeColorSet(
            home: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "000000")
        )
        let store = TeamThemeStore(setting: setting, service: service)

        _ = await store.select(.saoPauloHome)

        #expect(store.tokens.overrideAccentColor == Color(hex: "FE0000"))
        #expect(store.tokens.overrideAccentColor != Color(hex: "ffffff"))
        #expect(store.tokens.overrideTabSelectionColor == Color(hex: "000000"))
        #expect(store.tokens.textColor == Color(hex: "FFFFFF"))
        #expect(store.tokens.textColor != Color(hex: "000000"))
    }

    @Test("select() uses Atlético Mineiro's curated charcoal main color override instead of the API's literal black")
    func selectUsesAtleticoMineiroColorOverrides() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = TeamThemeColorSet(
            home: TeamThemeColors(mainColorHex: "000000", fontColorHex: "ffffff")
        )
        let store = TeamThemeStore(setting: setting, service: service)

        _ = await store.select(.atleticoMineiroHome)

        #expect(store.tokens.overrideAccentColor == Color(hex: "2B2B2E"))
        #expect(store.tokens.overrideAccentColor != Color(hex: "000000"))
        #expect(store.tokens.overrideTabSelectionColor == Color(hex: "FFFFFF"))
        #expect(store.tokens.overridePillFillColor == Color(hex: "2B2B2E"))
        #expect(store.tokens.textColor == Color(hex: "ffffff"))
    }

    @Test("select() uses Corinthians's curated main/pill-fill/font color overrides, with tab-selection falling back to the main color")
    func selectUsesCorinthiansColorOverrides() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = TeamThemeColorSet(
            home: TeamThemeColors(mainColorHex: "fcfbee", fontColorHex: "000000")
        )
        let store = TeamThemeStore(setting: setting, service: service)

        _ = await store.select(.corinthiansHome)

        #expect(store.tokens.overrideAccentColor == Color(hex: "6E6E6C"))
        #expect(store.tokens.overrideAccentColor != Color(hex: "fcfbee"))
        #expect(store.tokens.overrideTabSelectionColor == nil)
        #expect(store.tokens.overridePillFillColor == Color(hex: "000000"))
        #expect(store.tokens.textColor == Color(hex: "F2F2F2"))
        #expect(store.tokens.textColor != Color(hex: "000000"))
    }

    @Test("select() uses Cruzeiro's curated main color override instead of the API's mainColorHex")
    func selectUsesCruzeiroColorOverrides() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = TeamThemeColorSet(
            home: TeamThemeColors(mainColorHex: "0455a3", fontColorHex: "ffffff")
        )
        let store = TeamThemeStore(setting: setting, service: service)

        _ = await store.select(.cruzeiroHome)

        #expect(store.tokens.overrideAccentColor == Color(hex: "2F529E"))
        #expect(store.tokens.overrideAccentColor != Color(hex: "0455a3"))
        #expect(store.tokens.overrideTabSelectionColor == nil)
        #expect(store.tokens.textColor == Color(hex: "ffffff"))
        #expect(store.tokens.gradientStops[2] == Color.shaded(hex: "2F529E", towardWhite: -0.5))
        #expect(store.tokens.gradientStops[2] != Color.shaded(hex: "2F529E", towardWhite: -0.75))
    }

    @Test("select() uses Internacional's curated main color override instead of the API's mainColorHex")
    func selectUsesInternacionalColorOverrides() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = TeamThemeColorSet(
            home: TeamThemeColors(mainColorHex: "e00618", fontColorHex: "ffffff")
        )
        let store = TeamThemeStore(setting: setting, service: service)

        _ = await store.select(.internacionalHome)

        #expect(store.tokens.overrideAccentColor == Color(hex: "E5050F"))
        #expect(store.tokens.overrideAccentColor != Color(hex: "e00618"))
        #expect(store.tokens.overrideTabSelectionColor == nil)
        #expect(store.tokens.textColor == Color(hex: "ffffff"))
        #expect(store.tokens.gradientStops[2] == Color.shaded(hex: "E5050F", towardWhite: -0.75))
    }

    @Test("select() uses Remo's curated main color override — a lightened navy — instead of the API's literal black")
    func selectUsesRemoColorOverrides() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = TeamThemeColorSet(
            home: TeamThemeColors(mainColorHex: "000000", fontColorHex: "ffffff")
        )
        let store = TeamThemeStore(setting: setting, service: service)

        _ = await store.select(.remoHome)

        #expect(store.tokens.overrideAccentColor == Color(hex: "2048A8"))
        #expect(store.tokens.overrideAccentColor != Color(hex: "000000"))
        #expect(store.tokens.overrideTabSelectionColor == nil)
        #expect(store.tokens.textColor == Color(hex: "ffffff"))
    }

    @Test("select() uses Botafogo's curated charcoal/white overrides, same recipe as Atlético Mineiro but darker, instead of the API's near-white main color")
    func selectUsesBotafogoColorOverrides() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = TeamThemeColorSet(
            home: TeamThemeColors(mainColorHex: "f7f7f7", fontColorHex: "ffffff")
        )
        let store = TeamThemeStore(setting: setting, service: service)

        _ = await store.select(.botafogoHome)

        #expect(store.tokens.overrideAccentColor == Color(hex: "1E1E20"))
        #expect(store.tokens.overrideAccentColor != Color(hex: "f7f7f7"))
        #expect(store.tokens.overrideAccentColor != Color(hex: "2B2B2E"))
        #expect(store.tokens.overrideTabSelectionColor == Color(hex: "FFFFFF"))
        #expect(store.tokens.overridePillFillColor == Color(hex: "1E1E20"))
        #expect(store.tokens.textColor == Color(hex: "ffffff"))
    }

    @Test("select() uses Vitória's API red as-is, with no curated overrides needed")
    func selectUsesVitoriaColorsAsIs() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = TeamThemeColorSet(
            home: TeamThemeColors(mainColorHex: "ff0000", fontColorHex: "ffffff")
        )
        let store = TeamThemeStore(setting: setting, service: service)

        _ = await store.select(.vitoriaHome)

        #expect(store.tokens.overrideAccentColor == Color(hex: "ff0000"))
        #expect(store.tokens.overrideTabSelectionColor == nil)
        #expect(store.tokens.overridePillFillColor == nil)
        #expect(store.tokens.textColor == Color(hex: "ffffff"))
    }

    @Test("select() uses Mirassol's curated yellow/green/white overrides instead of the API's blown-out yellow and illegible dark-green font")
    func selectUsesMirassolColorOverrides() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = TeamThemeColorSet(
            home: TeamThemeColors(mainColorHex: "ffff00", fontColorHex: "076450")
        )
        let store = TeamThemeStore(setting: setting, service: service)

        _ = await store.select(.mirassolHome)

        #expect(store.tokens.overrideAccentColor == Color(hex: "9E9906"))
        #expect(store.tokens.overrideAccentColor != Color(hex: "ffff00"))
        #expect(store.tokens.overrideTabSelectionColor == Color(hex: "126F3D"))
        #expect(store.tokens.textColor == Color(hex: "FFFFFF"))
        #expect(store.tokens.textColor != Color(hex: "076450"))
    }

    @Test("select() uses Chapecoense's curated main color override instead of the API's near-white mainColorHex")
    func selectUsesChapecoenseColorOverrides() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = TeamThemeColorSet(
            home: TeamThemeColors(mainColorHex: "f9fbfa", fontColorHex: "ffffff")
        )
        let store = TeamThemeStore(setting: setting, service: service)

        _ = await store.select(.chapecoenseHome)

        #expect(store.tokens.overrideAccentColor == Color(hex: "1B552A"))
        #expect(store.tokens.overrideAccentColor != Color(hex: "f9fbfa"))
        #expect(store.tokens.overrideTabSelectionColor == nil)
        #expect(store.tokens.overridePillFillColor == nil)
        #expect(store.tokens.textColor == Color(hex: "ffffff"))
    }

    @Test("select() uses Santos's curated main/pill-fill/font color overrides — a lighter gray than Corinthians — instead of the API's near-white main color")
    func selectUsesSantosColorOverrides() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = TeamThemeColorSet(
            home: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "000000")
        )
        let store = TeamThemeStore(setting: setting, service: service)

        _ = await store.select(.santosHome)

        #expect(store.tokens.overrideAccentColor == Color(hex: "82827F"))
        #expect(store.tokens.overrideAccentColor != Color(hex: "ffffff"))
        #expect(store.tokens.overrideAccentColor != Color(hex: "6E6E6C"))
        #expect(store.tokens.overrideTabSelectionColor == nil)
        #expect(store.tokens.overridePillFillColor == Color(hex: "000000"))
        #expect(store.tokens.textColor == Color(hex: "F2F2F2"))
        #expect(store.tokens.textColor != Color(hex: "000000"))
    }

    @Test("select() uses Grêmio's curated main color override instead of the API's pale sampled blue")
    func selectUsesGremioColorOverrides() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = TeamThemeColorSet(
            home: TeamThemeColors(mainColorHex: "b8edff", fontColorHex: "ffffff")
        )
        let store = TeamThemeStore(setting: setting, service: service)

        _ = await store.select(.gremioHome)

        #expect(store.tokens.overrideAccentColor == Color(hex: "0D80BF"))
        #expect(store.tokens.overrideAccentColor != Color(hex: "b8edff"))
        #expect(store.tokens.overrideTabSelectionColor == nil)
        #expect(store.tokens.overridePillFillColor == nil)
        #expect(store.tokens.textColor == Color(hex: "ffffff"))
    }

    @Test("select() uses Vasco da Gama's curated charcoal overrides and switches on the diagonal sash background")
    func selectUsesVascoDaGamaColorOverrides() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = TeamThemeColorSet(
            home: TeamThemeColors(mainColorHex: "000000", fontColorHex: "ffffff")
        )
        let store = TeamThemeStore(setting: setting, service: service)

        _ = await store.select(.vascoDaGamaHome)

        #expect(store.tokens.overrideAccentColor == Color(hex: "242426"))
        #expect(store.tokens.overrideTabSelectionColor == Color(hex: "FFFFFF"))
        #expect(store.tokens.overridePillFillColor == Color(hex: "242426"))
        #expect(store.tokens.textColor == Color(hex: "ffffff"))
        #expect(store.tokens.usesDiagonalSashBackground == true)
    }

    @Test("select() leaves usesDiagonalSashBackground false for teams other than Vasco da Gama")
    func selectLeavesDiagonalSashBackgroundFalseByDefault() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)

        _ = await store.select(.palmeirasHome)

        #expect(store.tokens.usesDiagonalSashBackground == false)
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
        #expect(store.tokens.overrideAccentColor == Color(hex: "006437"))
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

    @Test("loadOnce() with a persisted selection populates selectedOption")
    func loadOnceSetsSelectedOption() async {
        let setting = StubTeamThemeSetting(selectedThemeID: TeamThemeOption.palmeirasHome.rawValue)
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)

        await store.loadOnce()

        #expect(store.selectedOption == .palmeirasHome)
    }

    @Test("loadOnce() with no persisted selection leaves selectedOption nil")
    func loadOnceWithNoSelectionLeavesSelectedOptionNil() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        let store = TeamThemeStore(setting: setting, service: service)

        await store.loadOnce()

        #expect(store.selectedOption == nil)
    }

    @Test("select() updates selectedOption to the newly selected option")
    func selectUpdatesSelectedOption() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)

        await store.select(.palmeirasHome)

        #expect(store.selectedOption == .palmeirasHome)
    }

    @Test("select(nil) clears selectedOption back to nil")
    func selectNilClearsSelectedOption() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)
        await store.select(.palmeirasHome)
        #expect(store.selectedOption == .palmeirasHome)

        await store.select(nil)

        #expect(store.selectedOption == nil)
    }

    @Test("select() leaves selectedOption unchanged when color resolution fails")
    func selectLeavesSelectedOptionUnchangedOnFailure() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        // No cachedTeamThemeColorSetOverride set, and fetchTeamThemeColorSet's default
        // StubMatchService behavior throws unless an override is provided — matches the
        // existing "both cache and fetch fail" test's setup.
        let store = TeamThemeStore(setting: setting, service: service)

        let succeeded = await store.select(.palmeirasHome)

        #expect(succeeded == false)
        #expect(store.selectedOption == nil)
    }

    @Test("select() preserves a prior successful selection when a later select() call fails")
    func selectPreservesPriorSelectionOnLaterFailure() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)
        let firstSucceeded = await store.select(.palmeirasHome)
        #expect(firstSucceeded == true)
        #expect(store.selectedOption == .palmeirasHome)

        // Remove the cache hit so the next select() falls through to fetch, which throws
        // since no fetch override is configured — simulating a later failed attempt.
        service.cachedTeamThemeColorSetOverride = nil
        let secondSucceeded = await store.select(.flamengoHome)

        #expect(secondSucceeded == false)
        #expect(store.selectedOption == .palmeirasHome)
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
