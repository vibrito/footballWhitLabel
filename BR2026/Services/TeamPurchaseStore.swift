import Foundation
import StoreKit
import Observation

/// Owns which teams' themes the user has purchased, sourced from `PurchaseService`. No
/// custom SwiftData cache — StoreKit already persists and syncs entitlements across
/// devices/reinstalls on its own, so re-querying it is enough (unlike match/standings data,
/// which genuinely needs an offline-first cache).
@Observable
@MainActor
final class TeamPurchaseStore {
    private(set) var purchasedTeamIDs: Set<String> = []
    private var products: [String: Product] = [:]
    private let service: PurchaseService
    private var hasLoadedOnce = false

    init(service: PurchaseService) {
        self.service = service
    }

    func loadOnce() async {
        guard !hasLoadedOnce else { return }
        hasLoadedOnce = true
        let productIDs = TeamThemeOption.allCases.map(\.productID)
        products = (try? await service.fetchProducts(productIDs: productIDs)) ?? [:]
        await refreshPurchasedTeamIDs()
    }

    func isPurchased(_ option: TeamThemeOption) -> Bool {
        purchasedTeamIDs.contains(option.rawValue)
    }

    func price(for option: TeamThemeOption) -> String? {
        products[option.productID]?.displayPrice
    }

    @discardableResult
    func purchase(_ option: TeamThemeOption) async -> Bool {
        guard let succeeded = try? await service.purchase(productID: option.productID), succeeded else {
            return false
        }
        await refreshPurchasedTeamIDs()
        return true
    }

    func restorePurchases() async {
        try? await service.restorePurchases()
        await refreshPurchasedTeamIDs()
    }

    private func refreshPurchasedTeamIDs() async {
        let ids = await service.currentPurchasedProductIDs()
        purchasedTeamIDs = Set(ids.compactMap(TeamThemeOption.rawValue(fromProductID:)))
    }
}
