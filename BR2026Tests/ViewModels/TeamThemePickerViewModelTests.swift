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
        let store = TeamThemeStore(setting: setting, service: StubMatchService(matches: [], standings: []))
        let purchaseStore = TeamPurchaseStore(service: MockPurchaseService())
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting)

        #expect(viewModel.selectedOption == nil)
    }

    @Test("selectedOption is derived from a matching persisted rawValue")
    func derivesFromPersistedValue() {
        let setting = StubTeamThemeSetting(selectedThemeID: TeamThemeOption.palmeirasHome.rawValue)
        let store = TeamThemeStore(setting: setting, service: StubMatchService(matches: [], standings: []))
        let purchaseStore = TeamPurchaseStore(service: MockPurchaseService())
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting)

        #expect(viewModel.selectedOption == .palmeirasHome)
    }

    @Test("select() purchases an unpurchased team before applying it, and updates selectedOption on success")
    func selectPurchasesThenUpdatesOnSuccess() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)
        let purchaseStore = TeamPurchaseStore(service: MockPurchaseService())
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting)

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
        let purchaseStore = TeamPurchaseStore(service: purchaseService)
        await purchaseStore.loadOnce()
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting)

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
        let purchaseStore = TeamPurchaseStore(service: purchaseService)
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting)

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
        let purchaseStore = TeamPurchaseStore(service: MockPurchaseService())
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting)

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
        let purchaseStore = TeamPurchaseStore(service: MockPurchaseService())
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting)
        await viewModel.select(.palmeirasHome)
        let callCountAfterFirstSelect = service.fetchTeamThemeColorSetCallCount

        await viewModel.select(.palmeirasHome)

        #expect(service.fetchTeamThemeColorSetCallCount == callCountAfterFirstSelect)
    }

    @Test("isPurchased(_:) and price(for:) pass through to the purchase store")
    func isPurchasedAndPricePassThrough() async {
        let setting = StubTeamThemeSetting()
        let store = TeamThemeStore(setting: setting, service: StubMatchService(matches: [], standings: []))
        let purchaseService = MockPurchaseService(purchasedProductIDs: [TeamThemeOption.flamengoHome.productID])
        let purchaseStore = TeamPurchaseStore(service: purchaseService)
        await purchaseStore.loadOnce()
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting)

        #expect(viewModel.isPurchased(.flamengoHome) == true)
        #expect(viewModel.isPurchased(.palmeirasHome) == false)
    }

    @Test("restorePurchases() delegates to the purchase store")
    func restorePurchasesDelegates() async {
        let setting = StubTeamThemeSetting()
        let store = TeamThemeStore(setting: setting, service: StubMatchService(matches: [], standings: []))
        let purchaseService = MockPurchaseService(purchasedProductIDs: [TeamThemeOption.bahiaHome.productID])
        let purchaseStore = TeamPurchaseStore(service: purchaseService)
        let viewModel = TeamThemePickerViewModel(themeStore: store, purchaseStore: purchaseStore, setting: setting)

        await viewModel.restorePurchases()

        #expect(viewModel.isPurchased(.bahiaHome) == true)
    }
}
