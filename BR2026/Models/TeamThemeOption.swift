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
    case fluminenseHome
    case athleticoParanaenseHome
    case bahiaHome
    case redBullBragantinoHome
    case coritibaHome
    case saoPauloHome
    case atleticoMineiroHome
    case corinthiansHome

    var id: String { rawValue }

    var teamID: Int {
        switch self {
        case .palmeirasHome: 121
        case .flamengoHome: 127
        case .fluminenseHome: 124
        case .athleticoParanaenseHome: 134
        case .bahiaHome: 118
        case .redBullBragantinoHome: 794
        case .coritibaHome: 147
        case .saoPauloHome: 126
        case .atleticoMineiroHome: 1062
        case .corinthiansHome: 131
        }
    }

    var kit: TeamKit {
        switch self {
        case .palmeirasHome, .flamengoHome, .fluminenseHome, .athleticoParanaenseHome, .bahiaHome,
             .redBullBragantinoHome, .coritibaHome, .saoPauloHome, .atleticoMineiroHome, .corinthiansHome:
            .home
        }
    }

    var displayName: LocalizedStringResource {
        switch self {
        case .palmeirasHome: "Palmeiras (Home)"
        case .flamengoHome: "Flamengo (Home)"
        case .fluminenseHome: "Fluminense (Home)"
        case .athleticoParanaenseHome: "Athletico Paranaense (Home)"
        case .bahiaHome: "Bahia (Home)"
        case .redBullBragantinoHome: "Red Bull Bragantino (Home)"
        case .coritibaHome: "Coritiba (Home)"
        case .saoPauloHome: "São Paulo (Home)"
        case .atleticoMineiroHome: "Atlético Mineiro (Home)"
        case .corinthiansHome: "Corinthians (Home)"
        }
    }

    /// A known-good hex for the picker row's swatch, so it doesn't need a network round-trip
    /// just to render — the actual applied theme still comes from the live-fetched/cached
    /// `TeamThemeColorSet` via `TeamThemeStore`, this is display-only. Matches
    /// `mainColorOverrideHex` where one exists.
    var previewColorHex: String {
        mainColorOverrideHex ?? apiMainColorFallbackHex
    }

    private var apiMainColorFallbackHex: String {
        switch self {
        case .palmeirasHome: "225638"
        case .flamengoHome: "ab1b10"
        case .fluminenseHome: "6e202e"
        case .athleticoParanaenseHome: "cc0000"
        case .bahiaHome: "ffffff"
        case .redBullBragantinoHome: "fcfcfc"
        case .coritibaHome: "ffffff"
        case .saoPauloHome: "ffffff"
        case .atleticoMineiroHome: "000000"
        case .corinthiansHome: "fcfbee"
        }
    }

    /// A curated main color, used instead of the API's `home.mainColor` — `nil` means the
    /// API's color already works fine. Palmeiras' and Flamengo's API colors (`225638`/`ab1b10`)
    /// were fine to launch with, but the user later asked for truer club-brand greens/reds
    /// (`006437`/`C52613`) once more teams' curated colors made the difference visible side by
    /// side. Fluminense's tricolor crest is grenat/burgundy + green
    /// + white; the API's own sampled `mainColor` (`6e202e`) is a reasonable burgundy but not
    /// the club's actual grenat, so this overrides it with the real value. Athletico
    /// Paranaense's API red (`cc0000`) is close but not the club's actual red. Bahia's, Red
    /// Bull Bragantino's, Coritiba's, and São Paulo's API `mainColor` are all `fcfcfc`/`ffffff`
    /// (pure/near white, same near-invisible-accent problem originally hit with the deferred
    /// Corinthians case) — each club's actual signature dark/vivid color fixes it. São Paulo's
    /// crest is red/white/black tricolor; the API's home-kit sampling missed the red band
    /// entirely (it only saw white main + black font), so this restores it as the main color —
    /// unlike Corinthians, which has no non-black/white signature color to fall back to.
    /// Atlético Mineiro is a genuinely black/white-only club with no hidden third crest color —
    /// so instead of the API's literal `000000` (which would make blobs/gradient/hero-border/
    /// tab-tint all disappear into this app's already-dark background), this uses a lightened
    /// charcoal that still reads as "the black team" while staying visually distinct from the
    /// background. Corinthians is the mirror case — also black/white-only, but the API's
    /// `mainColor` is near-white (`fcfbee`) rather than black — so it gets the same "push the
    /// extreme toward neutral gray" technique applied from the opposite end, landing on a
    /// mid-dark gray rather than a light one: a light gray was tried in earlier (reverted)
    /// attempts and reliably blew out the gradient's top-anchored light source, so this stays on
    /// the darker, already-proven-safe side of neutral rather than truly mirroring Atlético's
    /// exact brightness.
    var mainColorOverrideHex: String? {
        switch self {
        case .palmeirasHome: "006437"
        case .flamengoHome: "C52613"
        case .fluminenseHome: "870A28"
        case .athleticoParanaenseHome: "CE181E"
        case .bahiaHome: "006CB5"
        case .redBullBragantinoHome: "001D46"
        case .coritibaHome: "00544D"
        case .saoPauloHome: "FE0000"
        case .atleticoMineiroHome: "2B2B2E"
        case .corinthiansHome: "6E6E6C"
        }
    }

    /// The tab bar's selected-item color and other selection-indicator UI (e.g. the round
    /// pill in Fixtures) — `nil` falls back to the main color. Fluminense's second signature
    /// color (green) reads better here than as the general content accent, which stays
    /// grenat — mirrors `ChampionshipConfig.tabSelectionColorHex` existing for the same
    /// "brand color doesn't read well in every UI role" reason. Bahia's (red) and Red Bull
    /// Bragantino's (red) second signature colors play the same role against their blue/navy
    /// main colors. Coritiba's given color is a single teal/green with no second signature
    /// color provided, so it falls back to the main color like Palmeiras/Flamengo. São Paulo
    /// uses black here — unlike the earlier rejected black *tab-bar icon* experiment for
    /// Flamengo/Athletico (a thin glyph directly on the dark app background, which disappeared),
    /// this fills a solid pill behind light text, so the contrast problem doesn't apply; white
    /// was tried first but made the pill's own selected-state text (which uses the app's light
    /// `textColor`) unreadable against a white fill. Atlético Mineiro's charcoal main color
    /// (see `mainColorOverrideHex`) is close enough to the tab bar's own dark glass fill that
    /// the selected tab icon/label became nearly invisible using it directly — white fixes that
    /// without touching the charcoal used for the background/blobs/hero border.
    var tabSelectionColorOverrideHex: String? {
        switch self {
        case .palmeirasHome, .flamengoHome, .athleticoParanaenseHome, .coritibaHome, .corinthiansHome: nil
        case .fluminenseHome: "00613C"
        case .bahiaHome: "ED3237"
        case .redBullBragantinoHome: "D2003C"
        case .saoPauloHome: "000000"
        case .atleticoMineiroHome: "FFFFFF"
        }
    }

    /// The Fixtures round pill's selected-state fill, used instead of `tabSelectionColorOverrideHex`
    /// — `nil` falls back to that (which is what every other team wants). Atlético Mineiro's
    /// `tabSelectionColorOverrideHex` is white (for tab bar legibility against its charcoal main
    /// color), but the round pill needs a *dark* fill to stay readable behind the app's light
    /// `textColor` — reusing the charcoal main color here does that. Corinthians has no
    /// `tabSelectionColorOverrideHex` to fall back to (its gray main color works fine for the
    /// tab tint directly), but that same gray is too light for the pill fill against its own
    /// light `textColor` override — so this gives it a dedicated black fill, independent of the
    /// main/tab-selection colors entirely.
    var pillFillColorOverrideHex: String? {
        switch self {
        case .palmeirasHome, .flamengoHome, .fluminenseHome, .athleticoParanaenseHome, .bahiaHome,
             .redBullBragantinoHome, .coritibaHome, .saoPauloHome:
            nil
        case .atleticoMineiroHome: "2B2B2E"
        case .corinthiansHome: "000000"
        }
    }

    /// A curated body-text color, used instead of the API's `home.fontColor` — `nil` means the
    /// API's color already works fine. Athletico Paranaense's API font color (`6c6360`) is a
    /// muted grayish-brown rather than a clean white/black, which reads poorly at the low
    /// opacities most body text uses — an off-white (not pure white, so it still reads as
    /// slightly "tinted"/branded rather than identical to the untheemed default) fixes it.
    /// Bahia's API font color (`043a73`, a dark navy), Coritiba's, and Corinthians' (both
    /// `000000`, plain black) have the same problem for the opposite reason — a dark color
    /// is nearly invisible as body text against this app's dark background — so they get the
    /// same off-white treatment. Red Bull Bragantino's API font color (`f50000`, a bright red)
    /// turned out not to be legible in practice either — overridden to plain white. São Paulo
    /// started with the same off-white as Athletico/Bahia/Coritiba/Corinthians, but the user
    /// asked for full white instead — grouped with Red Bull Bragantino rather than with the
    /// off-white teams.
    var fontColorOverrideHex: String? {
        switch self {
        case .palmeirasHome, .flamengoHome, .fluminenseHome, .atleticoMineiroHome: nil
        case .athleticoParanaenseHome, .bahiaHome, .coritibaHome, .corinthiansHome: "F2F2F2"
        case .redBullBragantinoHome, .saoPauloHome: "FFFFFF"
        }
    }

    /// Stubbed always-true until real StoreKit 2 entitlement checking replaces this.
    var isPurchased: Bool { true }
}
