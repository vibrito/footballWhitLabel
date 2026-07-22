import Foundation

enum FeatureFlags {
    /// Team Theme and Team Icon purchases are hidden while Apple's Paid Apps Agreement
    /// (banking/tax information) is still pending approval — StoreKit purchases can't
    /// complete until that's accepted, so the purchase UI is hidden entirely rather than
    /// shown in a broken state. Flip back to `true` once the agreement clears.
    static let iapEnabled = true

    /// When `false`, real club crests and the competition's own logo are never fetched or
    /// shown — `TeamCrestBadge` and the More screen's competition header fall back to their
    /// generic placeholders (team initials on glass / a soccerball symbol). Disabled to
    /// remove third-party sports marks that App Review flagged under Guideline 4.1(a)
    /// (Copycats). Flip back to `true` if distribution rights for those marks are obtained.
    static let showsRemoteCrests = false
}
