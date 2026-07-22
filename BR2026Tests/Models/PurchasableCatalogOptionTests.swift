import Testing
@testable import BR2026

@Suite("PurchasableCatalogOption.offeredCases")
struct PurchasableCatalogOptionTests {
    @Test("An empty allowlist offers every case")
    func emptyAllowlistOffersAll() {
        #expect(TeamThemeOption.offeredCases(allowlist: []).count == TeamThemeOption.allCases.count)
        #expect(TeamIconOption.offeredCases(allowlist: []).count == TeamIconOption.allCases.count)
    }

    @Test("A non-empty allowlist offers only the listed product IDs")
    func allowlistFiltersToListed() {
        let offered = TeamThemeOption.offeredCases(allowlist: [TeamThemeOption.flamengoHome.productID])
        #expect(offered == [.flamengoHome])
    }

    @Test("The allowlist can span both catalogs independently")
    func allowlistIsPerCatalog() {
        let allowlist: Set<String> = [
            TeamThemeOption.flamengoHome.productID,
            TeamIconOption.bahia.productID,
        ]
        #expect(TeamThemeOption.offeredCases(allowlist: allowlist) == [.flamengoHome])
        #expect(TeamIconOption.offeredCases(allowlist: allowlist) == [.bahia])
    }

    @Test("An allowlist with no matching product IDs offers nothing")
    func allowlistWithNoMatchesOffersNothing() {
        #expect(TeamThemeOption.offeredCases(allowlist: ["com.vibrito.br2026.theme.doesNotExist"]).isEmpty)
    }

    @Test("offeredCases defaults to the FeatureFlags allowlist (all, in normal operation)")
    func defaultsToFeatureFlag() {
        // Default build ships an empty allowlist, so every case is offered.
        #expect(TeamThemeOption.offeredCases().count == TeamThemeOption.allCases.count)
        #expect(TeamIconOption.offeredCases().count == TeamIconOption.allCases.count)
    }
}
