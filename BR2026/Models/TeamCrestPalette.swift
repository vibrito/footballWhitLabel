import Foundation

/// Hand-curated color palettes for the placeholder crest ball, keyed by team id, for clubs
/// whose live API kit colors don't reflect their real identity (the API often returns only
/// one or two kit colors, or the wrong ones). Two colors render as a diagonal split, three
/// as vertical stripes. Teams not listed here fall back to their API-derived kit colors.
enum TeamCrestPalette {
    private static let palettes: [Int: [String]] = [
        // Bahia — tricolor azul/vermelho/branco (blue / red / white)
        118: ["1C3F94", "E20E17", "FFFFFF"],
        // Atlético Mineiro — black & white (charcoal so it reads on the dark background,
        // matching the curated theme color for this club)
        1062: ["2B2B2E", "FFFFFF"],
    ]

    static func hexes(forTeamID id: Int) -> [String]? {
        palettes[id]
    }
}
