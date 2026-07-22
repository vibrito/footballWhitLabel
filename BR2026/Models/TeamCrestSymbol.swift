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
        // Fluminense — the Italian tricolour (green / white / red), matching the club's
        // own tricolor identity and the World Cup app's Italy flag.
        124: TeamCrestSymbol(colorHexes: ["009246", "FFFFFF", "CE2B37"], pattern: .verticalStripes),
    ]

    static func symbol(forTeamID id: Int) -> TeamCrestSymbol? {
        byTeamID[id]
    }
}
