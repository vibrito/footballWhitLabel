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
    case corinthiansHome
    case saoPauloHome

    var id: String { rawValue }

    var teamID: Int {
        switch self {
        case .palmeirasHome: 121
        case .flamengoHome: 127
        case .corinthiansHome: 131
        case .saoPauloHome: 126
        }
    }

    var kit: TeamKit {
        switch self {
        case .palmeirasHome, .flamengoHome, .corinthiansHome, .saoPauloHome: .home
        }
    }

    var displayName: LocalizedStringResource {
        switch self {
        case .palmeirasHome: "Palmeiras (Home)"
        case .flamengoHome: "Flamengo (Home)"
        case .corinthiansHome: "Corinthians (Home)"
        case .saoPauloHome: "São Paulo (Home)"
        }
    }

    /// A known-good hex for the picker row's swatch, so it doesn't need a network round-trip
    /// just to render — the actual applied theme still comes from the live-fetched/cached
    /// `TeamThemeColorSet` via `TeamThemeStore`, this is display-only. Mirrors `accentOverrideHex`
    /// where one exists, since that's the color actually visible in the app's UI (chips, tab
    /// tint, hero border) — showing the near-white API main color here would make the swatch
    /// nearly invisible for Corinthians/São Paulo.
    var previewColorHex: String {
        accentOverrideHex ?? mainColorFallbackHex
    }

    private var mainColorFallbackHex: String {
        switch self {
        case .palmeirasHome: "225638"
        case .flamengoHome: "ab1b10"
        case .corinthiansHome: "fcfbee"
        case .saoPauloHome: "ffffff"
        }
    }

    /// A curated accent color, used instead of the API's `home.mainColor` wherever the UI
    /// needs a legible, branded color (blobs, the hero card's border, tab tint, `LiveChip`/
    /// `AccentPill`) — `nil` means the API's main color already works fine as an accent
    /// (Palmeiras green, Flamengo red are both plenty saturated). Corinthians and São Paulo
    /// are both near-white (`fcfbee`, `ffffff`), which reads as invisible in those UI
    /// elements, so both use a red pulled from their actual jerseys instead — Corinthians'
    /// muted crest-ribbon red, São Paulo's bolder, more saturated jersey-band red (the two
    /// jerseys' reds are visibly different in tone/vividness, so the accents are too).
    var accentOverrideHex: String? {
        switch self {
        case .palmeirasHome, .flamengoHome: nil
        case .corinthiansHome: "C8102E"
        case .saoPauloHome: "E4022B"
        }
    }

    /// Stubbed always-true until real StoreKit 2 entitlement checking replaces this.
    var isPurchased: Bool { true }

    /// Corinthians' near-white main color (`fcfbee`) and São Paulo's pure white (`ffffff`)
    /// both looked washed out with the default top-anchored gradient; the other teams' darker
    /// colors don't have this problem, so the centered-vignette style is opt-in per team
    /// rather than automatic.
    var gradientStyle: GradientStyle {
        switch self {
        case .corinthiansHome, .saoPauloHome: .centeredVignette
        case .palmeirasHome, .flamengoHome: .topAnchored
        }
    }
}
