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

    private enum CodingKeys: String, CodingKey {
        case position, team, playedGames, won, draw, lost, goalsFor, goalsAgainst, goalDifference, points
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        position = try container.decode(Int.self, forKey: .position)
        team = Team(dto: try container.decode(TeamDTO.self, forKey: .team))
        playedGames = try container.decode(Int.self, forKey: .playedGames)
        won = try container.decode(Int.self, forKey: .won)
        draw = try container.decode(Int.self, forKey: .draw)
        lost = try container.decode(Int.self, forKey: .lost)
        goalsFor = try container.decode(Int.self, forKey: .goalsFor)
        goalsAgainst = try container.decode(Int.self, forKey: .goalsAgainst)
        goalDifference = try container.decode(Int.self, forKey: .goalDifference)
        points = try container.decode(Int.self, forKey: .points)
    }
}
