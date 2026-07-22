import Foundation

enum FeatureFlags {
    /// Team Theme and Team Icon purchases are hidden while Apple's Paid Apps Agreement
    /// (banking/tax information) is still pending approval — StoreKit purchases can't
    /// complete until that's accepted, so the purchase UI is hidden entirely rather than
    /// shown in a broken state. Flip back to `true` once the agreement clears.
    static let iapEnabled = true

    /// Allowlist of in-app purchases to offer, keyed by StoreKit product ID.
    /// EMPTY = all IAPs shown (normal operation). When non-empty, ONLY the listed product
    /// IDs appear in the Team Theme / App Icon pickers and are fetched from StoreKit — every
    /// other IAP is hidden. Use this to ship a reduced IAP set for App Review (Apple requires
    /// the first non-consumable IAP to be submitted with an app version; keeping the visible
    /// catalog in sync with what's actually submitted avoids a purchase row the reviewer can't
    /// load). Composes with `iapEnabled`: if that's `false`, nothing shows regardless of this
    /// list. Reset to `[]` to restore the full catalog. See `PurchasableCatalogOption.offeredCases`.
    static let iapProductAllowlist: Set<String> = []

    /// When `false`, real club crests and the competition's own logo are never fetched or
    /// shown — `TeamCrestBadge` and the More screen's competition header fall back to their
    /// generic placeholders (team initials on glass / a soccerball symbol). Disabled to
    /// remove third-party sports marks that App Review flagged under Guideline 4.1(a)
    /// (Copycats). Flip back to `true` if distribution rights for those marks are obtained.
    static let showsRemoteCrests = false
}
