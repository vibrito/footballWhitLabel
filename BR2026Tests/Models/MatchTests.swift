import Testing
import Foundation
@testable import BR2026

@Suite("MatchStatus decoding")
struct MatchStatusTests {
    @Test("Decodes known statuses", arguments: [
        ("SCHEDULED", MatchStatus.scheduled),
        ("LIVE", MatchStatus.live),
        ("IN_PLAY", MatchStatus.live),
        ("PAUSED", MatchStatus.halftime),
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

    @Test("isLiveOrHalftime is true for live and halftime, false otherwise", arguments: [
        (MatchStatus.scheduled, false),
        (MatchStatus.live, true),
        (MatchStatus.halftime, true),
        (MatchStatus.finished, false),
        (MatchStatus.postponed, false)
    ])
    func isLiveOrHalftime(status: MatchStatus, expected: Bool) throws {
        #expect(status.isLiveOrHalftime == expected)
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

    @Test("accessibilityLabel for a scheduled match")
    func accessibilityLabelScheduled() throws {
        let team1 = Team(id: 1, name: "Flamengo", shortName: "Flamengo", crestURL: nil)
        let team2 = Team(id: 2, name: "Palmeiras", shortName: "Palmeiras", crestURL: nil)
        let match = Match(
            id: 1, utcDate: Date(timeIntervalSince1970: 1_700_000_000), status: .scheduled,
            matchday: 1, stage: "REGULAR_SEASON", homeTeam: team1, awayTeam: team2,
            homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        #expect(match.accessibilityLabel.contains("Flamengo"))
        #expect(match.accessibilityLabel.contains("Palmeiras"))
    }

    @Test("accessibilityLabel for a live match includes the score and minute")
    func accessibilityLabelLive() throws {
        let team1 = Team(id: 1, name: "Flamengo", shortName: "Flamengo", crestURL: nil)
        let team2 = Team(id: 2, name: "Palmeiras", shortName: "Palmeiras", crestURL: nil)
        let match = Match(
            id: 1, utcDate: Date(), status: .live, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team1, awayTeam: team2, homeScore: 2, awayScore: 1, winner: nil,
            venue: nil, minute: 67
        )
        let label = match.accessibilityLabel
        #expect(label.contains("2"))
        #expect(label.contains("1"))
        #expect(label.contains("67"))
    }

    @Test("accessibilityLabel for a finished match")
    func accessibilityLabelFinished() throws {
        let team1 = Team(id: 1, name: "Flamengo", shortName: "Flamengo", crestURL: nil)
        let team2 = Team(id: 2, name: "Palmeiras", shortName: "Palmeiras", crestURL: nil)
        let match = Match(
            id: 1, utcDate: Date(), status: .finished, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team1, awayTeam: team2, homeScore: 3, awayScore: 0, winner: "HOME_TEAM",
            venue: nil, minute: 90
        )
        let label = match.accessibilityLabel
        #expect(label.contains("3"))
        #expect(label.contains("0"))
    }

    @Test("accessibilityLabel for a postponed match")
    func accessibilityLabelPostponed() throws {
        let team1 = Team(id: 1, name: "Flamengo", shortName: "Flamengo", crestURL: nil)
        let team2 = Team(id: 2, name: "Palmeiras", shortName: "Palmeiras", crestURL: nil)
        let match = Match(
            id: 1, utcDate: Date(), status: .postponed, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team1, awayTeam: team2, homeScore: nil, awayScore: nil, winner: nil,
            venue: nil, minute: nil
        )
        #expect(match.accessibilityLabel.contains("Flamengo"))
        #expect(match.accessibilityLabel.contains("Palmeiras"))
    }

    @Test("accessibilityAnnouncement returns nil when nothing meaningful changed")
    func accessibilityAnnouncementNilWhenUnchanged() throws {
        let team1 = Team(id: 1, name: "Flamengo", shortName: "Flamengo", crestURL: nil)
        let team2 = Team(id: 2, name: "Palmeiras", shortName: "Palmeiras", crestURL: nil)
        let previous = Match(
            id: 1, utcDate: Date(), status: .live, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team1, awayTeam: team2, homeScore: 1, awayScore: 0, winner: nil,
            venue: nil, minute: 40
        )
        let current = Match(
            id: 1, utcDate: Date(), status: .live, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team1, awayTeam: team2, homeScore: 1, awayScore: 0, winner: nil,
            venue: nil, minute: 41
        )
        #expect(current.accessibilityAnnouncement(comparedTo: previous) == nil)
    }

    @Test("accessibilityAnnouncement announces a home goal")
    func accessibilityAnnouncementHomeGoal() throws {
        let team1 = Team(id: 1, name: "Flamengo", shortName: "Flamengo", crestURL: nil)
        let team2 = Team(id: 2, name: "Palmeiras", shortName: "Palmeiras", crestURL: nil)
        let previous = Match(
            id: 1, utcDate: Date(), status: .live, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team1, awayTeam: team2, homeScore: 0, awayScore: 0, winner: nil,
            venue: nil, minute: 40
        )
        let current = Match(
            id: 1, utcDate: Date(), status: .live, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team1, awayTeam: team2, homeScore: 1, awayScore: 0, winner: nil,
            venue: nil, minute: 41
        )
        let announcement = try #require(current.accessibilityAnnouncement(comparedTo: previous))
        #expect(announcement.contains("Flamengo"))
    }

    @Test("accessibilityAnnouncement announces a status transition to live")
    func accessibilityAnnouncementKickoff() throws {
        let team1 = Team(id: 1, name: "Flamengo", shortName: "Flamengo", crestURL: nil)
        let team2 = Team(id: 2, name: "Palmeiras", shortName: "Palmeiras", crestURL: nil)
        let previous = Match(
            id: 1, utcDate: Date(), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team1, awayTeam: team2, homeScore: nil, awayScore: nil, winner: nil,
            venue: nil, minute: nil
        )
        let current = Match(
            id: 1, utcDate: Date(), status: .live, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team1, awayTeam: team2, homeScore: 0, awayScore: 0, winner: nil,
            venue: nil, minute: 1
        )
        let announcement = try #require(current.accessibilityAnnouncement(comparedTo: previous))
        #expect(announcement.contains("Flamengo"))
    }

    @Test("accessibilityAnnouncement announces the final whistle")
    func accessibilityAnnouncementFullTime() throws {
        let team1 = Team(id: 1, name: "Flamengo", shortName: "Flamengo", crestURL: nil)
        let team2 = Team(id: 2, name: "Palmeiras", shortName: "Palmeiras", crestURL: nil)
        let previous = Match(
            id: 1, utcDate: Date(), status: .live, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team1, awayTeam: team2, homeScore: 2, awayScore: 1, winner: nil,
            venue: nil, minute: 90
        )
        let current = Match(
            id: 1, utcDate: Date(), status: .finished, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team1, awayTeam: team2, homeScore: 2, awayScore: 1, winner: "HOME_TEAM",
            venue: nil, minute: 90
        )
        let announcement = try #require(current.accessibilityAnnouncement(comparedTo: previous))
        #expect(announcement.contains("Flamengo"))
    }
}
