// ⚠️ SHARED FILE — kept byte-identical with the Fixture 2026 app.
//
// The white-label repo is the source of truth. After editing, run
// `scripts/sync-crests.sh` there to copy this into ../worldcup and refresh the
// integrity hash below. CrestSyncTests fails if the file and its hash disagree,
// which is how an un-synced edit gets caught in either repo.
//
// crest-sync: f729b586e7139ab40bdeb035cd7b922f604e175a490e1a9759dfeb3202dffa3f

import Foundation
import CoreGraphics

/// A hand-curated symbol standing in for a club's (unlicensed) crest, painted into the round
/// crest badge. Keyed by team id; teams without an entry fall back to the plain initials
/// placeholder. Add clubs (and patterns) here over time.
enum TeamCrestSymbol {
    /// One band/ring: a color and its relative size (a thin pinstripe / thin ring is a small
    /// weight next to wider ones).
    struct Band {
        let hex: String
        let weight: CGFloat

        init(_ hex: String, _ weight: CGFloat = 1) {
            self.hex = hex
            self.weight = weight
        }
    }

    /// Vertical bands, left→right, widths proportional to their weights.
    case verticalStripes([Band])
    /// Horizontal bands, top→bottom, heights proportional to their weights.
    case horizontalStripes([Band])
    /// Concentric filled circles, outer→inner — the last band is the solid centre, earlier
    /// ones are rings around it (radial thickness proportional to weight).
    case concentric([Band])
    /// A single diagonal stripe (top-left → bottom-right) of `stripe` over a `background`.
    /// `widthFraction` is the stripe's width as a fraction of the badge size.
    case diagonalSash(background: String, stripe: String, widthFraction: CGFloat)
    /// A checkerboard of `squares` × `squares` alternating cells, `light` in the top-left.
    /// The only two-dimensional pattern — every other case is a one-dimensional band list.
    case checkerboard(light: String, dark: String, squares: Int)

    /// Convenience for equal-width vertical bands from a plain list of hex colors.
    static func equalStripes(_ hexes: [String]) -> TeamCrestSymbol {
        .verticalStripes(hexes.map { Band($0) })
    }
}

