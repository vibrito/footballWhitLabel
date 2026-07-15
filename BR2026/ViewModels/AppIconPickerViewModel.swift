// BR2026/ViewModels/AppIconPickerViewModel.swift
import Foundation
import Observation

@Observable
@MainActor
final class AppIconPickerViewModel {
    private(set) var selectedIconAssetName: String?
    private(set) var errorMessage: String?
    private(set) var standings: [Standing]
    private let iconSetting: AppIconSetting
    private let purchaseStore: PurchaseStore<TeamIconOption>
    private let service: MatchService
    private var hasLoadedStandingsOnce = false

    init(iconSetting: AppIconSetting, purchaseStore: PurchaseStore<TeamIconOption>, service: MatchService) {
        self.iconSetting = iconSetting
        self.purchaseStore = purchaseStore
        self.service = service
        selectedIconAssetName = iconSetting.currentIconName
        standings = service.cachedStandings()
    }

    /// Same cached-then-refresh pattern as `TeamThemePickerViewModel.loadOnce()` — needed
    /// because a user can reach More → App Icon without ever visiting the Standings tab.
    func loadOnce() async {
        guard !hasLoadedStandingsOnce else { return }
        hasLoadedStandingsOnce = true
        if let fresh = try? await service.fetchStandings() {
            standings = fresh
        }
    }

    func isSelected(_ option: AppIconOption) -> Bool {
        option.iconAssetName == selectedIconAssetName
    }

    func isSelected(_ option: TeamIconOption) -> Bool {
        option.iconAssetName == selectedIconAssetName
    }

    /// Purchased teams first, then by standings position — identical logic to
    /// `TeamThemePickerViewModel.sortedOptions`.
    var sortedTeamOptions: [TeamIconOption] {
        let positionsByTeamID = Dictionary(standings.map { ($0.teamID, $0.position) }, uniquingKeysWith: { first, _ in first })
        return TeamIconOption.allCases.sorted { lhs, rhs in
            let lhsPurchased = purchaseStore.isPurchased(lhs)
            let rhsPurchased = purchaseStore.isPurchased(rhs)
            guard lhsPurchased == rhsPurchased else { return lhsPurchased }
            let lhsPosition = positionsByTeamID[lhs.teamID] ?? Int.max
            let rhsPosition = positionsByTeamID[rhs.teamID] ?? Int.max
            return lhsPosition < rhsPosition
        }
    }

    func isPurchased(_ option: TeamIconOption) -> Bool {
        purchaseStore.isPurchased(option)
    }

    func price(for option: TeamIconOption) -> String? {
        purchaseStore.price(for: option)
    }

    /// Default/Stadium — always free, no purchase check.
    func select(_ option: AppIconOption) async {
        await applyIconName(option.iconAssetName)
    }

    /// A team icon — purchase-gated, same shape as `TeamThemePickerViewModel.select(_:)`.
    func select(_ option: TeamIconOption) async {
        guard !isSelected(option) else { return }
        errorMessage = nil
        if !purchaseStore.isPurchased(option) {
            guard await purchaseStore.purchase(option) else { return }
        }
        await applyIconName(option.iconAssetName)
    }

    func restorePurchases() async {
        await purchaseStore.restorePurchases()
    }

    private func applyIconName(_ name: String?) async {
        guard name != selectedIconAssetName else { return }
        do {
            try await iconSetting.setIconName(name)
            selectedIconAssetName = name
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Couldn't change the app icon. Try again.")
        }
    }
}
