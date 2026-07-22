import Foundation
import CoreGraphics

/// A hand-curated "jersey-style" symbol standing in for a club's (unlicensed) crest, painted
/// into the round crest badge as vertical bands. Keyed by team id; teams without an entry
/// fall back to the plain initials placeholder. Add clubs here over time.
struct TeamCrestSymbol {
    /// One vertical band: a color and its relative width (a thin white pinstripe is a small
    /// weight next to wider colored bands).
    struct Stripe {
        let hex: String
        let weight: CGFloat

        init(_ hex: String, _ weight: CGFloat = 1) {
            self.hex = hex
            self.weight = weight
        }
    }

    let stripes: [Stripe]

    /// Convenience for equal-width bands from a plain list of hex colors.
    static func equalStripes(_ hexes: [String]) -> TeamCrestSymbol {
        TeamCrestSymbol(stripes: hexes.map { Stripe($0) })
    }
}

enum TeamCrestSymbols {
    static let byTeamID: [Int: TeamCrestSymbol] = [
        // Fluminense — the striped home shirt: green & grená vertical stripes (grená at the
        // centre, green on the outer bands) separated by thin white pinstripes. Colored bands
        // are 3× the width of the white pinstripes.
        124: TeamCrestSymbol(stripes: [
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
    ]

    static func symbol(forTeamID id: Int) -> TeamCrestSymbol? {
        byTeamID[id]
    }
}
