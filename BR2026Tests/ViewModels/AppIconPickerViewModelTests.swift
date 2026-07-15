// BR2026Tests/ViewModels/AppIconPickerViewModelTests.swift
import Testing
@testable import BR2026

@Suite("AppIconPickerViewModel")
@MainActor
struct AppIconPickerViewModelTests {
    @Test("selectedIconAssetName reflects the setting's currentIconName at init")
    func selectedIconAssetNameReflectsSetting() {
        let setting = StubAppIconSetting(currentIconName: nil)
        let service = StubMatchService(matches: [], standings: [])
        let purchaseStore = PurchaseStore<TeamIconOption>(service: MockPurchaseService())
        let viewModel = AppIconPickerViewModel(iconSetting: setting, purchaseStore: purchaseStore, service: service)

        #expect(viewModel.selectedIconAssetName == nil)
        #expect(viewModel.isSelected(AppIconOption.light) == true)
    }

    @Test("isSelected(_:) for AppIconOption matches the current icon asset name")
    func isSelectedForAppIconOption() {
        let setting = StubAppIconSetting(currentIconName: "AppIcon-Stadium")
        let service = StubMatchService(matches: [], standings: [])
        let purchaseStore = PurchaseStore<TeamIconOption>(service: MockPurchaseService())
        let viewModel = AppIconPickerViewModel(iconSetting: setting, purchaseStore: purchaseStore, service: service)

        #expect(viewModel.isSelected(AppIconOption.stadium) == true)
        #expect(viewModel.isSelected(AppIconOption.light) == false)
    }

    @Test("select(_: AppIconOption) updates selectedIconAssetName and calls setIconName")
    func selectAppIconOptionUpdatesSelection() async {
        let setting = StubAppIconSetting(currentIconName: nil)
        let service = StubMatchService(matches: [], standings: [])
        let purchaseStore = PurchaseStore<TeamIconOption>(service: MockPurchaseService())
        let viewModel = AppIconPickerViewModel(iconSetting: setting, purchaseStore: purchaseStore, service: service)

        await viewModel.select(AppIconOption.stadium)

        #expect(viewModel.isSelected(AppIconOption.stadium) == true)
        #expect(setting.setIconNameCalls == ["AppIcon-Stadium"])
        #expect(viewModel.errorMessage == nil)
    }

