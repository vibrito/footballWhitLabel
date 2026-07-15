import Foundation

/// Always declared for every championship target (unlike `AppIconOption`'s per-target case
/// gating) — a zero-case `enum ...: String` fails to compile ("an enum with no cases cannot
/// declare a raw type"), and gating individual cases here would leave the Premier League/
/// Ligue 1/Liga Portugal targets with none at all. Visibility is gated at the UI layer
/// instead — see `MoreViewModel`'s `#if` around the "Team Theme" row.
///
/// Only the home kit is offered as a purchasable option right now — Palmeiras' away colors
/// didn't look good, and the plan going forward is one (home) option per team rather than a
/// full kit set. `TeamKit`/`TeamThemeColorSet`/`MatchService.fetchTeamThemeColorSet` still
/// fetch and cache all 3 kits where available — only this UI-facing catalog was trimmed, so
/// away/third can come back later without redoing the data layer.
enum TeamThemeOption: String, CaseIterable, Identifiable {
    case palmeirasHome
    case flamengoHome

    var id: String { rawValue }

    var teamID: Int {
        switch self {
        case .palmeirasHome: 121
        case .flamengoHome: 127
        }
    }

    var kit: TeamKit {
        switch self {
        case .palmeirasHome, .flamengoHome: .home
        }
    }

    var displayName: LocalizedStringResource {
        switch self {
        case .palmeirasHome: "Palmeiras (Home)"
        case .flamengoHome: "Flamengo (Home)"
        }
    }

    /// A known-good hex for the picker row's swatch, so it doesn't need a network round-trip
    /// just to render — the actual applied theme still comes from the live-fetched/cached
    /// `TeamThemeColorSet` via `TeamThemeStore`, this is display-only.
    var previewColorHex: String {
        switch self {
        case .palmeirasHome: "225638"
        case .flamengoHome: "ab1b10"
        }
    }

    /// Stubbed always-true until real StoreKit 2 entitlement checking replaces this.
    var isPurchased: Bool { true }
}
