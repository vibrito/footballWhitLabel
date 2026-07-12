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
}
