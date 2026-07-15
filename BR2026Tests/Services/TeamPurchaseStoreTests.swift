import Testing
@testable import BR2026

@Suite("TeamPurchaseStore")
@MainActor
struct TeamPurchaseStoreTests {
    @Test("loadOnce() populates purchasedTeamIDs from the service's initial purchased set")
    func loadOncePopulatesFromInitialSet() async {
        let service = MockPurchaseService(purchasedProductIDs: [TeamThemeOption.palmeirasHome.productID])
        let store = TeamPurchaseStore(service: service)

        await store.loadOnce()

        #expect(store.isPurchased(.palmeirasHome) == true)
        #expect(store.isPurchased(.flamengoHome) == false)
    }

    @Test("loadOnce() called twice only loads once")
    func loadOnceIsIdempotent() async {
        let service = MockPurchaseService(purchasedProductIDs: [TeamThemeOption.palmeirasHome.productID])
        let store = TeamPurchaseStore(service: service)

        await store.loadOnce()
        await store.loadOnce()

        #expect(store.isPurchased(.palmeirasHome) == true)
    }

    @Test("purchase() adds the team to purchasedTeamIDs on success")
    func purchaseAddsToOwnedSet() async {
        let service = MockPurchaseService()
        let store = TeamPurchaseStore(service: service)
        await store.loadOnce()

        let succeeded = await store.purchase(.corinthiansHome)

        #expect(succeeded == true)
        #expect(store.isPurchased(.corinthiansHome) == true)
    }

    @Test("purchase() leaves the team unpurchased when the service reports failure")
    func purchaseLeavesUnpurchasedOnFailure() async {
        let service = MockPurchaseService()
        service.shouldFailNextPurchase = true
        let store = TeamPurchaseStore(service: service)
        await store.loadOnce()

        let succeeded = await store.purchase(.corinthiansHome)

        #expect(succeeded == false)
        #expect(store.isPurchased(.corinthiansHome) == false)
    }

    @Test("isPurchased(_:) is false for every team before loadOnce()")
    func isPurchasedFalseBeforeLoad() {
        let store = TeamPurchaseStore(service: MockPurchaseService())

        for option in TeamThemeOption.allCases {
            #expect(store.isPurchased(option) == false)
        }
    }

    @Test("restorePurchases() re-syncs purchasedTeamIDs from the service")
    func restorePurchasesResyncs() async {
        let service = MockPurchaseService()
        let store = TeamPurchaseStore(service: service)
        await store.loadOnce()
        #expect(store.isPurchased(.bahiaHome) == false)
        service.simulateExternalPurchase(TeamThemeOption.bahiaHome.productID)  // simulates a purchase made on another device

        await store.restorePurchases()

        #expect(store.isPurchased(.bahiaHome) == true)
    }
}
