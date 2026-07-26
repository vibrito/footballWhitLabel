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
    ]

    static func symbol(forTeamID id: Int) -> TeamCrestSymbol? {
        byTeamID[id]
    }
}
