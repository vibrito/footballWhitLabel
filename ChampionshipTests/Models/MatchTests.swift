import Testing
import Foundation
@testable import Championship26

@Suite("MatchStatus decoding")
struct MatchStatusTests {
    @Test("Decodes known statuses", arguments: [
        ("SCHEDULED", MatchStatus.scheduled),
        ("LIVE", MatchStatus.live),
        ("FINISHED", MatchStatus.finished),
        ("POSTPONED", MatchStatus.postponed)
    ])
    func decodesKnown(raw: String, expected: MatchStatus) throws {
        let json = Data("\"\(raw)\"".utf8)
        let status = try JSONDecoder().decode(MatchStatus.self, from: json)
        #expect(status == expected)
    }

    @Test("Falls back to scheduled for an unrecognized status")
    func decodesUnknownAsScheduled() throws {
        let json = Data("\"SUSPENDED\"".utf8)
        let status = try JSONDecoder().decode(MatchStatus.self, from: json)
        #expect(status == .scheduled)
    }
}

@Suite("Match model")
struct MatchTests {
    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private var sampleMatchJSON: Data {
        Data("""
        {
            "id": 1492111,
            "utcDate": "2026-01-30T00:30:00+00:00",
            "status": "FINISHED",
            "matchday": 1,
            "stage": "REGULAR_SEASON",
            "homeTeam": { "id": 120, "tla": null, "name": "Botafogo", "crest": null, "shortName": "Botafogo" },
            "awayTeam": { "id": 135, "tla": null, "name": "Cruzeiro", "crest": null, "shortName": "Cruzeiro" },
            "score": { "winner": "HOME_TEAM", "fullTime": { "away": 0, "home": 4 }, "halfTime": { "away": 0, "home": 0 } },
            "venue": "Estadio Olimpico Nilton Santos",
            "minute": 90
        }
        """.utf8)
    }

    @Test("MatchDTO decodes the API's match shape")
    func decodesMatchDTO() throws {
        let dto = try decoder.decode(MatchDTO.self, from: sampleMatchJSON)
        #expect(dto.id == 1492111)
        #expect(dto.status == .finished)
        #expect(dto.score.fullTime.home == 4)
        #expect(dto.score.fullTime.away == 0)
        #expect(dto.score.winner == "HOME_TEAM")
    }

    @Test("Match(dto:) maps a DTO into the persisted model")
    func mapsFromDTO() throws {
        let dto = try decoder.decode(MatchDTO.self, from: sampleMatchJSON)
        let match = Match(dto: dto)
        #expect(match.id == 1492111)
        #expect(match.homeTeam.name == "Botafogo")
        #expect(match.homeScore == 4)
        #expect(match.awayScore == 0)
        #expect(match.halfTimeHomeScore == 0)
        #expect(match.halfTimeAwayScore == 0)
    }

    @Test("update(from:) applies a partial score/status change without touching identity fields")
    func updatesFromDTO() throws {
        let dto = try decoder.decode(MatchDTO.self, from: sampleMatchJSON)
        let match = Match(dto: dto)

        let liveJSON = Data("""
        {
            "id": 1492111,
            "utcDate": "2026-01-30T00:30:00+00:00",
            "status": "LIVE",
            "matchday": 1,
            "stage": "REGULAR_SEASON",
            "homeTeam": { "id": 120, "tla": null, "name": "Botafogo", "crest": null, "shortName": "Botafogo" },
            "awayTeam": { "id": 135, "tla": null, "name": "Cruzeiro", "crest": null, "shortName": "Cruzeiro" },
            "score": { "winner": null, "fullTime": { "away": 1, "home": 2 }, "halfTime": { "away": 0, "home": 1 } },
            "venue": "Estadio Olimpico Nilton Santos",
            "minute": 63
        }
        """.utf8)
        let liveDTO = try decoder.decode(MatchDTO.self, from: liveJSON)

        match.update(from: liveDTO)

        #expect(match.id == 1492111)
        #expect(match.status == .live)
        #expect(match.homeScore == 2)
        #expect(match.awayScore == 1)
        #expect(match.minute == 63)
        #expect(match.halfTimeHomeScore == 1)
        #expect(match.halfTimeAwayScore == 0)
    }
}
