import Testing
@testable import BR2026

@Suite("TeamThemeOption")
struct TeamThemeOptionTests {
    @Test("All 3 cases point at Palmeiras's team id, 121")
    func allCasesShareTeamID() {
        for option in TeamThemeOption.allCases {
            #expect(option.teamID == 121)
        }
    }

    @Test("Each case maps to its matching TeamKit")
    func kitMapping() {
        #expect(TeamThemeOption.palmeirasHome.kit == .home)
        #expect(TeamThemeOption.palmeirasAway.kit == .away)
        #expect(TeamThemeOption.palmeirasThird.kit == .third)
    }

    @Test("All 3 cases are stubbed as purchased")
    func allPurchased() {
        for option in TeamThemeOption.allCases {
            #expect(option.isPurchased == true)
        }
    }
}