    @Test("select(_: AppIconOption) sets errorMessage when setIconName throws")
    func selectAppIconOptionSetsErrorOnFailure() async {
        let setting = StubAppIconSetting(currentIconName: nil)
        setting.shouldThrow = true
        let service = StubMatchService(matches: [], standings: [])
        let purchaseStore = PurchaseStore<TeamIconOption>(service: MockPurchaseService())
        let viewModel = AppIconPickerViewModel(iconSetting: setting, purchaseStore: purchaseStore, service: service)

        await viewModel.select(AppIconOption.stadium)

        #expect(viewModel.isSelected(AppIconOption.light) == true)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("select(_: TeamIconOption) purchases an unpurchased team icon before applying it")
    func selectTeamIconPurchasesThenApplies() async {
        let setting = StubAppIconSetting(currentIconName: nil)
        let service = StubMatchService(matches: [], standings: [])
        let purchaseStore = PurchaseStore<TeamIconOption>(service: MockPurchaseService())
        let viewModel = AppIconPickerViewModel(iconSetting: setting, purchaseStore: purchaseStore, service: service)

        await viewModel.select(TeamIconOption.palmeiras)

        #expect(viewModel.isSelected(TeamIconOption.palmeiras) == true)
        #expect(setting.setIconNameCalls == ["AppIcon-Palmeiras"])
        #expect(viewModel.errorMessage == nil)
        #expect(purchaseStore.isPurchased(.palmeiras) == true)
    }

    @Test("select(_: TeamIconOption) does not re-purchase an already-purchased team icon")
    func selectTeamIconSkipsPurchaseWhenAlreadyOwned() async {
        let setting = StubAppIconSetting(currentIconName: nil)
        let service = StubMatchService(matches: [], standings: [])
        let purchaseService = MockPurchaseService(purchasedProductIDs: [TeamIconOption.palmeiras.productID])
        let purchaseStore = PurchaseStore<TeamIconOption>(service: purchaseService)
        await purchaseStore.loadOnce()
        let viewModel = AppIconPickerViewModel(iconSetting: setting, purchaseStore: purchaseStore, service: service)

        await viewModel.select(TeamIconOption.palmeiras)

        #expect(viewModel.isSelected(TeamIconOption.palmeiras) == true)
    }

    @Test("select(_: TeamIconOption) leaves selection unchanged when the purchase fails")
    func selectTeamIconLeavesUnchangedOnFailedPurchase() async {
        let setting = StubAppIconSetting(currentIconName: nil)
        let service = StubMatchService(matches: [], standings: [])
        let purchaseService = MockPurchaseService()
        purchaseService.shouldFailNextPurchase = true
        let purchaseStore = PurchaseStore<TeamIconOption>(service: purchaseService)
        let viewModel = AppIconPickerViewModel(iconSetting: setting, purchaseStore: purchaseStore, service: service)

        await viewModel.select(TeamIconOption.palmeiras)

        #expect(viewModel.isSelected(TeamIconOption.palmeiras) == false)
        #expect(setting.setIconNameCalls.isEmpty)
    }

    @Test("isPurchased(_:) and price(for:) pass through to the purchase store")
    func isPurchasedAndPricePassThrough() async {
        let setting = StubAppIconSetting(currentIconName: nil)
        let service = StubMatchService(matches: [], standings: [])
        let purchaseService = MockPurchaseService(purchasedProductIDs: [TeamIconOption.flamengo.productID])
        let purchaseStore = PurchaseStore<TeamIconOption>(service: purchaseService)
        await purchaseStore.loadOnce()
        let viewModel = AppIconPickerViewModel(iconSetting: setting, purchaseStore: purchaseStore, service: service)

        #expect(viewModel.isPurchased(.flamengo) == true)
        #expect(viewModel.isPurchased(.palmeiras) == false)
    }

    @Test("restorePurchases() delegates to the purchase store")
    func restorePurchasesDelegates() async {
        let setting = StubAppIconSetting(currentIconName: nil)
        let service = StubMatchService(matches: [], standings: [])
        let purchaseService = MockPurchaseService(purchasedProductIDs: [TeamIconOption.bahia.productID])
        let purchaseStore = PurchaseStore<TeamIconOption>(service: purchaseService)
        let viewModel = AppIconPickerViewModel(iconSetting: setting, purchaseStore: purchaseStore, service: service)

        await viewModel.restorePurchases()

        #expect(viewModel.isPurchased(.bahia) == true)
    }

    @Test("sortedTeamOptions orders purchased teams before unpurchased teams")
    func sortedTeamOptionsPutsPurchasedFirst() async {
        let setting = StubAppIconSetting(currentIconName: nil)
        let service = StubMatchService(matches: [], standings: [])
        let purchaseService = MockPurchaseService(purchasedProductIDs: [TeamIconOption.corinthians.productID])
        let purchaseStore = PurchaseStore<TeamIconOption>(service: purchaseService)
        await purchaseStore.loadOnce()
        let viewModel = AppIconPickerViewModel(iconSetting: setting, purchaseStore: purchaseStore, service: service)

        let sorted = viewModel.sortedTeamOptions

        #expect(sorted.first == .corinthians)
    }

    @Test("sortedTeamOptions orders teams within the same purchase group by standings position")
    func sortedTeamOptionsOrdersByStandings() {
        let setting = StubAppIconSetting(currentIconName: nil)
        let flamengo = Standing(
            position: 1,
            team: Team(id: TeamIconOption.flamengo.teamID, name: "Flamengo", shortName: "FLA", crestURL: nil),
            playedGames: 10, won: 8, draw: 1, lost: 1, goalsFor: 20, goalsAgainst: 8, goalDifference: 12, points: 25
        )
        let palmeiras = Standing(
            position: 2,
            team: Team(id: TeamIconOption.palmeiras.teamID, name: "Palmeiras", shortName: "PAL", crestURL: nil),
            playedGames: 10, won: 7, draw: 2, lost: 1, goalsFor: 18, goalsAgainst: 9, goalDifference: 9, points: 23
        )
        let service = StubMatchService(matches: [], standings: [palmeiras, flamengo])
        let purchaseStore = PurchaseStore<TeamIconOption>(service: MockPurchaseService())
        let viewModel = AppIconPickerViewModel(iconSetting: setting, purchaseStore: purchaseStore, service: service)

        let sorted = viewModel.sortedTeamOptions

        #expect(sorted.firstIndex(of: .flamengo)! < sorted.firstIndex(of: .palmeiras)!)
    }

    @Test("loadOnce() fetches standings when the cache is empty, updating sortedTeamOptions once fetched")
    func loadOnceFetchesStandingsWhenCacheEmpty() async {
        let setting = StubAppIconSetting(currentIconName: nil)
        let flamengo = Standing(
            position: 1,
            team: Team(id: TeamIconOption.flamengo.teamID, name: "Flamengo", shortName: "FLA", crestURL: nil),
            playedGames: 10, won: 8, draw: 1, lost: 1, goalsFor: 20, goalsAgainst: 8, goalDifference: 12, points: 25
        )
        let service = StubMatchService(matches: [], standings: [flamengo])
        service.cachedStandingsOverride = []
        let purchaseStore = PurchaseStore<TeamIconOption>(service: MockPurchaseService())
        let viewModel = AppIconPickerViewModel(iconSetting: setting, purchaseStore: purchaseStore, service: service)
        #expect(viewModel.standings.isEmpty)

        await viewModel.loadOnce()

        #expect(viewModel.standings.map(\.teamID) == [flamengo.teamID])
        #expect(viewModel.sortedTeamOptions.firstIndex(of: .flamengo)! < viewModel.sortedTeamOptions.firstIndex(of: .palmeiras)!)
    }

    @Test("loadOnce() called twice only fetches standings once")
    func loadOnceFetchesStandingsOnlyOnce() async {
        let setting = StubAppIconSetting(currentIconName: nil)
        let service = StubMatchService(matches: [], standings: [])
        let purchaseStore = PurchaseStore<TeamIconOption>(service: MockPurchaseService())
        let viewModel = AppIconPickerViewModel(iconSetting: setting, purchaseStore: purchaseStore, service: service)

        await viewModel.loadOnce()
        await viewModel.loadOnce()

        #expect(service.fetchStandingsCallCount == 1)
    }
}

final class StubAppIconSetting: AppIconSetting {
    let currentIconName: String?
    var shouldThrow = false
    private(set) var setIconNameCalls: [String?] = []

    init(currentIconName: String?) {
        self.currentIconName = currentIconName
    }

    func setIconName(_ name: String?) async throws {
        setIconNameCalls.append(name)
        if shouldThrow { throw StubServiceError.simulatedFailure }
    }
}
