import Foundation

struct Standing: Decodable, Identifiable {
    var id: Int { team.id }
    let position: Int
    let team: Team
    let playedGames: Int
    let won: Int
    let draw: Int
    let lost: Int
    let goalsFor: Int
    let goalsAgainst: Int
    let goalDifference: Int
    let points: Int
}
