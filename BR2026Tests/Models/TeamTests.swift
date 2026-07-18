import Testing
import Foundation
@testable import BR2026

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

    @Test("Overrides Atletico Paranaense's display name")
    func overridesDisplayName() {
        let team = Team(id: 134, name: "Atletico Paranaense", shortName: "Atletico Paranaense", crestURL: nil)
        #expect(team.displayName == "At. Paranaense")
    }

    @Test("Overrides Vasco DA Gama's display name")
    func overridesVascoDisplayName() {
        let team = Team(id: 133, name: "Vasco DA Gama", shortName: "Vasco DA Gama", crestURL: nil)
        #expect(team.displayName == "Vasco da Gama")
    }

    @Test("Overrides Chapecoense-sc's display name")
    func overridesChapecoenseDisplayName() {
        let team = Team(id: 132, name: "Chapecoense-sc", shortName: "Chapecoense-sc", crestURL: nil)
        #expect(team.displayName == "Chapecoense")
    }

    @Test("Falls back to shortName when no override exists")
    func displayNameFallsBackToShortName() {
        let team = Team(id: 999, name: "Some FC", shortName: "SFC", crestURL: nil)
        #expect(team.displayName == "SFC")
    }
}
