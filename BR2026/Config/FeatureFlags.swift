import Foundation

enum FeatureFlags {
    /// Team Theme and Team Icon purchases are hidden while Apple's Paid Apps Agreement
    /// (banking/tax information) is still pending approval — StoreKit purchases can't
    /// complete until that's accepted, so the purchase UI is hidden entirely rather than
    /// shown in a broken state. Flip back to `true` once the agreement clears.
    static let iapEnabled = false
}
