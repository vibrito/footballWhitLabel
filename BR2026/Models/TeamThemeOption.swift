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
    case cruzeiroHome
    case internacionalHome
    case remoHome
    case botafogoHome
    case vitoriaHome

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
        case .cruzeiroHome: 135
        case .internacionalHome: 119
        case .remoHome: 1198
        case .botafogoHome: 120
        case .vitoriaHome: 136
        }
    }

    var kit: TeamKit {
        switch self {
        case .palmeirasHome, .flamengoHome, .fluminenseHome, .athleticoParanaenseHome, .bahiaHome,
             .redBullBragantinoHome, .coritibaHome, .saoPauloHome, .atleticoMineiroHome, .corinthiansHome,
             .cruzeiroHome, .internacionalHome, .remoHome, .botafogoHome, .vitoriaHome:
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
        case .cruzeiroHome: "Cruzeiro (Home)"
        case .internacionalHome: "Internacional (Home)"
        case .remoHome: "Remo (Home)"
        case .botafogoHome: "Botafogo (Home)"
        case .vitoriaHome: "Vitória (Home)"
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
        case .cruzeiroHome: "0455a3"
        case .internacionalHome: "e00618"
        case .remoHome: "000000"
        case .botafogoHome: "f7f7f7"
        case .vitoriaHome: "ff0000"
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
    /// exact brightness. Cruzeiro's API blue (`0455a3`) already worked fine — this is a curated
    /// club-brand blue given directly by the user, the same "good enough API color, truer brand
    /// color requested anyway" case as Palmeiras/Flamengo. Internacional's API red (`e00618`)
    /// likewise already worked fine — same case, curated to `E5050F`. Remo's brand color was
    /// given as CMYK (90/78/48/68), which converts to `#08122A` — a very dark navy nearly as
    /// dark as the app's own background gradient, the same "too dark to work as an accent"
    /// problem Atlético Mineiro had, independently confirmed by the API's own home-kit sampling
    /// also landing on literal black. First attempt lightened it the same way as Atlético's
    /// charcoal — blending toward white — but that desaturates a color that actually has real
    /// hue (unlike Atlético's true black/gray), and the result (`#777D8A`) read as neutral gray,
    /// not navy. Fixed by scaling the RGB values up instead (preserving the original hue/
    /// saturation ratio rather than diluting it toward white) to `#2048A8` — a properly
    /// saturated, clearly blue navy. Botafogo's API home sample landed near-white (`f7f7f7`,
    /// from its black/white striped shirt), but the club's actual signature color is black —
    /// same underlying case as Atlético Mineiro, using the same technique per the user's
    /// direction ("similar approach to Atlético Mineiro is fine") — but a distinctly darker
    /// charcoal (`#1E1E20` vs Atlético's `#2B2B2E`) per later feedback, so the two black/white
    /// clubs don't look identical in the picker. Vitória's API red (`ff0000`) is a clean,
    /// already-usable saturated red with no near-white/black problem, so it's used as-is —
    /// `nil`, same as Palmeiras/Flamengo at launch.
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
        case .cruzeiroHome: "2F529E"
        case .internacionalHome: "E5050F"
        case .remoHome: "2048A8"
        case .botafogoHome: "1E1E20"
        case .vitoriaHome: nil
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
        case .palmeirasHome, .flamengoHome, .athleticoParanaenseHome, .coritibaHome, .corinthiansHome, .cruzeiroHome,
             .internacionalHome, .remoHome, .vitoriaHome:
            nil
        case .fluminenseHome: "00613C"
        case .bahiaHome: "ED3237"
        case .redBullBragantinoHome: "D2003C"
        case .saoPauloHome: "000000"
        case .atleticoMineiroHome, .botafogoHome: "FFFFFF"
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
             .redBullBragantinoHome, .coritibaHome, .saoPauloHome, .cruzeiroHome, .internacionalHome,
             .remoHome, .vitoriaHome:
            nil
        case .atleticoMineiroHome: "2B2B2E"
        case .botafogoHome: "1E1E20"
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
        case .palmeirasHome, .flamengoHome, .fluminenseHome, .atleticoMineiroHome, .cruzeiroHome, .internacionalHome,
             .remoHome, .botafogoHome, .vitoriaHome:
            nil
        case .athleticoParanaenseHome, .bahiaHome, .coritibaHome, .corinthiansHome: "F2F2F2"
        case .redBullBragantinoHome, .saoPauloHome: "FFFFFF"
        }
    }

    /// How far the gradient's bottom stop is shaded toward black (see
    /// `ThemeTokens.themed(gradientDarkAmount:)`) — `nil` means the default `-0.75`. Cruzeiro's
    /// blue looked too dark/heavy at the bottom of the screen with the default amount, so this
    /// lightens it to `-0.5`, keeping more of the actual main color visible instead of fading
    /// most of the way to black.
    var gradientDarkAmountOverride: Double? {
        switch self {
        case .palmeirasHome, .flamengoHome, .fluminenseHome, .athleticoParanaenseHome, .bahiaHome,
             .redBullBragantinoHome, .coritibaHome, .saoPauloHome, .atleticoMineiroHome, .corinthiansHome,
             .internacionalHome, .remoHome, .botafogoHome, .vitoriaHome:
            nil
        case .cruzeiroHome: -0.5
        }
    }

    /// Stubbed always-true until real StoreKit 2 entitlement checking replaces this.
    var isPurchased: Bool { true }
}
