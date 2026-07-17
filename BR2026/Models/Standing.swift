import Foundation
import SwiftData

@Model
final class Standing: Identifiable {
    @Attribute(.unique) var teamID: Int
    var position: Int
    var team: Team
    var playedGames: Int
    var won: Int
    var draw: Int
    var lost: Int
    var goalsFor: Int
    var goalsAgainst: Int
    var goalDifference: Int
    var points: Int

    var id: Int { teamID }

    init(
        position: Int,
        team: Team,
        playedGames: Int,
        won: Int,
        draw: Int,
        lost: Int,
        goalsFor: Int,
        goalsAgainst: Int,
        goalDifference: Int,
        points: Int
    ) {
        self.teamID = team.id
        self.position = position
        self.team = team
        self.playedGames = playedGames
        self.won = won
        self.draw = draw
        self.lost = lost
        self.goalsFor = goalsFor
        self.goalsAgainst = goalsAgainst
        self.goalDifference = goalDifference
        self.points = points
    }

    convenience init(dto: StandingDTO) {
        self.init(
            position: dto.position,
            team: Team(dto: dto.team),
            playedGames: dto.playedGames,
            won: dto.won,
            draw: dto.draw,
            lost: dto.lost,
            goalsFor: dto.goalsFor,
            goalsAgainst: dto.goalsAgainst,
            goalDifference: dto.goalDifference,
            points: dto.points
        )
    }

    private static let ordinalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter
    }()

    var accessibilityLabel: String {
        let positionText = Self.ordinalFormatter.string(from: NSNumber(value: position)) ?? String(position)
        let playedGamesText = String(playedGames)
        let wonText = String(won)
        let drawText = String(draw)
        let lostText = String(lost)
        let pointsText = String(points)
        let goalDifferenceText: String
        if goalDifference > 0 {
            let plusWord = String(localized: "plus", comment: "VoiceOver: prefix spoken before a positive goal difference, e.g. \"plus 15\".")
            goalDifferenceText = "\(plusWord) \(goalDifference)"
        } else if goalDifference < 0 {
            let minusWord = String(localized: "minus", comment: "VoiceOver: prefix spoken before a negative goal difference, e.g. \"minus 4\".")
            goalDifferenceText = "\(minusWord) \(abs(goalDifference))"
        } else {
            goalDifferenceText = String(goalDifference)
        }
        return String(
            localized: "\(positionText) place, \(team.displayName), \(playedGamesText) played, \(wonText) won, \(drawText) drawn, \(lostText) lost, goal difference \(goalDifferenceText), \(pointsText) points",
            comment: "VoiceOver label for one standings table row. Arguments: ordinal position, team name, games played, wins, draws, losses, goal difference (already spelled out with plus/minus), points."
        )
    }
}
