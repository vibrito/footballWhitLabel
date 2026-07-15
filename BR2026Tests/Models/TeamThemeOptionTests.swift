import Testing
@testable import BR2026

@Suite("TeamThemeOption")
struct TeamThemeOptionTests {
    @Test("Each case's teamID matches its real team")
    func teamIDs() {
        #expect(TeamThemeOption.palmeirasHome.teamID == 121)
        #expect(TeamThemeOption.flamengoHome.teamID == 127)
        #expect(TeamThemeOption.fluminenseHome.teamID == 124)
        #expect(TeamThemeOption.athleticoParanaenseHome.teamID == 134)
        #expect(TeamThemeOption.bahiaHome.teamID == 118)
        #expect(TeamThemeOption.redBullBragantinoHome.teamID == 794)
        #expect(TeamThemeOption.coritibaHome.teamID == 147)
        #expect(TeamThemeOption.saoPauloHome.teamID == 126)
        #expect(TeamThemeOption.atleticoMineiroHome.teamID == 1062)
        #expect(TeamThemeOption.corinthiansHome.teamID == 131)
    }

    @Test("Every case maps to the home TeamKit")
    func kitMapping() {
        for option in TeamThemeOption.allCases {
            #expect(option.kit == .home)
        }
    }

    @Test("All cases are stubbed as purchased")
    func allPurchased() {
        for option in TeamThemeOption.allCases {
            #expect(option.isPurchased == true)
        }
    }

    @Test("Only Palmeiras/Flamengo have no curated main color override")
    func colorOverrides() {
        #expect(TeamThemeOption.palmeirasHome.mainColorOverrideHex == nil)
        #expect(TeamThemeOption.flamengoHome.mainColorOverrideHex == nil)
        #expect(TeamThemeOption.fluminenseHome.mainColorOverrideHex == "870A28")
        #expect(TeamThemeOption.athleticoParanaenseHome.mainColorOverrideHex == "CE181E")
        #expect(TeamThemeOption.bahiaHome.mainColorOverrideHex == "006CB5")
        #expect(TeamThemeOption.redBullBragantinoHome.mainColorOverrideHex == "001D46")
        #expect(TeamThemeOption.coritibaHome.mainColorOverrideHex == "00544D")
        #expect(TeamThemeOption.saoPauloHome.mainColorOverrideHex == "FE0000")
        #expect(TeamThemeOption.atleticoMineiroHome.mainColorOverrideHex == "2B2B2E")
        #expect(TeamThemeOption.corinthiansHome.mainColorOverrideHex == "6E6E6C")
    }

    @Test("Only Fluminense/Bahia/Red Bull Bragantino/São Paulo/Atlético Mineiro have a curated tab-selection color override")
    func tabSelectionColorOverrides() {
        #expect(TeamThemeOption.palmeirasHome.tabSelectionColorOverrideHex == nil)
        #expect(TeamThemeOption.flamengoHome.tabSelectionColorOverrideHex == nil)
        #expect(TeamThemeOption.fluminenseHome.tabSelectionColorOverrideHex == "00613C")
        #expect(TeamThemeOption.athleticoParanaenseHome.tabSelectionColorOverrideHex == nil)
        #expect(TeamThemeOption.bahiaHome.tabSelectionColorOverrideHex == "ED3237")
        #expect(TeamThemeOption.redBullBragantinoHome.tabSelectionColorOverrideHex == "D2003C")
        #expect(TeamThemeOption.coritibaHome.tabSelectionColorOverrideHex == nil)
        #expect(TeamThemeOption.saoPauloHome.tabSelectionColorOverrideHex == "000000")
        #expect(TeamThemeOption.atleticoMineiroHome.tabSelectionColorOverrideHex == "FFFFFF")
        #expect(TeamThemeOption.corinthiansHome.tabSelectionColorOverrideHex == nil)
    }

    @Test("Only Atlético Mineiro/Corinthians have a curated pill-fill color override, distinct from their tab-selection color")
    func pillFillColorOverrides() {
        #expect(TeamThemeOption.palmeirasHome.pillFillColorOverrideHex == nil)
        #expect(TeamThemeOption.flamengoHome.pillFillColorOverrideHex == nil)
        #expect(TeamThemeOption.fluminenseHome.pillFillColorOverrideHex == nil)
        #expect(TeamThemeOption.athleticoParanaenseHome.pillFillColorOverrideHex == nil)
        #expect(TeamThemeOption.bahiaHome.pillFillColorOverrideHex == nil)
        #expect(TeamThemeOption.redBullBragantinoHome.pillFillColorOverrideHex == nil)
        #expect(TeamThemeOption.coritibaHome.pillFillColorOverrideHex == nil)
        #expect(TeamThemeOption.saoPauloHome.pillFillColorOverrideHex == nil)
        #expect(TeamThemeOption.atleticoMineiroHome.pillFillColorOverrideHex == "2B2B2E")
        #expect(TeamThemeOption.corinthiansHome.pillFillColorOverrideHex == "000000")
    }

    @Test("previewColorHex uses the main color override where one exists, falling back to the API-style main color otherwise")
    func previewColorHex() {
        #expect(TeamThemeOption.palmeirasHome.previewColorHex == "225638")
        #expect(TeamThemeOption.flamengoHome.previewColorHex == "ab1b10")
        #expect(TeamThemeOption.fluminenseHome.previewColorHex == "870A28")
        #expect(TeamThemeOption.athleticoParanaenseHome.previewColorHex == "CE181E")
        #expect(TeamThemeOption.bahiaHome.previewColorHex == "006CB5")
        #expect(TeamThemeOption.redBullBragantinoHome.previewColorHex == "001D46")
        #expect(TeamThemeOption.coritibaHome.previewColorHex == "00544D")
        #expect(TeamThemeOption.saoPauloHome.previewColorHex == "FE0000")
        #expect(TeamThemeOption.atleticoMineiroHome.previewColorHex == "2B2B2E")
        #expect(TeamThemeOption.corinthiansHome.previewColorHex == "6E6E6C")
    }

    @Test("Only Palmeiras/Flamengo/Fluminense/Atlético Mineiro have no curated font color override")
    func fontColorOverrides() {
        #expect(TeamThemeOption.palmeirasHome.fontColorOverrideHex == nil)
        #expect(TeamThemeOption.flamengoHome.fontColorOverrideHex == nil)
        #expect(TeamThemeOption.fluminenseHome.fontColorOverrideHex == nil)
        #expect(TeamThemeOption.athleticoParanaenseHome.fontColorOverrideHex == "F2F2F2")
        #expect(TeamThemeOption.bahiaHome.fontColorOverrideHex == "F2F2F2")
        #expect(TeamThemeOption.redBullBragantinoHome.fontColorOverrideHex == "FFFFFF")
        #expect(TeamThemeOption.coritibaHome.fontColorOverrideHex == "F2F2F2")
        #expect(TeamThemeOption.saoPauloHome.fontColorOverrideHex == "F2F2F2")
        #expect(TeamThemeOption.atleticoMineiroHome.fontColorOverrideHex == nil)
        #expect(TeamThemeOption.corinthiansHome.fontColorOverrideHex == "F2F2F2")
    }
}
