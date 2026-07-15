import Testing
@testable import BR2026

@Suite("TeamIconOption")
struct TeamIconOptionTests {
    @Test("Each case's teamID matches the same real team as its TeamThemeOption counterpart")
    func teamIDs() {
        #expect(TeamIconOption.palmeiras.teamID == 121)
        #expect(TeamIconOption.flamengo.teamID == 127)
        #expect(TeamIconOption.fluminense.teamID == 124)
        #expect(TeamIconOption.athleticoParanaense.teamID == 134)
        #expect(TeamIconOption.bahia.teamID == 118)
        #expect(TeamIconOption.redBullBragantino.teamID == 794)
        #expect(TeamIconOption.coritiba.teamID == 147)
        #expect(TeamIconOption.saoPaulo.teamID == 126)
        #expect(TeamIconOption.atleticoMineiro.teamID == 1062)
        #expect(TeamIconOption.corinthians.teamID == 131)
        #expect(TeamIconOption.cruzeiro.teamID == 135)
        #expect(TeamIconOption.internacional.teamID == 119)
        #expect(TeamIconOption.remo.teamID == 1198)
        #expect(TeamIconOption.botafogo.teamID == 120)
        #expect(TeamIconOption.vitoria.teamID == 136)
        #expect(TeamIconOption.mirassol.teamID == 7848)
        #expect(TeamIconOption.chapecoense.teamID == 132)
        #expect(TeamIconOption.santos.teamID == 128)
        #expect(TeamIconOption.gremio.teamID == 130)
        #expect(TeamIconOption.vascoDaGama.teamID == 133)
    }

    @Test("productID follows the com.vibrito.br2026.icon.<rawValue> scheme for every case")
    func productIDs() {
        for option in TeamIconOption.allCases {
            #expect(option.productID == "com.vibrito.br2026.icon.\(option.rawValue)")
        }
    }

    @Test("rawValue(fromProductID:) round-trips every case's productID and returns nil for a foreign ID")
    func rawValueFromProductID() {
        for option in TeamIconOption.allCases {
            #expect(TeamIconOption.rawValue(fromProductID: option.productID) == option.rawValue)
        }
        #expect(TeamIconOption.rawValue(fromProductID: "com.example.other.product") == nil)
        #expect(TeamIconOption.rawValue(fromProductID: "com.vibrito.br2026.theme.palmeirasHome") == nil)
    }

    @Test("iconAssetName and previewImageName match the asset catalog's capitalized team token")
    func assetNames() {
        #expect(TeamIconOption.palmeiras.iconAssetName == "AppIcon-Palmeiras")
        #expect(TeamIconOption.palmeiras.previewImageName == "AppIconPreview-Palmeiras")
        #expect(TeamIconOption.athleticoParanaense.iconAssetName == "AppIcon-AthleticoParanaense")
        #expect(TeamIconOption.redBullBragantino.iconAssetName == "AppIcon-RedBullBragantino")
        #expect(TeamIconOption.vascoDaGama.iconAssetName == "AppIcon-VascoDaGama")
        #expect(TeamIconOption.saoPaulo.iconAssetName == "AppIcon-SaoPaulo")
    }

    @Test("There are exactly 20 cases, one per TeamThemeOption team")
    func caseCount() {
        #expect(TeamIconOption.allCases.count == 20)
    }
}
