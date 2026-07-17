import Foundation
import SwiftData

@Model
final class Match: Identifiable {
    @Attribute(.unique) var id: Int
    var utcDate: Date
    var status: MatchStatus
    var matchday: Int
    var stage: String
    var homeTeam: Team
    var awayTeam: Team
    var homeScore: Int?
    var awayScore: Int?
    var halfTimeHomeScore: Int?
    var halfTimeAwayScore: Int?
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
        halfTimeHomeScore: Int? = nil,
        halfTimeAwayScore: Int? = nil,
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
        self.halfTimeHomeScore = halfTimeHomeScore
        self.halfTimeAwayScore = halfTimeAwayScore
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
            homeTeam: Team(dto: dto.homeTeam),
            awayTeam: Team(dto: dto.awayTeam),
            homeScore: dto.score.fullTime.home,
            awayScore: dto.score.fullTime.away,
            halfTimeHomeScore: dto.score.halfTime.home,
            halfTimeAwayScore: dto.score.halfTime.away,
            winner: dto.score.winner,
            venue: dto.venue,
            minute: dto.minute
        )
    }

    func update(from dto: MatchDTO) {
        status = dto.status
        homeScore = dto.score.fullTime.home
        awayScore = dto.score.fullTime.away
        halfTimeHomeScore = dto.score.halfTime.home
        halfTimeAwayScore = dto.score.halfTime.away
        winner = dto.score.winner
        minute = dto.minute
        venue = dto.venue
    }

    var accessibilityLabel: String {
        let home = homeTeam.displayName
        let away = awayTeam.displayName
        switch status {
        case .scheduled:
            let time = utcDate.formatted(date: .omitted, time: .shortened)
            return String(
                localized: "\(home) versus \(away), kicks off at \(time)",
                comment: "VoiceOver label for a scheduled match card. Arguments: home team name, away team name, formatted kickoff time."
            )
        case .postponed:
            return String(
                localized: "\(home) versus \(away), postponed",
                comment: "VoiceOver label for a postponed match card. Arguments: home team name, away team name."
            )
        case .live, .halftime:
            guard let home_score = homeScore, let away_score = awayScore else {
                return String(
                    localized: "\(home) versus \(away), live",
                    comment: "VoiceOver label for a live match card with no score yet available. Arguments: home team name, away team name."
                )
            }
            let minuteText = minute.map { String($0) } ?? ""
            return String(
                localized: "\(home) \(home_score), \(away) \(away_score), live, \(minuteText) minute",
                comment: "VoiceOver label for a live match card. Arguments: home team name, home score, away team name, away score, current minute."
            )
        case .finished:
            guard let home_score = homeScore, let away_score = awayScore else {
                return String(
                    localized: "\(home) versus \(away), final score",
                    comment: "VoiceOver label for a finished match card with no score available. Arguments: home team name, away team name."
                )
            }
            return String(
                localized: "\(home) \(home_score), \(away) \(away_score), final score",
                comment: "VoiceOver label for a finished match card. Arguments: home team name, home score, away team name, away score."
            )
        }
    }
}
