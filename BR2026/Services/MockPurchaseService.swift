import StoreKit

/// Test double for `PurchaseService` — used in every automated test, never in the shipped
/// app (unlike `MockMatchService`, which also serves as `ChampionshipApp`'s offline
/// fallback). `fetchProducts` always returns `[:]`: `StoreKit.Product` has no public
/// initializer, so a mock can't hand back a fake one — price display is verified manually via
/// the `.storekit` configuration file instead (see Task 8).
final class MockPurchaseService: PurchaseService {
    private var purchased: Set<String>
    /// When `true`, `purchase(productID:)` returns `false` (simulating a cancelled/failed
    /// purchase) instead of granting the entitlement.
    var shouldFailNextPurchase = false

    init(purchasedProductIDs: Set<String> = []) {
        self.purchased = purchasedProductIDs
    }

    func fetchProducts(productIDs: [String]) async throws -> [String: Product] { [:] }

    func purchase(productID: String) async throws -> Bool {
        guard !shouldFailNextPurchase else { return false }
        purchased.insert(productID)
        return true
    }

    func restorePurchases() async throws {}

    func currentPurchasedProductIDs() async -> Set<String> { purchased }
}