enum TeamCrestSymbols {
    static let byTeamID: [Int: TeamCrestSymbol] = [
        // Fluminense — the striped home shirt: green & grená vertical stripes (grená at the
        // centre, green on the outer bands) separated by thin white pinstripes. Colored bands
        // are 3× the width of the white pinstripes.
        124: .verticalStripes([
            .init("FFFFFF", 1),
            .init("00613C", 3), .init("FFFFFF", 1),
            .init("870A28", 3), .init("FFFFFF", 1),
            .init("00613C", 3), .init("FFFFFF", 1),
            .init("870A28", 3), .init("FFFFFF", 1),  // centre grená
            .init("00613C", 3), .init("FFFFFF", 1),
            .init("870A28", 3), .init("FFFFFF", 1),
            .init("00613C", 3), .init("FFFFFF", 1),
        ]),
        // Atlético Mineiro — black & white striped jersey, equal bands, black on both edges.
        1062: .equalStripes(["000000", "FFFFFF", "000000", "FFFFFF", "000000", "FFFFFF", "000000", "FFFFFF", "000000"]),
        // Vasco da Gama — inverted: a white diagonal sash on black.
        133: .diagonalSash(background: "000000", stripe: "FFFFFF", widthFraction: 0.3),
        // Red Bull Bragantino — white with two thin red vertical bars, one on the left and one
        // on the right (inset from the edges).
        794: .verticalStripes([
            .init("FFFFFF", 1),
            .init("D2003C", 0.6),
            .init("FFFFFF", 5),
            .init("D2003C", 0.6),
            .init("FFFFFF", 1),
        ]),
        // Athletico Paranaense — rubro-negro: equal vertical bars alternating red & black,
        // red on both edges (red, black, red, black, red, black, red).
        134: .verticalStripes([
            .init("CE181E"), .init("000000"), .init("CE181E"), .init("000000"),
            .init("CE181E"), .init("000000"), .init("CE181E"),
        ]),
        // Flamengo — rubro-negro: five equal horizontal hoops, black at top & bottom with red
        // between (black, red, black, red, black).
        127: .horizontalStripes([
            .init("000000"), .init("C52613"), .init("000000"), .init("C52613"), .init("000000"),
        ]),
        // Coritiba — white shirt with two equal horizontal green bars across the middle,
        // separated by a thin white line.
        147: .horizontalStripes([
            .init("FFFFFF", 5),
            .init("00544D", 2),
            .init("FFFFFF", 0.7),
            .init("00544D", 2),
            .init("FFFFFF", 5),
        ]),
        // Palmeiras — retro green shirt: wide green bars separated by equal thin white
        // pinstripes (same even structure as Fluminense, but every wide bar is green).
        121: .verticalStripes([
            .init("FFFFFF", 1),
            .init("006437", 3), .init("FFFFFF", 1),
            .init("006437", 3), .init("FFFFFF", 1),
            .init("006437", 3), .init("FFFFFF", 1),
            .init("006437", 3), .init("FFFFFF", 1),
            .init("006437", 3), .init("FFFFFF", 1),
            .init("006437", 3), .init("FFFFFF", 1),
            .init("006437", 3), .init("FFFFFF", 1),
        ]),
        // Bahia — tricolor: same structure as Palmeiras (wide bars separated by equal thin
        // white pinstripes), but the wide bars alternate blue & red (blue on both edges).
        118: .verticalStripes([
            .init("FFFFFF", 1),
            .init("006CB5", 3), .init("FFFFFF", 1),
            .init("ED3237", 3), .init("FFFFFF", 1),
            .init("006CB5", 3), .init("FFFFFF", 1),
            .init("ED3237", 3), .init("FFFFFF", 1),
            .init("006CB5", 3), .init("FFFFFF", 1),
            .init("ED3237", 3), .init("FFFFFF", 1),
            .init("006CB5", 3), .init("FFFFFF", 1),
        ]),
        // Grêmio — tricolor: same structure as Bahia (wide bars separated by equal thin white
        // pinstripes), but the wide bars alternate celeste blue & black (blue on both edges).
        130: .verticalStripes([
            .init("FFFFFF", 1),
            .init("0F8BD0", 3), .init("FFFFFF", 1),
            .init("000000", 3), .init("FFFFFF", 1),
            .init("0F8BD0", 3), .init("FFFFFF", 1),
            .init("000000", 3), .init("FFFFFF", 1),
            .init("0F8BD0", 3), .init("FFFFFF", 1),
            .init("000000", 3), .init("FFFFFF", 1),
            .init("0F8BD0", 3), .init("FFFFFF", 1),
        ]),
        // Internacional — the Colorado: a solid red shirt with a little white stripe.
        119: .verticalStripes([
            .init("E30613", 8),
            .init("FFFFFF", 1),
            .init("E30613", 2)
        ]),
        // São Paulo — white shirt with two equal horizontal bars across the middle (same
        // structure as Coritiba), the top bar red and the bottom bar black.
        126: .horizontalStripes([
            .init("FFFFFF", 5),
            .init("FE0000", 2),
            .init("FFFFFF", 0.7),
            .init("000000", 2),
            .init("FFFFFF", 5),
        ]),
        // Botafogo — alvinegro: equal vertical stripes alternating black & white, black on both
        // edges (black, white, black, white, black, white, black).
        120: .equalStripes(["000000", "FFFFFF", "000000", "FFFFFF", "000000", "FFFFFF", "000000"]),
        // Vitória — rubro-negro: five equal vertical bars alternating black & red, black on both
        // edges (black, red, black, red, black).
        136: .equalStripes(["000000", "FF1100", "000000", "FF1100", "000000"]),
        // Corinthians — white shirt with a single thin black vertical stripe (same structure as
        // Internacional, colors inverted: white base, black stripe).
        131: .verticalStripes([
            .init("FFFFFF", 8),
            .init("000000", 1),
            .init("FFFFFF", 2),
        ]),
        // Cruzeiro — solid blue shirt with a single thin white vertical stripe (same structure
        // as Internacional).
        135: .verticalStripes([
            .init("2F529E", 8),
            .init("FFFFFF", 1),
            .init("2F529E", 2),
        ]),
        // Santos — the iconic all-white home shirt (solid, no stripe pattern).
        128: .equalStripes(["FFFFFF"]),
        // Mirassol — solid yellow shirt with a single thin green vertical stripe (same structure
        // as Internacional).
        7848: .verticalStripes([
            .init("F3EC0A", 8),
            .init("126F3D", 1),
            .init("F3EC0A", 2),
        ]),
        // Remo — the Leão Azul: solid navy-blue shirt with a single thin white vertical stripe
        // (same structure as Internacional).
        1198: .verticalStripes([
            .init("0A1F5C", 8),
            .init("FFFFFF", 1),
            .init("0A1F5C", 2),
        ]),
        // Chapecoense — five equal vertical stripes alternating white & green, white on both
        // edges (white, green, white, green, white).
        132: .equalStripes(["FFFFFF", "1B552A", "FFFFFF", "1B552A", "FFFFFF"]),

        // ── Scottish Premiership ────────────────────────────────────────────────────────
        // Keyed by team id like everything above, so these are inert in the Brazilian build
        // and need no target gating. Ids come from the live SPL standings.
        // See docs/superpowers/specs/2026-07-26-scottish-crest-symbols-design.md.

        // Celtic — green & white horizontal hoops, white at top & bottom. `equalStripes` is
        // vertical-only, so the equal bands are spelled out.
        247: .horizontalStripes([
            .init("FFFFFF"),
            .init("018749"),
            .init("FFFFFF"),
            .init("018749"),
            .init("FFFFFF"),
            .init("018749"),
            .init("FFFFFF"),
        ]),
        // Rangers — royal blue with five thin white pinstripes. Far finer than any Brazilian
        // band (0.35 against Bragantino's 0.6, the previous thinnest); the blue is sampled
        // from a kit photo rather than guessed.
        257: .verticalStripes([
            .init("005ABA", 6),
            .init("FFFFFF", 0.35),
            .init("005ABA", 6),
            .init("FFFFFF", 0.35),
            .init("005ABA", 6),
            .init("FFFFFF", 0.35),
            .init("005ABA", 6),
            .init("FFFFFF", 0.35),
            .init("005ABA", 6),
            .init("FFFFFF", 0.35),
            .init("005ABA", 6),
        ]),
        // Heart of Midlothian — solid maroon.
        254: .equalStripes(["660033"]),
        // Hibernian — green body between two thin white sleeve bands.
        249: .verticalStripes([
            .init("FFFFFF"),
            .init("006633", 6),
            .init("FFFFFF"),
        ]),
        // Aberdeen — solid red.
        252: .equalStripes(["DA291C"]),
        // Dundee United — tangerine & black vertical stripes, tangerine on both edges (the
        // same seven-band shape as St Mirren and Kilmarnock).
        1386: .equalStripes(["FF6600", "000000", "FF6600", "000000", "FF6600", "000000", "FF6600"]),
        // Falkirk — navy body between two thin white sleeve bands (same shape as Hibernian).
        1389: .verticalStripes([
            .init("FFFFFF"),
            .init("0A2240", 6),
            .init("FFFFFF"),
        ]),
        // Kilmarnock — blue & white vertical stripes, white on both edges.
        250: .equalStripes(["FFFFFF", "003C7D", "FFFFFF", "003C7D", "FFFFFF", "003C7D", "FFFFFF"]),
        // Motherwell — amber with a claret band across the chest.
        256: .horizontalStripes([
            .init("FFBF00", 4),
            .init("8A1538", 2),
            .init("FFBF00", 4),
        ]),
        // St Mirren — black & white vertical stripes, white on both edges.
        251: .equalStripes(["FFFFFF", "000000", "FFFFFF", "000000", "FFFFFF", "000000", "FFFFFF"]),
        // St Johnstone — royal blue with a single thin white vertical stripe (same structure
        // as Internacional).
        258: .verticalStripes([
            .init("0033A0", 8),
            .init("FFFFFF"),
            .init("0033A0", 2),
        ]),
        // Dundee — navy with two centred white vertical bars separated by a thin navy line
        // (São Paulo's paired-bar structure, rotated vertical).
        253: .verticalStripes([
            .init("000F4F", 5),
            .init("FFFFFF", 2),
            .init("000F4F", 0.7),
            .init("FFFFFF", 2),
            .init("000F4F", 5),
        ]),

        // ── Liga Portugal ───────────────────────────────────────────────────────────────
        // Keyed by team id like everything above, so these are inert in the Brazilian,
        // Scottish and World Cup builds and need no target gating. Ids come from the live
        // PPL standings.
        // See docs/superpowers/specs/2026-07-26-portuguese-crest-symbols-design.md.

        // Benfica — solid red.
        211: .equalStripes(["DA020E"]),
        // FC Porto — blue & white vertical stripes, blue at both edges.
        212: .equalStripes(["003DA5", "FFFFFF", "003DA5", "FFFFFF", "003DA5", "FFFFFF", "003DA5"]),
        // Marítimo — green & red vertical stripes, green at both edges.
        214: .equalStripes(["00A551", "E4002B", "00A551", "E4002B", "00A551", "E4002B", "00A551"]),
        // Moreirense — green & white checkerboard, 4 squares across (the Croatia pattern).
        // Six across was tested on the crest board and rejected: it collapses into noise
        // below 32pt.
        215: .checkerboard(light: "FFFFFF", dark: "0A6B3D", squares: 4),
        // SC Braga — red body with white sleeves (the Arsenalistas heritage). Same shape as
        // Hibernian and Falkirk.
        217: .verticalStripes([
            .init("FFFFFF"),
            .init("DC0B15", 6),
            .init("FFFFFF"),
        ]),
        // Vitória de Guimarães — white with a thin black stripe (the Internacional structure).
        224: .verticalStripes([
            .init("FFFFFF", 8),
            .init("000000", 1),
            .init("FFFFFF", 2),
        ]),
        // Nacional — black & white vertical stripes, black at both edges.
        225: .equalStripes(["000000", "FFFFFF", "000000", "FFFFFF", "000000", "FFFFFF", "000000"]),
        // Rio Ave — green & white vertical stripes, white at both edges.
        226: .equalStripes(["FFFFFF", "007A3D", "FFFFFF", "007A3D", "FFFFFF", "007A3D", "FFFFFF"]),
        // Santa Clara — red & white vertical stripes, red at both edges.
        227: .equalStripes(["E4002B", "FFFFFF", "E4002B", "FFFFFF", "E4002B", "FFFFFF", "E4002B"]),
        // Sporting CP — green & white horizontal hoops, white at top & bottom. `equalStripes`
        // is vertical-only, so the equal bands are spelled out (same as Celtic).
        228: .horizontalStripes([
            .init("FFFFFF"),
            .init("008057"),
            .init("FFFFFF"),
            .init("008057"),
            .init("FFFFFF"),
            .init("008057"),
            .init("FFFFFF"),
        ]),
        // Estoril — yellow & blue vertical stripes, yellow at both edges.
        230: .equalStripes(["FFD400", "0033A0", "FFD400", "0033A0", "FFD400", "0033A0", "FFD400"]),
        // Académico de Viseu — black body with white sleeves (the same shape as SC Braga).
        238: .verticalStripes([
            .init("FFFFFF"),
            .init("111111", 6),
            .init("FFFFFF"),
        ]),
        // Arouca — yellow with a thin blue stripe (the Internacional structure).
        240: .verticalStripes([
            .init("FFD400", 8),
            .init("0A2E6E", 1),
            .init("FFD400", 2),
        ]),
        // Famalicão — blue with a thin white stripe (the Internacional structure).
        242: .verticalStripes([
            .init("0A2E6E", 8),
            .init("FFFFFF", 1),
            .init("0A2E6E", 2),
        ]),
        // Gil Vicente — red and blue halves. The only halved kit in any set.
        762: .equalStripes(["E4002B", "0A2E6E"]),
        // Casa Pia — black with a gold bar down the right. The only asymmetric disc in any
        // set. The bar needs the thin black band beyond it: without one the gold runs off
        // the edge and the circular clip reads it as a crescent rather than a stripe.
        4716: .verticalStripes([
            .init("111111", 7),
            .init("D4AF37", 2),
            .init("111111", 1),
        ]),
        // Alverca — blue with a central red band. Colours sampled from a kit photo rather
        // than guessed; the kit's thin white edging was dropped because it would not have
        // survived 24pt.
        4724: .verticalStripes([
            .init("0060A8", 5),
            .init("F6002A", 3),
            .init("0060A8", 5),
        ]),
        // Estrela da Amadora — Fluminense's tricolour structure with thicker white bars
        // (1.8 against Fluminense's 1), so the three colours still read at badge size.
        15130: .verticalStripes([
            .init("FFFFFF", 1.8),
            .init("00613C", 3), .init("FFFFFF", 1.8),
            .init("870A28", 3), .init("FFFFFF", 1.8),
            .init("00613C", 3), .init("FFFFFF", 1.8),
            .init("870A28", 3), .init("FFFFFF", 1.8),
            .init("00613C", 3), .init("FFFFFF", 1.8),
            .init("870A28", 3), .init("FFFFFF", 1.8),
            .init("00613C", 3), .init("FFFFFF", 1.8),
        ]),

        // ---- La Liga ------------------------------------------------------------------
        // Eleven of the twenty clubs share a look with a neighbour, which no previous set
        // had to solve. The rule these follow is shape before hue: at badge size a shift
        // between two royal blues is invisible where five bands against nine is not.

        // Deportivo La Coruña — blue and white, the broadest stripes of the five blue-and-
        // white sides. Málaga matches this shape exactly; the blue is what separates them.
        544: .equalStripes(["0055A5", "FFFFFF", "0055A5", "FFFFFF", "0055A5"]),
        // Málaga — the same five broad bands, in a distinctly lighter blue. Their blue
        // really is lighter than Depor's royal; drawn any closer the two discs were one.
        535: .equalStripes(["33B5E5", "FFFFFF", "33B5E5", "FFFFFF", "33B5E5"]),
        // Real Sociedad — seven bands, white-edged, the darkest blue of the five.
        548: .equalStripes(["FFFFFF", "003C8F", "FFFFFF", "003C8F", "FFFFFF", "003C8F", "FFFFFF"]),
        // Alavés — thin white pinstripes between wide blue bands. The only one of the five
        // with unequal weights, which is what separates it at badge size.
        542: .verticalStripes([
            .init("FFFFFF", 1), .init("0761AF", 3), .init("FFFFFF", 1), .init("0761AF", 3),
            .init("FFFFFF", 1), .init("0761AF", 3), .init("FFFFFF", 1)
        ]),
        // Espanyol — nine narrow bands in the brightest blue; they are known for narrow
        // stripes, and it is the far end of the count scale from Depor and Málaga.
        540: .equalStripes(["FFFFFF", "007FC8", "FFFFFF", "007FC8", "FFFFFF", "007FC8", "FFFFFF", "007FC8", "FFFFFF"]),

        // Atlético Madrid — red and white, with navy edge bands. The navy is their real
        // third colour (shorts, collar) and is the honest separator from Athletic below.
        530: .verticalStripes([
            .init("262E62", 1), .init("CB3524", 3), .init("FFFFFF", 3), .init("CB3524", 3),
            .init("FFFFFF", 3), .init("CB3524", 3), .init("262E62", 1)
        ]),
        // Athletic Club — pure red and white, seven narrower bands, no third colour.
        531: .equalStripes(["FFFFFF", "EE2523", "FFFFFF", "EE2523", "FFFFFF", "EE2523", "FFFFFF"]),

        // Barcelona — blaugrana, five broad bands with blue on the outside.
        529: .equalStripes(["004D98", "A50044", "004D98", "A50044", "004D98"]),
        // Levante — the same two colours as Barcelona, so it is inverted: garnet on the
        // outside, seven narrower bands.
        539: .equalStripes(["A61B2B", "004B9B", "A61B2B", "004B9B", "A61B2B", "004B9B", "A61B2B"]),

        // Real Betis — seven bands, green and white.
        543: .equalStripes(["FFFFFF", "00954C", "FFFFFF", "00954C", "FFFFFF", "00954C", "FFFFFF"]),
        // Racing Santander — the home shirt: white body, green at the sides. Green lands on
        // the left and right arcs only, white through the middle. Deliberately not green
        // and white stripes, which would have been a second Betis.
        4665: .verticalStripes([.init("009540", 1), .init("FFFFFF", 3), .init("009540", 1)]),

        // The four mostly-white clubs take their accent colour as a ring. A plain white
        // disc vanishes on a light background, and the ring colour also keeps these four
        // apart from each other. These are the first concentric entries in the catalogue.
        // Real Madrid — gold ring on white, the club's only real accent.
        541: .concentric([.init("FEBE10", 0.8), .init("FFFFFF", 4)]),
        // Sevilla — red ring on white.
        536: .concentric([.init("D8020E", 1), .init("FFFFFF", 4)]),
        // Elche — green ring on white. Sits near Racing above; they differ in shape, since
        // Racing's green touches only the side arcs where this goes all the way round.
        797: .concentric([.init("00714A", 1), .init("FFFFFF", 4)]),
        // Valencia — orange ring on white.
        532: .concentric([.init("F18E00", 1), .init("FFFFFF", 4)]),

        // Rayo Vallecano — the red sash on white. The only diagonal in the division.
        728: .diagonalSash(background: "FFFFFF", stripe: "E53027", widthFraction: 0.30),
        // Villarreal — El Submarino Amarillo: yellow with a navy ring.
        533: .concentric([.init("003D7C", 0.7), .init("FFE667", 4)]),
        // Celta Vigo — solid sky blue; nothing else in the division is this pale.
        538: .equalStripes(["8AC3EE"]),
        // Getafe — solid royal blue.
        546: .equalStripes(["005999"]),
        // Osasuna — red with a navy ring, their shirt and shorts.
        727: .concentric([.init("0A1D5B", 0.8), .init("D91A21", 4)]),
    ]

    static func symbol(forTeamID id: Int) -> TeamCrestSymbol? {
        byTeamID[id]
    }
}
