import Testing
@testable import BR2026

@Suite("TeamThemeOption")
struct TeamThemeOptionTests {
    @Test("All cases point at Palmeiras's team id, 121")
    func allCasesShareTeamID() {
        for option in TeamThemeOption.allCases {
            #expect(option.teamID == 121)
        }
    }

    @Test("palmeirasHome maps to the home TeamKit")
    func kitMapping() {
        #expect(TeamThemeOption.palmeirasHome.kit == .home)
    }

    @Test("All cases are stubbed as purchased")
    func allPurchased() {
        for option in TeamThemeOption.allCases {
            #expect(option.isPurchased == true)
        }
    }
}
