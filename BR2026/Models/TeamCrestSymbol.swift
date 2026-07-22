import Foundation

/// A hand-curated "flag-style" symbol standing in for a club's (unlicensed) crest, painted
/// into the round crest badge. Keyed by team id; teams without an entry fall back to the
/// plain initials placeholder. Add clubs here over time.
struct TeamCrestSymbol {
    enum Pattern {
        /// Equal-width vertical bands, left→right, like a vertical-tricolour flag.
        case verticalStripes
    }

    let colorHexes: [String]
    let pattern: Pattern
}

enum TeamCrestSymbols {
    static let byTeamID: [Int: TeamCrestSymbol] = [
        // Fluminense — the club's grená/branco/verde tricolour (burgundy / white / green).
        124: TeamCrestSymbol(colorHexes: ["870A28", "FFFFFF", "00613C"], pattern: .verticalStripes),
        // Atlético Mineiro — the black & white striped jersey (many thin alternating bands).
        1062: TeamCrestSymbol(
            colorHexes: ["000000", "FFFFFF", "000000", "FFFFFF", "000000", "FFFFFF", "000000", "FFFFFF"],
            pattern: .verticalStripes
        ),
    ]

    static func symbol(forTeamID id: Int) -> TeamCrestSymbol? {
        byTeamID[id]
    }
}
