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
enum TeamThemeOption: String, CaseIterable, Identifiable, PurchasableCatalogOption {
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
    case mirassolHome
    case chapecoenseHome
    case santosHome
    case gremioHome
    case vascoDaGamaHome

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
        case .mirassolHome: 7848
        case .chapecoenseHome: 132
        case .santosHome: 128
        case .gremioHome: 130
        case .vascoDaGamaHome: 133
        }
    }

    var kit: TeamKit {
        switch self {
        case .palmeirasHome, .flamengoHome, .fluminenseHome, .athleticoParanaenseHome, .bahiaHome,
             .redBullBragantinoHome, .coritibaHome, .saoPauloHome, .atleticoMineiroHome, .corinthiansHome,
             .cruzeiroHome, .internacionalHome, .remoHome, .botafogoHome, .vitoriaHome, .mirassolHome,
             .chapecoenseHome, .santosHome, .gremioHome, .vascoDaGamaHome:
            .home
        }
    }

    /// No "(Home)" suffix for now — every option is a home kit today, so it read as noise;
    /// revisit if away/third variants are ever reintroduced (see this enum's own top-level
    /// doc comment on why only home kits are offered).
    var displayName: LocalizedStringResource {
        switch self {
        case .palmeirasHome: "Palmeiras"
        case .flamengoHome: "Flamengo"
        case .fluminenseHome: "Fluminense"
        case .athleticoParanaenseHome: "Athletico Paranaense"
        case .bahiaHome: "Bahia"
        case .redBullBragantinoHome: "Red Bull Bragantino"
        case .coritibaHome: "Coritiba"
        case .saoPauloHome: "São Paulo"
        case .atleticoMineiroHome: "Atlético Mineiro"
        case .corinthiansHome: "Corinthians"
        case .cruzeiroHome: "Cruzeiro"
        case .internacionalHome: "Internacional"
        case .remoHome: "Remo"
        case .botafogoHome: "Botafogo"
        case .vitoriaHome: "Vitória"
        case .mirassolHome: "Mirassol"
        case .chapecoenseHome: "Chapecoense"
        case .santosHome: "Santos"
        case .gremioHome: "Grêmio"
        case .vascoDaGamaHome: "Vasco da Gama"
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
    /// `nil`, same as Palmeiras/Flamengo at launch. Mirassol's API `mainColor` is pure yellow
    /// (`ffff00`, ~93% luminance) — bright enough to risk washing out the gradient's top-anchored
    /// light source, the same problem light main colors caused for the deferred Corinthians
    /// attempts. User first gave `F3EC0A` (barely deepened, still ~87% luminance), then asked
    /// for it darker still — scaled down (preserving hue, same technique as Remo's lightening
    /// but in reverse) to `9E9906`, a richer dark gold/olive that reads as "yellow" without the
    /// wash-out risk. `126F3D` (green) is used as `tabSelectionColorOverrideHex`, and white as
    /// `fontColorOverrideHex`. Chapecoense's API
    /// `mainColor` is near-white (`f9fbfa`), same near-invisible-accent problem as the other
    /// near-white teams — the club's actual green fixes it, given directly by the user
    /// ("approach pretty similar to Palmeiras" — just a main color override, no tab-selection/
    /// pill-fill/font overrides needed, since the API's font is already a clean white). Santos
    /// is genuinely white/black-only (no hidden color, same profile as Corinthians), so it gets
    /// the same "push toward moderate gray" technique — deliberately a touch lighter than
    /// Corinthians' `6E6E6C` (`82827F`) per user request, so the two gray teams aren't
    /// identical. Grêmio's API `mainColor` (`b8edff`) is a very pale blue sampled from a light
    /// section of the kit, not the club's real tricolor blue — user gave the real brand hex
    /// (`0D80BF`) directly. Vasco da Gama's API `mainColor` is literal black (`000000`), same
    /// profile as Atlético Mineiro/Botafogo — charcoal fixes the hero-border/tab-tint role,
    /// using yet another distinct shade (`242426`) so all three black clubs read as visually
    /// different. Vasco's actual background rendering bypasses this main color entirely though —
    /// see `ThemeTokens.usesDiagonalSashBackground` — since its crest is a diagonal sash, not a
    /// solid color.
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
        case .mirassolHome: "9E9906"
        case .chapecoenseHome: "1B552A"
        case .santosHome: "82827F"
        case .gremioHome: "0D80BF"
        case .vascoDaGamaHome: "242426"
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
             .internacionalHome, .remoHome, .vitoriaHome, .chapecoenseHome, .santosHome, .gremioHome:
            nil
        case .fluminenseHome: "00613C"
        case .bahiaHome: "ED3237"
        case .redBullBragantinoHome: "D2003C"
        case .saoPauloHome: "000000"
        case .atleticoMineiroHome, .botafogoHome, .vascoDaGamaHome: "FFFFFF"
        case .mirassolHome: "126F3D"
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
             .remoHome, .vitoriaHome, .mirassolHome, .chapecoenseHome, .gremioHome:
            nil
        case .atleticoMineiroHome: "2B2B2E"
        case .botafogoHome: "1E1E20"
        case .vascoDaGamaHome: "242426"
        case .corinthiansHome, .santosHome: "000000"
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
    /// off-white teams. Mirassol's API font (`076450`, dark green) has the same dark-on-dark
    /// legibility problem as Bahia/Coritiba's — plain white fixes it. (Briefly tried the team's
    /// own green here instead, matching `tabSelectionColorOverrideHex` — reverted, "not good.")
    var fontColorOverrideHex: String? {
        switch self {
        case .palmeirasHome, .flamengoHome, .fluminenseHome, .atleticoMineiroHome, .cruzeiroHome, .internacionalHome,
             .remoHome, .botafogoHome, .vitoriaHome, .chapecoenseHome, .gremioHome, .vascoDaGamaHome:
            nil
        case .athleticoParanaenseHome, .bahiaHome, .coritibaHome, .corinthiansHome, .santosHome: "F2F2F2"
        case .redBullBragantinoHome, .saoPauloHome, .mirassolHome: "FFFFFF"
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
             .internacionalHome, .remoHome, .botafogoHome, .vitoriaHome, .mirassolHome, .chapecoenseHome,
             .santosHome, .gremioHome, .vascoDaGamaHome:
            nil
        case .cruzeiroHome: -0.5
        }
    }

    /// Vasco da Gama's crest is a diagonal black/white/black sash rather than a solid brand
    /// color — no curated hex represents that, so this opts the whole background into
    /// `StadiumBackground`'s diagonal `LinearGradient` instead of the usual radial
    /// gradient + blobs. `false` for every other team.
    var usesDiagonalSashBackground: Bool {
        self == .vascoDaGamaHome
    }

    /// Overrides the background gradient's outer stop (normally the main color shaded
    /// toward black) with a literal, unrelated color instead — Internacional-only, an
    /// experimental preview per user request ("try a gradient to light grey") after an
    /// earlier flat-solid-fill preview for the same team was rejected. `nil` for every
    /// other team, unaffected.
    var gradientOuterColorOverrideHex: String? {
        switch self {
        case .palmeirasHome, .flamengoHome, .fluminenseHome, .athleticoParanaenseHome, .bahiaHome,
             .redBullBragantinoHome, .coritibaHome, .saoPauloHome, .atleticoMineiroHome, .corinthiansHome,
             .cruzeiroHome, .remoHome, .botafogoHome, .vitoriaHome, .mirassolHome, .chapecoenseHome,
             .santosHome, .gremioHome, .vascoDaGamaHome:
            nil
        case .internacionalHome: "D9D9D9"
        }
    }

    /// Mirrors the bottom-right ambient glow onto the bottom-left too, instead of the
    /// app's default top-left/bottom-right asymmetric pair — Internacional-only, part of
    /// the same gradient-preview exploration as `gradientOuterColorOverrideHex`. `false`
    /// for every other team.
    var usesSymmetricBottomGlow: Bool {
        self == .internacionalHome
    }

    /// Overrides the Standings table's Libertadores zone-marker ball color (normally the
    /// app-wide teal, see `StandingsView.zoneBallColor`) — Corinthians' gray and Athletico
    /// Paranaense's red theme colors read poorly against that teal, per user request. Reuses
    /// CLAUDE.md's existing "Gold" accent hex (`FBBF24`, also used as the `playoff` status
    /// color) rather than inventing a new one. `nil` for every other team, unaffected.
    var libertadoresBallColorOverrideHex: String? {
        switch self {
        case .palmeirasHome, .flamengoHome, .fluminenseHome, .bahiaHome,
             .redBullBragantinoHome, .coritibaHome, .saoPauloHome, .atleticoMineiroHome,
             .cruzeiroHome, .internacionalHome, .remoHome, .botafogoHome, .vitoriaHome,
             .mirassolHome, .chapecoenseHome, .santosHome, .gremioHome, .vascoDaGamaHome:
            nil
        case .corinthiansHome, .athleticoParanaenseHome: "FBBF24"
        }
    }

    /// The StoreKit product identifier this team's theme purchase uses — one non-consumable
    /// per team, scheme `"com.vibrito.br2026.theme.<rawValue>"`. Derivable directly from the
    /// case with no separate mapping table to keep in sync as teams are added.
    var productID: String {
        "com.vibrito.br2026.theme.\(rawValue)"
    }

    /// The inverse of `productID` — maps a StoreKit product ID back to a `TeamThemeOption`
    /// `rawValue`, used by `PurchaseStore` to translate a purchased-product-ID set into
    /// purchased-option state. Returns `nil` for anything not matching this app's product ID
    /// scheme (e.g. a foreign/malformed ID).
    static func rawValue(fromProductID productID: String) -> String? {
        let prefix = "com.vibrito.br2026.theme."
        guard productID.hasPrefix(prefix) else { return nil }
        return String(productID.dropFirst(prefix.count))
    }
}
