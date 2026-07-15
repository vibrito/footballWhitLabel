import Testing
@testable import BR2026

@Suite("TeamThemeOption")
struct TeamThemeOptionTests {
    @Test("Each case's teamID matches its real team")
    func teamIDs() {
        #expect(TeamThemeOption.palmeirasHome.teamID == 121)
        #expect(TeamThemeOption.flamengoHome.teamID == 127)
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
}
