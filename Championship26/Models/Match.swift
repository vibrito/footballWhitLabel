import Foundation
import SwiftData

@Model
final class Match {
    @Attribute(.unique) var id: Int
    var utcDate: Date
    var status: MatchStatus
    var matchday: Int
    var stage: String
    var homeTeam: Team
    var awayTeam: Team
    var homeScore: Int?
    var awayScore: Int?
    var winner: String?
    var venue: String?
    var minute: Int?

    init(
        id: Int,
        utcDate: Date,
        status: MatchStatus,
        matchday: Int,
        stage: String,
        homeTeam: Team,
        awayTeam: Team,
        homeScore: Int?,
        awayScore: Int?,
        winner: String?,
        venue: String?,
        minute: Int?
    ) {
        self.id = id
        self.utcDate = utcDate
        self.status = status
        self.matchday = matchday
        self.stage = stage
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.winner = winner
        self.venue = venue
        self.minute = minute
    }

    convenience init(dto: MatchDTO) {
        self.init(
            id: dto.id,
            utcDate: dto.utcDate,
            status: dto.status,
            matchday: dto.matchday,
            stage: dto.stage,
            homeTeam: dto.homeTeam,
            awayTeam: dto.awayTeam,
            homeScore: dto.score.fullTime.home,
            awayScore: dto.score.fullTime.away,
            winner: dto.score.winner,
            venue: dto.venue,
            minute: dto.minute
        )
    }

    func update(from dto: MatchDTO) {
        status = dto.status
        homeScore = dto.score.fullTime.home
        awayScore = dto.score.fullTime.away
        winner = dto.score.winner
        minute = dto.minute
        venue = dto.venue
    }
}
