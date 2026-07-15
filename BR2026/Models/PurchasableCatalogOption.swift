import Foundation

/// The minimal shape `PurchaseStore` needs from any purchasable catalog of options — both
/// `TeamThemeOption` and `TeamIconOption` conform, letting `PurchaseStore<Option>` serve
/// both catalogs with one implementation instead of two near-identical copies.
/// `RawRepresentable where RawValue == String` already provides `rawValue` on both
/// conforming enums, so their conformance is just `productID`/`rawValue(fromProductID:)`,
/// which both already have (or will have, for `TeamIconOption` — see Task 2).
protocol PurchasableCatalogOption: CaseIterable, Hashable {
    var rawValue: String { get }
    var productID: String { get }
    static func rawValue(fromProductID productID: String) -> String?
}
