import Foundation
import StoreKit
import Observation

/// Owns which options of a purchasable catalog (`TeamThemeOption`, `TeamIconOption`) the
/// user has purchased, sourced from `PurchaseService`. No custom SwiftData cache — StoreKit
/// already persists and syncs entitlements across devices/reinstalls on its own, so
/// re-querying it is enough (unlike match/standings data, which genuinely needs an
/// offline-first cache).
@Observable
@MainActor
final class PurchaseStore<Option: PurchasableCatalogOption> {
    private(set) var purchasedIDs: Set<String> = []
    private var products: [String: Product] = [:]
    private let service: PurchaseService
    private var hasLoadedOnce = false

    init(service: PurchaseService) {
        self.service = service
    }

    func loadOnce() async {
        guard !hasLoadedOnce else { return }
        hasLoadedOnce = true
        let productIDs = Option.offeredCases().map(\.productID)
        products = (try? await service.fetchProducts(productIDs: productIDs)) ?? [:]
        await refreshPurchasedIDs()
    }

    func isPurchased(_ option: Option) -> Bool {
        purchasedIDs.contains(option.rawValue)
    }

    func price(for option: Option) -> String? {
        products[option.productID]?.displayPrice
    }

    @discardableResult
    func purchase(_ option: Option) async -> Bool {
        guard let succeeded = try? await service.purchase(productID: option.productID), succeeded else {
            return false
        }
        await refreshPurchasedIDs()
        return true
    }

    func restorePurchases() async {
        try? await service.restorePurchases()
        await refreshPurchasedIDs()
    }

    private func refreshPurchasedIDs() async {
        let ids = await service.currentPurchasedProductIDs()
        purchasedIDs = Set(ids.compactMap(Option.rawValue(fromProductID:)))
    }
}
