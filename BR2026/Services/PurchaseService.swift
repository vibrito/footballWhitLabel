import StoreKit

/// Abstracts StoreKit 2's `Product`/`Transaction` APIs so `TeamPurchaseStore` can be tested
/// without making real StoreKit calls — mirrors `MatchService`'s role for match/standings
/// data: one live implementation (`LivePurchaseService`) talks to the real store, one mock
/// (`MockPurchaseService`) is used in all automated tests.
///
/// Main-actor isolated for the same reason as `MatchService`: `TeamPurchaseStore` (the sole
/// consumer) is `@MainActor`, so every conformance stays on the main actor for the whole call
/// rather than requiring a `nonisolated(unsafe)` workaround at the call site.
@MainActor
protocol PurchaseService {
    /// Fetches StoreKit `Product` metadata (price, display name) for the given product IDs,
    /// keyed by product ID.
    func fetchProducts(productIDs: [String]) async throws -> [String: Product]

    /// Starts the purchase flow for one product. Returns `true` if the user now owns it
    /// (purchase completed and verified), `false` if they cancelled or the purchase is
    /// pending (e.g. Ask to Buy). Throws for actual failures (network, StoreKit errors,
    /// failed verification).
    func purchase(productID: String) async throws -> Bool

    /// Re-syncs entitlements from the App Store — the "Restore Purchases" action App Store
    /// guidelines require for non-consumables.
    func restorePurchases() async throws

    /// A snapshot of every product ID the user currently owns.
    func currentPurchasedProductIDs() async -> Set<String>
}
