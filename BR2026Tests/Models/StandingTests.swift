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

    @Test("Decodes the description field from API JSON")
    func decodesDescription() throws {
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
            "points": 41,
            "description": "Promotion - Copa Libertadores (Group Stage)"
        }
        """.utf8)
        let dto = try JSONDecoder().decode(StandingDTO.self, from: json)
        #expect(dto.description == "Promotion - Copa Libertadores (Group Stage)")
        let standing = Standing(dto: dto)
        #expect(standing.zoneDescription == "Promotion - Copa Libertadores (Group Stage)")
    }

    @Test("Decodes standings entries with no description field at all (optional, absent key)")
    func decodesMissingDescription() throws {
        let json = Data("""
        {
            "position": 12,
            "team": { "id": 131, "tla": null, "name": "Corinthians", "crest": null, "shortName": "Corinthians" },
            "playedGames": 15, "won": 5, "draw": 5, "lost": 5,
            "goalsFor": 16, "goalsAgainst": 16, "goalDifference": 0, "points": 20
        }
        """.utf8)
        let dto = try JSONDecoder().decode(StandingDTO.self, from: json)
        #expect(dto.description == nil)
    }

    @Test("zone classifies real observed API description values correctly", arguments: [
        ("Promotion - Copa Libertadores (Group Stage)", StandingZone.qualification),
        ("Promotion - Copa Libertadores (Qualification)", StandingZone.qualification),
        ("Promotion - Copa Sudamericana (Group Stage)", StandingZone.qualification),
        ("Champions League league stage", StandingZone.qualification),
        ("Champions League", StandingZone.qualification),
        ("Promotion - Champions League (League phase)", StandingZone.qualification),
        ("Promotion - Premiership (Championship Group)", StandingZone.qualification),
        ("Relegation - Serie B", StandingZone.relegation),
        ("Relegation", StandingZone.relegation),
        ("Relegation Playoffs", StandingZone.relegation),
        ("Liga Portugal (Relegation)", StandingZone.relegation),
        ("Relegation - Liga Portugal 2", StandingZone.relegation),
        ("Premiership (Relegation Group)", StandingZone.relegation),
        ("None", StandingZone.none),
    ])
    func zoneClassifiesRealAPIValues(description: String, expectedZone: StandingZone) throws {
        let team = Team(id: 1, name: "Test", shortName: "Test", crestURL: nil)
        let standing = Standing(
            position: 1, team: team, playedGames: 10, won: 5, draw: 3, lost: 2,
            goalsFor: 10, goalsAgainst: 10, goalDifference: 0, points: 18,
            zoneDescription: description
        )
        #expect(standing.zone == expectedZone)
    }

    @Test("zone is .none when zoneDescription is nil")
    func zoneIsNoneWhenDescriptionIsNil() throws {
        let team = Team(id: 1, name: "Test", shortName: "Test", crestURL: nil)
        let standing = Standing(
            position: 1, team: team, playedGames: 10, won: 5, draw: 3, lost: 2,
            goalsFor: 10, goalsAgainst: 10, goalDifference: 0, points: 18
        )
        #expect(standing.zone == .none)
    }

    @Test("accessibilityLabel appends the qualification label when zone is qualification")
    func accessibilityLabelAppendsQualification() throws {
        let team = Team(id: 121, name: "Palmeiras", shortName: "Palmeiras", crestURL: nil)
        let standing = Standing(
            position: 1, team: team, playedGames: 15, won: 12, draw: 5, lost: 1,
            goalsFor: 41, goalsAgainst: 18, goalDifference: 23, points: 41,
            zoneDescription: "Promotion - Copa Libertadores (Group Stage)"
        )
        #expect(standing.accessibilityLabel.hasSuffix("Continental qualification"))
    }

    @Test("accessibilityLabel appends the relegation label when zone is relegation")
    func accessibilityLabelAppendsRelegation() throws {
        let team = Team(id: 132, name: "Chapecoense-sc", shortName: "Chapecoense-sc", crestURL: nil)
        let standing = Standing(
            position: 20, team: team, playedGames: 15, won: 2, draw: 4, lost: 9,
            goalsFor: 9, goalsAgainst: 27, goalDifference: -18, points: 10,
            zoneDescription: "Relegation - Serie B"
        )
        #expect(standing.accessibilityLabel.hasSuffix("Relegation zone"))
    }

    @Test("accessibilityLabel is unchanged (no trailing zone clause) when zone is .none")
    func accessibilityLabelUnchangedWhenNoZone() throws {
        let team = Team(id: 131, name: "Corinthians", shortName: "Corinthians", crestURL: nil)
        let standing = Standing(
            position: 12, team: team, playedGames: 15, won: 5, draw: 5, lost: 5,
            goalsFor: 16, goalsAgainst: 16, goalDifference: 0, points: 20
        )
        #expect(standing.accessibilityLabel.hasSuffix("points"))
    }
}
