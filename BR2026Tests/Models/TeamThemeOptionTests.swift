import Testing
@testable import BR2026

@Suite("TeamThemeOption")
struct TeamThemeOptionTests {
    @Test("Each case's teamID matches its real team")
    func teamIDs() {
        #expect(TeamThemeOption.palmeirasHome.teamID == 121)
        #expect(TeamThemeOption.flamengoHome.teamID == 127)
        #expect(TeamThemeOption.corinthiansHome.teamID == 131)
        #expect(TeamThemeOption.saoPauloHome.teamID == 126)
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

    @Test("Only near-white teams (Corinthians, São Paulo) use the centered vignette gradient style")
    func gradientStyle() {
        #expect(TeamThemeOption.palmeirasHome.gradientStyle == .topAnchored)
        #expect(TeamThemeOption.flamengoHome.gradientStyle == .topAnchored)
        #expect(TeamThemeOption.corinthiansHome.gradientStyle == .centeredVignette)
        #expect(TeamThemeOption.saoPauloHome.gradientStyle == .centeredVignette)
    }

    @Test("Only near-white teams have a curated accentOverrideHex, and Corinthians/São Paulo's differ")
    func accentOverrideHex() {
        #expect(TeamThemeOption.palmeirasHome.accentOverrideHex == nil)
        #expect(TeamThemeOption.flamengoHome.accentOverrideHex == nil)
        #expect(TeamThemeOption.corinthiansHome.accentOverrideHex == "C8102E")
        #expect(TeamThemeOption.saoPauloHome.accentOverrideHex == "E4022B")
    }

    @Test("previewColorHex uses the accent override where one exists, falling back to the API-style main color otherwise")
    func previewColorHex() {
        #expect(TeamThemeOption.palmeirasHome.previewColorHex == "225638")
        #expect(TeamThemeOption.flamengoHome.previewColorHex == "ab1b10")
        #expect(TeamThemeOption.corinthiansHome.previewColorHex == "C8102E")
        #expect(TeamThemeOption.saoPauloHome.previewColorHex == "E4022B")
    }
}
