import Foundation

struct MatchDTO: Decodable {
    let id: Int
    let utcDate: Date
    let status: MatchStatus
    let matchday: Int
    let stage: String
    let homeTeam: Team
    let awayTeam: Team
    let score: ScoreDTO
    let venue: String?
    let minute: Int?
}

struct ScoreDTO: Decodable {
    let winner: String?
    let fullTime: FullTimeDTO
}

struct FullTimeDTO: Decodable {
    let home: Int?
    let away: Int?
}
