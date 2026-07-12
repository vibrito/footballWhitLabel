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
}
