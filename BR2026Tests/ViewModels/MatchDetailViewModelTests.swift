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
}
