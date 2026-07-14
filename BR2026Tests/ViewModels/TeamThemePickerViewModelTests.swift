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
        let viewModel = TeamThemePickerViewModel(themeStore: store, setting: setting)

        #expect(viewModel.selectedOption == nil)
    }

    @Test("selectedOption is derived from a matching persisted rawValue")
    func derivesFromPersistedValue() {
        let setting = StubTeamThemeSetting(selectedThemeID: TeamThemeOption.palmeirasThird.rawValue)
        let store = TeamThemeStore(setting: setting, service: StubMatchService(matches: [], standings: []))
        let viewModel = TeamThemePickerViewModel(themeStore: store, setting: setting)

        #expect(viewModel.selectedOption == .palmeirasThird)
    }

    @Test("select() updates selectedOption on success")
    func selectUpdatesOnSuccess() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.cachedTeamThemeColorSetOverride = palmeirasColors
        let store = TeamThemeStore(setting: setting, service: service)
        let viewModel = TeamThemePickerViewModel(themeStore: store, setting: setting)

        await viewModel.select(.palmeirasHome)

        #expect(viewModel.selectedOption == .palmeirasHome)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("select() sets errorMessage and leaves selectedOption unchanged on failure")
    func selectSetsErrorMessageOnFailure() async {
        let setting = StubTeamThemeSetting()
        let service = StubMatchService(matches: [], standings: [])
        service.shouldThrowOnTeamThemeFetch = true
        let store = TeamThemeStore(setting: setting, service: service)
        let viewModel = TeamThemePickerViewModel(themeStore: store, setting: setting)

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
        let viewModel = TeamThemePickerViewModel(themeStore: store, setting: setting)
        await viewModel.select(.palmeirasHome)
        let callCountAfterFirstSelect = service.fetchTeamThemeColorSetCallCount

        await viewModel.select(.palmeirasHome)

        #expect(service.fetchTeamThemeColorSetCallCount == callCountAfterFirstSelect)
    }
}
