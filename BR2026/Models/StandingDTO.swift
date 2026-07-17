import Foundation

struct StandingDTO: Decodable {
    let position: Int
    let team: TeamDTO
    let playedGames: Int
    let won: Int
    let draw: Int
    let lost: Int
    let goalsFor: Int
    let goalsAgainst: Int
    let goalDifference: Int
    let points: Int
    /// A free-text, English-only field from the upstream provider describing this position's
    /// zone within the competition — e.g. "Promotion - Copa Libertadores (Group Stage)",
    /// "Relegation", or the literal string "None" for a mid-table position with no zone.
    /// Never displayed directly (see `Standing.zone`/`Standing.zoneAccessibilityLabel`) —
    /// only used to classify into `StandingZone`. `nil` when the key is absent from the
    /// response entirely (distinct from the literal string "None", which `StandingZone`
    /// treats the same way).
    let description: String?
}
