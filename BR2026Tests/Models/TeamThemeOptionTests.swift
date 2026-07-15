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
        #expect(TeamThemeOption.cruzeiroHome.teamID == 135)
        #expect(TeamThemeOption.internacionalHome.teamID == 119)
        #expect(TeamThemeOption.remoHome.teamID == 1198)
        #expect(TeamThemeOption.botafogoHome.teamID == 120)
        #expect(TeamThemeOption.vitoriaHome.teamID == 136)
        #expect(TeamThemeOption.mirassolHome.teamID == 7848)
        #expect(TeamThemeOption.chapecoenseHome.teamID == 132)
        #expect(TeamThemeOption.santosHome.teamID == 128)
        #expect(TeamThemeOption.gremioHome.teamID == 130)
        #expect(TeamThemeOption.vascoDaGamaHome.teamID == 133)
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

    @Test("Every team but Vitória has a curated main color override")
    func colorOverrides() {
        #expect(TeamThemeOption.palmeirasHome.mainColorOverrideHex == "006437")
        #expect(TeamThemeOption.flamengoHome.mainColorOverrideHex == "C52613")
        #expect(TeamThemeOption.fluminenseHome.mainColorOverrideHex == "870A28")
        #expect(TeamThemeOption.athleticoParanaenseHome.mainColorOverrideHex == "CE181E")
        #expect(TeamThemeOption.bahiaHome.mainColorOverrideHex == "006CB5")
        #expect(TeamThemeOption.redBullBragantinoHome.mainColorOverrideHex == "001D46")
        #expect(TeamThemeOption.coritibaHome.mainColorOverrideHex == "00544D")
        #expect(TeamThemeOption.saoPauloHome.mainColorOverrideHex == "FE0000")
        #expect(TeamThemeOption.atleticoMineiroHome.mainColorOverrideHex == "2B2B2E")
        #expect(TeamThemeOption.corinthiansHome.mainColorOverrideHex == "6E6E6C")
        #expect(TeamThemeOption.cruzeiroHome.mainColorOverrideHex == "2F529E")
        #expect(TeamThemeOption.internacionalHome.mainColorOverrideHex == "E5050F")
        #expect(TeamThemeOption.remoHome.mainColorOverrideHex == "2048A8")
        #expect(TeamThemeOption.botafogoHome.mainColorOverrideHex == "1E1E20")
        #expect(TeamThemeOption.vitoriaHome.mainColorOverrideHex == nil)
        #expect(TeamThemeOption.mirassolHome.mainColorOverrideHex == "9E9906")
        #expect(TeamThemeOption.chapecoenseHome.mainColorOverrideHex == "1B552A")
        #expect(TeamThemeOption.santosHome.mainColorOverrideHex == "82827F")
        #expect(TeamThemeOption.gremioHome.mainColorOverrideHex == "0D80BF")
        #expect(TeamThemeOption.vascoDaGamaHome.mainColorOverrideHex == "242426")
    }

    @Test("Only Fluminense/Bahia/Red Bull Bragantino/São Paulo/Atlético Mineiro/Botafogo/Mirassol/Vasco da Gama have a curated tab-selection color override")
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
        #expect(TeamThemeOption.cruzeiroHome.tabSelectionColorOverrideHex == nil)
        #expect(TeamThemeOption.internacionalHome.tabSelectionColorOverrideHex == nil)
        #expect(TeamThemeOption.remoHome.tabSelectionColorOverrideHex == nil)
        #expect(TeamThemeOption.botafogoHome.tabSelectionColorOverrideHex == "FFFFFF")
        #expect(TeamThemeOption.vitoriaHome.tabSelectionColorOverrideHex == nil)
        #expect(TeamThemeOption.mirassolHome.tabSelectionColorOverrideHex == "126F3D")
        #expect(TeamThemeOption.chapecoenseHome.tabSelectionColorOverrideHex == nil)
        #expect(TeamThemeOption.santosHome.tabSelectionColorOverrideHex == nil)
        #expect(TeamThemeOption.gremioHome.tabSelectionColorOverrideHex == nil)
        #expect(TeamThemeOption.vascoDaGamaHome.tabSelectionColorOverrideHex == "FFFFFF")
    }

    @Test("Only Atlético Mineiro/Corinthians/Botafogo/Santos/Vasco da Gama have a curated pill-fill color override, distinct from their tab-selection color")
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
        #expect(TeamThemeOption.cruzeiroHome.pillFillColorOverrideHex == nil)
        #expect(TeamThemeOption.internacionalHome.pillFillColorOverrideHex == nil)
        #expect(TeamThemeOption.remoHome.pillFillColorOverrideHex == nil)
        #expect(TeamThemeOption.botafogoHome.pillFillColorOverrideHex == "1E1E20")
        #expect(TeamThemeOption.vitoriaHome.pillFillColorOverrideHex == nil)
        #expect(TeamThemeOption.mirassolHome.pillFillColorOverrideHex == nil)
        #expect(TeamThemeOption.chapecoenseHome.pillFillColorOverrideHex == nil)
        #expect(TeamThemeOption.santosHome.pillFillColorOverrideHex == "000000")
        #expect(TeamThemeOption.gremioHome.pillFillColorOverrideHex == nil)
        #expect(TeamThemeOption.vascoDaGamaHome.pillFillColorOverrideHex == "242426")
    }

    @Test("previewColorHex uses the main color override where one exists, falling back to the API-style main color otherwise")
    func previewColorHex() {
        #expect(TeamThemeOption.palmeirasHome.previewColorHex == "006437")
        #expect(TeamThemeOption.flamengoHome.previewColorHex == "C52613")
        #expect(TeamThemeOption.fluminenseHome.previewColorHex == "870A28")
        #expect(TeamThemeOption.athleticoParanaenseHome.previewColorHex == "CE181E")
        #expect(TeamThemeOption.bahiaHome.previewColorHex == "006CB5")
        #expect(TeamThemeOption.redBullBragantinoHome.previewColorHex == "001D46")
        #expect(TeamThemeOption.coritibaHome.previewColorHex == "00544D")
        #expect(TeamThemeOption.saoPauloHome.previewColorHex == "FE0000")
        #expect(TeamThemeOption.atleticoMineiroHome.previewColorHex == "2B2B2E")
        #expect(TeamThemeOption.corinthiansHome.previewColorHex == "6E6E6C")
        #expect(TeamThemeOption.cruzeiroHome.previewColorHex == "2F529E")
        #expect(TeamThemeOption.internacionalHome.previewColorHex == "E5050F")
        #expect(TeamThemeOption.remoHome.previewColorHex == "2048A8")
        #expect(TeamThemeOption.botafogoHome.previewColorHex == "1E1E20")
        #expect(TeamThemeOption.vitoriaHome.previewColorHex == "ff0000")
        #expect(TeamThemeOption.mirassolHome.previewColorHex == "9E9906")
        #expect(TeamThemeOption.chapecoenseHome.previewColorHex == "1B552A")
        #expect(TeamThemeOption.santosHome.previewColorHex == "82827F")
        #expect(TeamThemeOption.gremioHome.previewColorHex == "0D80BF")
        #expect(TeamThemeOption.vascoDaGamaHome.previewColorHex == "242426")
    }

    @Test("Only Palmeiras/Flamengo/Fluminense/Atlético Mineiro/Cruzeiro/Internacional/Remo/Botafogo/Vitória/Chapecoense/Grêmio/Vasco da Gama have no curated font color override")
    func fontColorOverrides() {
        #expect(TeamThemeOption.palmeirasHome.fontColorOverrideHex == nil)
        #expect(TeamThemeOption.flamengoHome.fontColorOverrideHex == nil)
        #expect(TeamThemeOption.fluminenseHome.fontColorOverrideHex == nil)
        #expect(TeamThemeOption.athleticoParanaenseHome.fontColorOverrideHex == "F2F2F2")
        #expect(TeamThemeOption.bahiaHome.fontColorOverrideHex == "F2F2F2")
        #expect(TeamThemeOption.redBullBragantinoHome.fontColorOverrideHex == "FFFFFF")
        #expect(TeamThemeOption.coritibaHome.fontColorOverrideHex == "F2F2F2")
        #expect(TeamThemeOption.saoPauloHome.fontColorOverrideHex == "FFFFFF")
        #expect(TeamThemeOption.atleticoMineiroHome.fontColorOverrideHex == nil)
        #expect(TeamThemeOption.corinthiansHome.fontColorOverrideHex == "F2F2F2")
        #expect(TeamThemeOption.cruzeiroHome.fontColorOverrideHex == nil)
        #expect(TeamThemeOption.internacionalHome.fontColorOverrideHex == nil)
        #expect(TeamThemeOption.remoHome.fontColorOverrideHex == nil)
        #expect(TeamThemeOption.botafogoHome.fontColorOverrideHex == nil)
        #expect(TeamThemeOption.vitoriaHome.fontColorOverrideHex == nil)
        #expect(TeamThemeOption.mirassolHome.fontColorOverrideHex == "FFFFFF")
        #expect(TeamThemeOption.chapecoenseHome.fontColorOverrideHex == nil)
        #expect(TeamThemeOption.santosHome.fontColorOverrideHex == "F2F2F2")
        #expect(TeamThemeOption.gremioHome.fontColorOverrideHex == nil)
        #expect(TeamThemeOption.vascoDaGamaHome.fontColorOverrideHex == nil)
    }

    @Test("Only Cruzeiro has a curated gradient dark-amount override")
    func gradientDarkAmountOverrides() {
        #expect(TeamThemeOption.palmeirasHome.gradientDarkAmountOverride == nil)
        #expect(TeamThemeOption.flamengoHome.gradientDarkAmountOverride == nil)
        #expect(TeamThemeOption.fluminenseHome.gradientDarkAmountOverride == nil)
        #expect(TeamThemeOption.athleticoParanaenseHome.gradientDarkAmountOverride == nil)
        #expect(TeamThemeOption.bahiaHome.gradientDarkAmountOverride == nil)
        #expect(TeamThemeOption.redBullBragantinoHome.gradientDarkAmountOverride == nil)
        #expect(TeamThemeOption.coritibaHome.gradientDarkAmountOverride == nil)
        #expect(TeamThemeOption.saoPauloHome.gradientDarkAmountOverride == nil)
        #expect(TeamThemeOption.atleticoMineiroHome.gradientDarkAmountOverride == nil)
        #expect(TeamThemeOption.corinthiansHome.gradientDarkAmountOverride == nil)
        #expect(TeamThemeOption.cruzeiroHome.gradientDarkAmountOverride == -0.5)
        #expect(TeamThemeOption.internacionalHome.gradientDarkAmountOverride == nil)
        #expect(TeamThemeOption.remoHome.gradientDarkAmountOverride == nil)
        #expect(TeamThemeOption.botafogoHome.gradientDarkAmountOverride == nil)
        #expect(TeamThemeOption.vitoriaHome.gradientDarkAmountOverride == nil)
        #expect(TeamThemeOption.mirassolHome.gradientDarkAmountOverride == nil)
        #expect(TeamThemeOption.chapecoenseHome.gradientDarkAmountOverride == nil)
        #expect(TeamThemeOption.santosHome.gradientDarkAmountOverride == nil)
        #expect(TeamThemeOption.gremioHome.gradientDarkAmountOverride == nil)
        #expect(TeamThemeOption.vascoDaGamaHome.gradientDarkAmountOverride == nil)
    }

    @Test("Only Vasco da Gama uses the diagonal sash background")
    func usesDiagonalSashBackgroundOverrides() {
        for option in TeamThemeOption.allCases where option != .vascoDaGamaHome {
            #expect(option.usesDiagonalSashBackground == false)
        }
        #expect(TeamThemeOption.vascoDaGamaHome.usesDiagonalSashBackground == true)
    }
}
