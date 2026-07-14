import Foundation

/// Always declared for every championship target (unlike `AppIconOption`'s per-target case
/// gating) — a zero-case `enum ...: String` fails to compile ("an enum with no cases cannot
/// declare a raw type"), and gating individual cases here would leave the Premier League/
/// Ligue 1/Liga Portugal targets with none at all. Visibility is gated at the UI layer
/// instead — see `MoreViewModel`'s `#if` around the "Team Theme" row.
enum TeamThemeOption: String, CaseIterable, Identifiable {
    case palmeirasHome, palmeirasAway, palmeirasThird

    var id: String { rawValue }

    var teamID: Int { 121 }

    var kit: TeamKit {
        switch self {
        case .palmeirasHome: .home
        case .palmeirasAway: .away
        case .palmeirasThird: .third
        }
    }

    var displayName: LocalizedStringResource {
        switch self {
        case .palmeirasHome: "Palmeiras (Home)"
        case .palmeirasAway: "Palmeiras (Away)"
        case .palmeirasThird: "Palmeiras (Third)"
        }
    }

    /// Stubbed always-true until real StoreKit 2 entitlement checking replaces this.
    var isPurchased: Bool { true }
}
