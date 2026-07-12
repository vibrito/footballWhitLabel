import Testing
@testable import BR2026

@Suite("AppIconPickerViewModel")
@MainActor
struct AppIconPickerViewModelTests {
    @Test("Defaults to .light when there's no current alternate icon name")
    func defaultsToLightWhenNoAlternateIcon() {
        let setting = StubAppIconSetting(currentIconName: nil)
        let viewModel = AppIconPickerViewModel(iconSetting: setting)

        #expect(viewModel.selectedIcon == .light)
    }

    @Test("Derives the selected icon from a matching current icon name")
    func derivesSelectedIconFromCurrentName() {
        let setting = StubAppIconSetting(currentIconName: "AppIcon-Stadium")
        let viewModel = AppIconPickerViewModel(iconSetting: setting)

        #expect(viewModel.selectedIcon == .stadium)
    }

    @Test("select() updates selectedIcon and calls setIconName on success")
    func selectUpdatesSelectedIconOnSuccess() async {
        let setting = StubAppIconSetting(currentIconName: nil)
        let viewModel = AppIconPickerViewModel(iconSetting: setting)

        await viewModel.select(.brasil)

        #expect(viewModel.selectedIcon == .brasil)
        #expect(setting.setIconNameCalls == ["AppIcon-Brasil"])
        #expect(viewModel.errorMessage == nil)
    }

    @Test("select() sets errorMessage and keeps the prior selection when setIconName throws")
    func selectSetsErrorMessageOnFailure() async {
        let setting = StubAppIconSetting(currentIconName: nil)
        setting.shouldThrow = true
        let viewModel = AppIconPickerViewModel(iconSetting: setting)

        await viewModel.select(.brasil)

        #expect(viewModel.selectedIcon == .light)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("select() on the already-selected option does not call setIconName again")
    func selectOnAlreadySelectedIsNoOp() async {
        let setting = StubAppIconSetting(currentIconName: nil)
        let viewModel = AppIconPickerViewModel(iconSetting: setting)

        await viewModel.select(.light)

        #expect(setting.setIconNameCalls.isEmpty)
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
