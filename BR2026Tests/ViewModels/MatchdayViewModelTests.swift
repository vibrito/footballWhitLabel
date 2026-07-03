import Testing
import Foundation
@testable import BR2026

@Suite("MatchdayViewModel")
@MainActor
struct MatchdayViewModelTests {
    private let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)

    private func date(day: Int, hour: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour))!
    }

    @Test("nextMatch is the earliest live-or-scheduled match, ignoring finished ones")
    func nextMatchIsEarliestUpcoming() async {
        let finishedYesterday = Match(
            id: 1, utcDate: date(day: 9, hour: 20), status: .finished, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 1, awayScore: 0, winner: "HOME_TEAM", venue: nil, minute: 90
        )
        let scheduledLater = Match(
            id: 2, utcDate: date(day: 10, hour: 20), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let scheduledSooner = Match(
            id: 3, utcDate: date(day: 10, hour: 16), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [scheduledLater, finishedYesterday, scheduledSooner], standings: [])
        let viewModel = MatchdayViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.nextMatch?.id == 3)
    }

    @Test("nextMatch prefers a match live right now over one scheduled for a later day")
    func nextMatchPrefersLiveMatch() async {
        let live = Match(
            id: 1, utcDate: date(day: 10, hour: 15), status: .live, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 1, awayScore: 0, winner: nil, venue: nil, minute: 30
        )
        let scheduledTomorrow = Match(
            id: 2, utcDate: date(day: 11, hour: 15), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [scheduledTomorrow, live], standings: [])
        let viewModel = MatchdayViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.nextMatch?.id == 1)
    }

    @Test("otherMatchesForNextMatchDay returns same-day matches excluding nextMatch, sorted by kickoff")
    func otherMatchesForNextMatchDayFiltersAndSorts() async {
        let next = Match(
            id: 1, utcDate: date(day: 10, hour: 12), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let sameDayLater = Match(
            id: 2, utcDate: date(day: 10, hour: 20), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let sameDayEarlier = Match(
            id: 3, utcDate: date(day: 10, hour: 15), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let differentDay = Match(
            id: 4, utcDate: date(day: 11, hour: 12), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [differentDay, sameDayLater, next, sameDayEarlier], standings: [])
        let viewModel = MatchdayViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.otherMatchesForNextMatchDay.map(\.id) == [3, 2])
    }

    @Test("finishedMatchesForNextMatchDay and upcomingMatchesForNextMatchDay split same-day matches by status")
    func splitsOtherMatchesByFinishedStatus() async {
        let next = Match(
            id: 1, utcDate: date(day: 10, hour: 12), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let finishedSameDay = Match(
            id: 2, utcDate: date(day: 10, hour: 9), status: .finished, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 1, awayScore: 0, winner: "HOME_TEAM", venue: nil, minute: 90
        )
        let scheduledSameDay = Match(
            id: 3, utcDate: date(day: 10, hour: 20), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [scheduledSameDay, next, finishedSameDay], standings: [])
        let viewModel = MatchdayViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.finishedMatchesForNextMatchDay.map(\.id) == [2])
        #expect(viewModel.upcomingMatchesForNextMatchDay.map(\.id) == [3])
    }

    @Test("nextMatch and otherMatchesForNextMatchDay are empty when nothing is live or scheduled")
    func emptyWhenNothingUpcoming() async {
        let finished = Match(
            id: 1, utcDate: date(day: 10, hour: 12), status: .finished, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 1, awayScore: 0, winner: "HOME_TEAM", venue: nil, minute: 90
        )
        let service = StubMatchService(matches: [finished], standings: [])
        let viewModel = MatchdayViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.nextMatch == nil)
        #expect(viewModel.otherMatchesForNextMatchDay.isEmpty)
    }
}

final class StubMatchService: MatchService {
    let matches: [Match]
    let standings: [Standing]
    let events: [MatchEvent]
    init(matches: [Match], standings: [Standing], events: [MatchEvent] = []) {
        self.matches = matches
        self.standings = standings
        self.events = events
    }
    func fetchMatches() async throws -> [Match] { matches }
    func fetchStandings() async throws -> [Standing] { standings }
    func fetchEvents(matchID: Int) async throws -> [MatchEvent] { events }
}
