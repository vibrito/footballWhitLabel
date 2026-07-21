import Foundation

/// Hand-curated color palettes for the placeholder crest ball, keyed by team id, for clubs
/// whose live API kit colors don't reflect their real identity (the API often returns only
/// one or two kit colors, or the wrong ones). Two colors render as a diagonal split, three
/// as vertical stripes. Teams not listed here fall back to their API-derived kit colors.
enum TeamCrestPalette {
    private static let palettes: [Int: [String]] = [
        // Bahia — tricolor azul/vermelho/branco (blue / red / white)
        118: ["006CB5", "ED3237", "FFFFFF"],
        // Atlético Mineiro — black & white
        1062: ["000000", "FFFFFF"],
        // Cruzeiro — blue & white
        135: ["2F529E", "FFFFFF"],
    ]

    static func hexes(forTeamID id: Int) -> [String]? {
        palettes[id]
    }
}
