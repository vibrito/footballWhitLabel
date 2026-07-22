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
    ]

    static func symbol(forTeamID id: Int) -> TeamCrestSymbol? {
        byTeamID[id]
    }
}
