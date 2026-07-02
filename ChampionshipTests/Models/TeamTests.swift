import Testing
import Foundation
@testable import Championship26

@Suite("Team decoding")
struct TeamTests {
    @Test("TeamDTO decodes from API JSON, and Team(dto:) maps it correctly")
    func decodesTeam() throws {
        let json = """
        {
            "id": 121,
            "tla": null,
            "name": "Palmeiras",
            "crest": "https://media.api-sports.io/football/teams/121.png",
            "shortName": "Palmeiras"
        }
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(TeamDTO.self, from: json)
        let team = Team(dto: dto)
        #expect(team.id == 121)
        #expect(team.name == "Palmeiras")
        #expect(team.shortName == "Palmeiras")
        #expect(team.crestURL?.absoluteString == "https://media.api-sports.io/football/teams/121.png")
    }

    @Test("Tolerates a missing crest")
    func decodesTeamWithoutCrest() throws {
        let json = """
        { "id": 1, "tla": null, "name": "Test FC", "crest": null, "shortName": null }
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(TeamDTO.self, from: json)
        let team = Team(dto: dto)
        #expect(team.crestURL == nil)
        #expect(team.shortName == nil)
    }
}
