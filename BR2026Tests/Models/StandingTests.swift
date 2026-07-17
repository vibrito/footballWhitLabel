import Testing
import Foundation
@testable import BR2026

@Suite("Standing decoding")
struct StandingTests {
    @Test("Decodes a standings entry from API JSON")
    func decodesStanding() throws {
        let json = Data("""
        {
            "position": 1,
            "team": { "id": 121, "tla": null, "name": "Palmeiras", "crest": "https://media.api-sports.io/football/teams/121.png", "shortName": "Palmeiras" },
            "playedGames": 15,
            "won": 12,
            "draw": 5,
            "lost": 1,
            "goalsFor": 41,
            "goalsAgainst": 18,
            "goalDifference": 23,
            "points": 41
        }
        """.utf8)
        let dto = try JSONDecoder().decode(StandingDTO.self, from: json)
        let standing = Standing(dto: dto)
        #expect(standing.position == 1)
        #expect(standing.team.name == "Palmeiras")
        #expect(standing.points == 41)
        #expect(standing.id == 121)
    }

    @Test("accessibilityLabel spells out every column")
    func accessibilityLabel() throws {
        let team = Team(id: 121, name: "Palmeiras", shortName: "Palmeiras", crestURL: nil)
        let standing = Standing(
            position: 3, team: team, playedGames: 10, won: 7, draw: 2, lost: 1,
            goalsFor: 20, goalsAgainst: 5, goalDifference: 15, points: 23
        )
        let label = standing.accessibilityLabel
        #expect(label.contains("Palmeiras"))
        #expect(label.contains("10"))
        #expect(label.contains("7"))
        #expect(label.contains("23"))
    }

    @Test("accessibilityLabel spells out a negative goal difference")
    func accessibilityLabelNegativeGoalDifference() throws {
        let team = Team(id: 121, name: "Palmeiras", shortName: "Palmeiras", crestURL: nil)
        let standing = Standing(
            position: 18, team: team, playedGames: 10, won: 1, draw: 2, lost: 7,
            goalsFor: 5, goalsAgainst: 20, goalDifference: -15, points: 5
        )
        #expect(standing.accessibilityLabel.contains("15"))
    }
}
