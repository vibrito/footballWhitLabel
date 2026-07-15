import StoreKit

/// Real StoreKit 2 implementation of `PurchaseService`. Used everywhere except the test
/// target — no "if not configured, fall back to mock" branch like `LiveMatchService`/
/// `MockMatchService` have, since StoreKit's local `.storekit` configuration file (see
/// `BR2026.storekit`) already makes this fully functional in Simulator with no external
/// setup or API key.
final class LivePurchaseService: PurchaseService {
    func fetchProducts(productIDs: [String]) async throws -> [String: Product] {
        let products = try await Product.products(for: productIDs)
        return Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
    }

    func purchase(productID: String) async throws -> Bool {
        let products = try await Product.products(for: [productID])
        guard let product = products.first else { throw PurchaseServiceError.productNotFound }
        let result = try await product.purchase()
        switch result {
        case .success(.verified(let transaction)):
            await transaction.finish()
            return true
        case .success(.unverified):
            throw PurchaseServiceError.unverifiedTransaction
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
    }

    func currentPurchasedProductIDs() async -> Set<String> {
        var owned: Set<String> = []
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement {
                owned.insert(transaction.productID)
            }
        }
        return owned
    }
}

enum PurchaseServiceError: Error {
    case productNotFound
    case unverifiedTransaction
}
