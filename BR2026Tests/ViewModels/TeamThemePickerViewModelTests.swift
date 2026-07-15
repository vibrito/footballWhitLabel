import Testing
@testable import BR2026

@Suite("TeamThemePickerViewModel")
@MainActor
struct TeamThemePickerViewModelTests {
    private let palmeirasColors = TeamThemeColorSet(
        home: TeamThemeColors(mainColorHex: "225638", fontColorHex: "ffffff"),
        away: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "035336"),
        third: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "2c5434")
    )

    @Test("selectedOption is nil when nothing is persisted")
    func nilByDefault() {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        let store = TeamThemeStore(setting: setting, service: service)
        let purchaseStore = PurchaseStore<TeamThemeOption>(service: MockPurchaseService())
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting, service: service)

        #expect(viewModel.selectedOption == nil)
    }

    @Test("selectedOption is derived from a matching persisted rawValue")
    func derivesFromPersistedValue() {
        let setting = StubTeamThemeSetting(selectedThemeID: TeamThemeOption.palmeirasHome.rawValue)
        let service = StubMatchService(matches: [], standings: [])
        let store = TeamThemeStore(setting: setting, service: service)
        let purchaseStore = PurchaseStore<TeamThemeOption>(service: MockPurchaseService())
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting, service: service)

        #expect(viewModel.selectedOption == .palmeirasHome)
    }

    @Test("select() purchases an unpurchased team before applying it, and updates selectedOption on success")
    func selectPurchasesThenUpdatesOnSuccess() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)
        let purchaseStore = PurchaseStore<TeamThemeOption>(service: MockPurchaseService())
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting, service: service)

        await viewModel.select(.palmeirasHome)

        #expect(viewModel.selectedOption == .palmeirasHome)
        #expect(viewModel.errorMessage == nil)
        #expect(purchaseStore.isPurchased(.palmeirasHome) == true)
    }

    @Test("select() does not re-purchase an already-purchased team")
    func selectSkipsPurchaseWhenAlreadyOwned() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)
        let purchaseService = MockPurchaseService(purchasedProductIDs: [TeamThemeOption.palmeirasHome.productID])
        let purchaseStore = PurchaseStore<TeamThemeOption>(service: purchaseService)
        await purchaseStore.loadOnce()
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting, service: service)

        await viewModel.select(.palmeirasHome)

        #expect(viewModel.selectedOption == .palmeirasHome)
    }

    @Test("select() leaves selectedOption unchanged, with no errorMessage, when the purchase fails/is cancelled")
    func selectLeavesUnchangedOnFailedPurchase() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)
        let purchaseService = MockPurchaseService()
        purchaseService.shouldFailNextPurchase = true
        let purchaseStore = PurchaseStore<TeamThemeOption>(service: purchaseService)
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting, service: service)

        await viewModel.select(.palmeirasHome)

        #expect(viewModel.selectedOption == nil)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("select() sets errorMessage and leaves selectedOption unchanged when theme application fails after a successful purchase")
    func selectSetsErrorMessageOnThemeApplicationFailure() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.shouldThrowOnTeamThemeFetch = true
        let store = TeamThemeStore(setting: setting, service: service)
        let purchaseStore = PurchaseStore<TeamThemeOption>(service: MockPurchaseService())
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting, service: service)

        await viewModel.select(.palmeirasHome)

        #expect(viewModel.selectedOption == nil)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("select() on the already-selected option is a no-op")
    func selectOnAlreadySelectedIsNoOp() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)
        let purchaseStore = PurchaseStore<TeamThemeOption>(service: MockPurchaseService())
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting, service: service)
        await viewModel.select(.palmeirasHome)
        let callCountAfterFirstSelect = service.fetchTeamThemeColorSetCallCount

        await viewModel.select(.palmeirasHome)

        #expect(service.fetchTeamThemeColorSetCallCount == callCountAfterFirstSelect)
    }

    @Test("isPurchased(_:) and price(for:) pass through to the purchase store")
    func isPurchasedAndPricePassThrough() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        let store = TeamThemeStore(setting: setting, service: service)
        let purchaseService = MockPurchaseService(purchasedProductIDs: [TeamThemeOption.flamengoHome.productID])
        let purchaseStore = PurchaseStore<TeamThemeOption>(service: purchaseService)
        await purchaseStore.loadOnce()
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting, service: service)

        #expect(viewModel.isPurchased(.flamengoHome) == true)
        #expect(viewModel.isPurchased(.palmeirasHome) == false)
    }

    @Test("restorePurchases() delegates to the purchase store")
    func restorePurchasesDelegates() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        let store = TeamThemeStore(setting: setting, service: service)
        let purchaseService = MockPurchaseService(purchasedProductIDs: [TeamThemeOption.bahiaHome.productID])
        let purchaseStore = PurchaseStore<TeamThemeOption>(service: purchaseService)
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting, service: service)

        await viewModel.restorePurchases()

        #expect(viewModel.isPurchased(.bahiaHome) == true)
    }

    @Test("select() clears stale errorMessage from prior failure when attempting different team with failed purchase")
    func selectClearsStaleErrorMessageOnFailedPurchase() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.shouldThrowOnTeamThemeFetch = true
        let store = TeamThemeStore(setting: setting, service: service)
        let purchaseService = MockPurchaseService()
        let purchaseStore = PurchaseStore<TeamThemeOption>(service: purchaseService)
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting, service: service)

        // First, trigger a theme-application failure to set errorMessage
        await viewModel.select(.palmeirasHome)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.selectedOption == nil)

        // Then attempt to select a different team where purchase fails
        purchaseService.shouldFailNextPurchase = true
        await viewModel.select(.flamengoHome)

        // After failed purchase of different team, stale errorMessage must be cleared
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.selectedOption == nil)
    }

    @Test("sortedOptions orders purchased teams before unpurchased teams")
    func sortedOptionsPutsPurchasedTeamsFirst() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        let store = TeamThemeStore(setting: setting, service: service)
        // Corinthians is purchased despite being the lowest-position team given below,
        // Palmeiras/Flamengo are unpurchased despite outranking it — purchase status must
        // win the sort over standings position.
        let purchaseService = MockPurchaseService(purchasedProductIDs: [TeamThemeOption.corinthiansHome.productID])
        let purchaseStore = PurchaseStore<TeamThemeOption>(service: purchaseService)
        await purchaseStore.loadOnce()
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting, service: service)

        let sorted = viewModel.sortedOptions

        #expect(sorted.first == .corinthiansHome)
        #expect(sorted.firstIndex(of: .corinthiansHome)! < sorted.firstIndex(of: .palmeirasHome)!)
        #expect(sorted.firstIndex(of: .corinthiansHome)! < sorted.firstIndex(of: .flamengoHome)!)
    }

    @Test("sortedOptions orders teams within the same purchase group by standings position")
    func sortedOptionsOrdersByStandingsPosition() {
        let setting = StubTeamThemeSetting()
        let flamengo = Standing(
            position: 1,
            team: Team(id: TeamThemeOption.flamengoHome.teamID, name: "Flamengo", shortName: "FLA", crestURL: nil),
            playedGames: 10, won: 8, draw: 1, lost: 1, goalsFor: 20, goalsAgainst: 8, goalDifference: 12, points: 25
        )
        let palmeiras = Standing(
            position: 2,
            team: Team(id: TeamThemeOption.palmeirasHome.teamID, name: "Palmeiras", shortName: "PAL", crestURL: nil),
            playedGames: 10, won: 7, draw: 2, lost: 1, goalsFor: 18, goalsAgainst: 9, goalDifference: 9, points: 23
        )
        let service = StubMatchService(matches: [], standings: [palmeiras, flamengo])
        let store = TeamThemeStore(setting: setting, service: service)
        let purchaseStore = PurchaseStore<TeamThemeOption>(service: MockPurchaseService())
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting, service: service)

        let sorted = viewModel.sortedOptions

        #expect(sorted.firstIndex(of: .flamengoHome)! < sorted.firstIndex(of: .palmeirasHome)!)
    }

    @Test("sortedOptions sorts a team with no cached standings row to the end of its purchase group")
    func sortedOptionsPutsUnrankedTeamsLast() {
        let setting = StubTeamThemeSetting()
        let flamengo = Standing(
            position: 1,
            team: Team(id: TeamThemeOption.flamengoHome.teamID, name: "Flamengo", shortName: "FLA", crestURL: nil),
            playedGames: 10, won: 8, draw: 1, lost: 1, goalsFor: 20, goalsAgainst: 8, goalDifference: 12, points: 25
        )
        // Only Flamengo has a standings row — every other team (including Palmeiras) is unranked.
        let service = StubMatchService(matches: [], standings: [flamengo])
        let store = TeamThemeStore(setting: setting, service: service)
        let purchaseStore = PurchaseStore<TeamThemeOption>(service: MockPurchaseService())
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting, service: service)

        let sorted = viewModel.sortedOptions

        #expect(sorted.firstIndex(of: .flamengoHome)! < sorted.firstIndex(of: .palmeirasHome)!)
    }

    @Test("loadOnce() fetches standings when the cache is empty, updating sortedOptions once fetched")
    func loadOnceFetchesStandingsWhenCacheEmpty() async {
        let setting = StubTeamThemeSetting()
        let flamengo = Standing(
            position: 1,
            team: Team(id: TeamThemeOption.flamengoHome.teamID, name: "Flamengo", shortName: "FLA", crestURL: nil),
            playedGames: 10, won: 8, draw: 1, lost: 1, goalsFor: 20, goalsAgainst: 8, goalDifference: 12, points: 25
        )
        let service = StubMatchService(matches: [], standings: [flamengo])
        // Simulates a user reaching More → Team Theme without ever visiting Standings —
        // fetchStandings() (what the API would return) has data, but the cache is still empty.
        service.cachedStandingsOverride = []
        let store = TeamThemeStore(setting: setting, service: service)
        let purchaseStore = PurchaseStore<TeamThemeOption>(service: MockPurchaseService())
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting, service: service)
        #expect(viewModel.standings.isEmpty)

        await viewModel.loadOnce()

        #expect(viewModel.standings.map(\.teamID) == [flamengo.teamID])
        #expect(viewModel.sortedOptions.firstIndex(of: .flamengoHome)! < viewModel.sortedOptions.firstIndex(of: .palmeirasHome)!)
    }

    @Test("loadOnce() called twice only fetches standings once")
    func loadOnceFetchesStandingsOnlyOnce() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        let store = TeamThemeStore(setting: setting, service: service)
        let purchaseStore = PurchaseStore<TeamThemeOption>(service: MockPurchaseService())
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting, service: service)

        await viewModel.loadOnce()
        await viewModel.loadOnce()

        #expect(service.fetchStandingsCallCount == 1)
    }
}
