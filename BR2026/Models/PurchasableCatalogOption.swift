import Foundation

/// The minimal shape `PurchaseStore` needs from any purchasable catalog of options — both
/// `TeamThemeOption` and `TeamIconOption` conform, letting `PurchaseStore<Option>` serve
/// both catalogs with one implementation instead of two near-identical copies.
/// `RawRepresentable where RawValue == String` already provides `rawValue` on both
/// conforming enums, so their conformance is just `productID`/`rawValue(fromProductID:)`,
/// which both already have (or will have, for `TeamIconOption` — see Task 2).
protocol PurchasableCatalogOption: CaseIterable, Hashable, Sendable {
    var rawValue: String { get }
    var productID: String { get }
    static func rawValue(fromProductID productID: String) -> String?
}

extension PurchasableCatalogOption {
    /// `allCases`, filtered to those currently on offer per `FeatureFlags.iapProductAllowlist`.
    /// An empty allowlist offers every case (normal operation); a non-empty one offers only
    /// the cases whose `productID` it lists. Used everywhere the purchase catalog is displayed
    /// or its products fetched, so a hidden IAP never surfaces a row a user (or App reviewer)
    /// could tap. Parameterized on `allowlist` for testability; defaults to the live flag.
    static func offeredCases(allowlist: Set<String> = FeatureFlags.iapProductAllowlist) -> [Self] {
        allowlist.isEmpty ? Array(allCases) : allCases.filter { allowlist.contains($0.productID) }
    }
}
