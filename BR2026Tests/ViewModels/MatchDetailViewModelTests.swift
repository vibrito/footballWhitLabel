import Testing
import Foundation
@testable import BR2026

@Suite("MatchDetailViewModel")
@MainActor
struct MatchDetailViewModelTests {
    private let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)

    @Test("load() fetches events for the given match ID")
    func loadFetchesEvents() async {
        let match = Match(
            id: 42, utcDate: Date(), status: .finished, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 2, awayScore: 1, winner: "HOME_TEAM", venue: nil, minute: 90
        )
        let goal = MatchEvent(
            team: .home, type: .goal, assist: nil, detail: "Normal Goal", minute: 10,
            player: "C. Ronaldo", playerOut: nil, extraMinute: nil
        )
        let service = StubMatchService(matches: [match], standings: [], events: [goal])
        let viewModel = MatchDetailViewModel(match: match, service: service)

        await viewModel.load()

        #expect(viewModel.events.map(\.player) == ["C. Ronaldo"])
        #expect(viewModel.isLoading == false)
    }

    @Test("load() keeps already-loaded events if a later fetch fails")
    func loadKeepsEventsWhenLaterFetchFails() async {
        let match = Match(
            id: 42, utcDate: Date(), status: .live, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 1, awayScore: 0, winner: nil, venue: nil, minute: 30
        )
        let goal = MatchEvent(
            team: .home, type: .goal, assist: nil, detail: "Normal Goal", minute: 10,
            player: "C. Ronaldo", playerOut: nil, extraMinute: nil
        )
        let service = StubMatchService(matches: [match], standings: [], events: [goal])
        let viewModel = MatchDetailViewModel(match: match, service: service)

        await viewModel.load()
        #expect(viewModel.events.map(\.player) == ["C. Ronaldo"])

        service.shouldThrowOnFetch = true
        await viewModel.load()

        #expect(viewModel.events.map(\.player) == ["C. Ronaldo"])
    }

    @Test("events are empty before load() runs")
    func eventsEmptyBeforeLoad() {
        let match = Match(
            id: 42, utcDate: Date(), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [match], standings: [])
        let viewModel = MatchDetailViewModel(match: match, service: service)

        #expect(viewModel.events.isEmpty)
    }

    @Test("isLive is true when the match status is live")
    func isLiveTrueWhenLive() {
        let match = Match(
            id: 42, utcDate: Date(), status: .live, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 1, awayScore: 0, winner: nil, venue: nil, minute: 30
        )
        let service = StubMatchService(matches: [match], standings: [])
        let viewModel = MatchDetailViewModel(match: match, service: service)

        #expect(viewModel.isLive == true)
    }

    @Test("isLive is false when the match status is not live")
    func isLiveFalseWhenNotLive() {
        let match = Match(
            id: 42, utcDate: Date(), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [match], standings: [])
        let viewModel = MatchDetailViewModel(match: match, service: service)

        #expect(viewModel.isLive == false)
    }

    @Test("selectedSegment defaults to .timeline")
    func selectedSegmentDefaultsToTimeline() {
        let match = Match(
            id: 42, utcDate: Date(), status: .finished, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 2, awayScore: 1, winner: "HOME_TEAM", venue: nil, minute: 90
        )
        let service = StubMatchService(matches: [match], standings: [])
        let viewModel = MatchDetailViewModel(match: match, service: service)

        #expect(viewModel.selectedSegment == .timeline)
    }

    @Test("loadStatisticsIfNeeded() fetches statistics for the given match ID")
    func loadStatisticsIfNeededFetchesStatistics() async {
        let match = Match(
            id: 42, utcDate: Date(), status: .finished, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 2, awayScore: 1, winner: "HOME_TEAM", venue: nil, minute: 90
        )
        let stats = MatchStatistics(
            home: TeamStats(fouls: 10, shots: 17, corners: 5, possession: 48, passAccuracy: 81, shotsOnTarget: 7),
            away: TeamStats(fouls: 13, shots: 22, corners: 5, possession: 52, passAccuracy: 79, shotsOnTarget: 9)
        )
        let service = StubMatchService(matches: [match], standings: [])
        service.statisticsOverride = stats
        let viewModel = MatchDetailViewModel(match: match, service: service)

        await viewModel.loadStatisticsIfNeeded()

        #expect(viewModel.statistics?.home.possession == 48)
    }

    @Test("loadStatisticsIfNeeded() is a no-op on a second call")
    func loadStatisticsIfNeededIsNoOpOnSecondCall() async {
        let match = Match(
            id: 42, utcDate: Date(), status: .finished, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 2, awayScore: 1, winner: "HOME_TEAM", venue: nil, minute: 90
        )
        let stats = MatchStatistics(
            home: TeamStats(fouls: 10, shots: 17, corners: 5, possession: 48, passAccuracy: 81, shotsOnTarget: 7),
            away: TeamStats(fouls: 13, shots: 22, corners: 5, possession: 52, passAccuracy: 79, shotsOnTarget: 9)
        )
        let service = StubMatchService(matches: [match], standings: [])
        service.statisticsOverride = stats
        let viewModel = MatchDetailViewModel(match: match, service: service)

        await viewModel.loadStatisticsIfNeeded()
        service.statisticsOverride = nil
        await viewModel.loadStatisticsIfNeeded()

        // Still the first-loaded value — the second call never re-fetched.
        #expect(viewModel.statistics?.home.possession == 48)
    }

    @Test("loadLineupsIfNeeded() fetches lineups for the given match ID")
    func loadLineupsIfNeededFetchesLineups() async {
        let match = Match(
            id: 42, utcDate: Date(), status: .finished, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 2, awayScore: 1, winner: "HOME_TEAM", venue: nil, minute: 90
        )
        let lineup = MatchLineup(dto: try! JSONDecoder().decode(MatchLineupDTO.self, from: Data("""
        {
            "home": { "colors": { "fontColor": "ffffff", "mainColor": "6e202e", "secondaryColor": "6e202e" }, "formation": "4-2-3-1", "startingXI": [], "substitutes": [] },
            "away": { "colors": { "fontColor": "f50000", "mainColor": "fcfcfc", "secondaryColor": "fcfcfc" }, "formation": "4-1-4-1", "startingXI": [], "substitutes": [] }
        }
        """.utf8)))
        let service = StubMatchService(matches: [match], standings: [])
        service.lineupsOverride = lineup
        let viewModel = MatchDetailViewModel(match: match, service: service)

        await viewModel.loadLineupsIfNeeded()

        #expect(viewModel.lineups?.home.formation == "4-2-3-1")
    }

    @Test("statistics and lineups are nil before either load method runs")
    func statisticsAndLineupsNilBeforeLoad() {
        let match = Match(
            id: 42, utcDate: Date(), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [match], standings: [])
        let viewModel = MatchDetailViewModel(match: match, service: service)

        #expect(viewModel.statistics == nil)
        #expect(viewModel.lineups == nil)
    }
}
