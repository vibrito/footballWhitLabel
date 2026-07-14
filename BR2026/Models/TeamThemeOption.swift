import Foundation

enum TeamThemeOption: String, CaseIterable, Identifiable {
    #if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA)
    case palmeirasHome, palmeirasAway, palmeirasThird
    #endif

    var id: String { rawValue }

    var teamID: Int {
        switch self {
        #if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA)
        case .palmeirasHome, .palmeirasAway, .palmeirasThird: 121
        #endif
        }
    }

    var kit: TeamKit {
        switch self {
        #if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA)
        case .palmeirasHome: .home
        case .palmeirasAway: .away
        case .palmeirasThird: .third
        #endif
        }
    }

    var displayName: LocalizedStringResource {
        switch self {
        #if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA)
        case .palmeirasHome: "Palmeiras (Home)"
        case .palmeirasAway: "Palmeiras (Away)"
        case .palmeirasThird: "Palmeiras (Third)"
        #endif
        }
    }

    /// Stubbed always-true until real StoreKit 2 entitlement checking replaces this.
    var isPurchased: Bool { true }
}
