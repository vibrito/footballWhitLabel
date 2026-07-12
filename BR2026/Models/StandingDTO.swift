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
}
