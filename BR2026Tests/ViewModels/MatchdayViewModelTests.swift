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

    @Test("load() shows cached matches immediately and keeps them if the background refresh fails")
    func loadKeepsCachedDataWhenRefreshFails() async {
        let cachedMatch = Match(
            id: 99, utcDate: date(day: 1, hour: 12), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [], standings: [])
        service.cachedMatchesOverride = [cachedMatch]
        service.shouldThrowOnFetch = true
        let viewModel = MatchdayViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.matches.map(\.id) == [99])
        #expect(viewModel.isRefreshing == false)
    }

    @Test("load() replaces stale cached matches with freshly fetched ones on success")
    func loadReplacesCacheWithFreshDataOnSuccess() async {
        let staleMatch = Match(
            id: 1, utcDate: date(day: 1, hour: 12), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let freshMatch = Match(
            id: 2, utcDate: date(day: 2, hour: 12), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [freshMatch], standings: [])
        service.cachedMatchesOverride = [staleMatch]
        let viewModel = MatchdayViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.matches.map(\.id) == [2])
    }

    @Test("loadOnce() only fetches on the first call, not on repeated calls")
    func loadOnceOnlyFetchesOnce() async {
        let match = Match(
            id: 1, utcDate: date(day: 1, hour: 12), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [match], standings: [])
        let viewModel = MatchdayViewModel(service: service)

        await viewModel.loadOnce()
        await viewModel.loadOnce()
        await viewModel.loadOnce()

        #expect(service.fetchMatchesCallCount == 1)
        #expect(viewModel.matches.map(\.id) == [1])
    }
}

final class StubMatchService: MatchService {
    let matches: [Match]
    let standings: [Standing]
    let events: [MatchEvent]
    let competition: Competition
    var cachedMatchesOverride: [Match]?
    var cachedStandingsOverride: [Standing]?
    var cachedCompetitionOverride: Competition?
    var shouldThrowOnFetch = false
    private(set) var fetchMatchesCallCount = 0
    private(set) var fetchStandingsCallCount = 0

    init(
        matches: [Match],
        standings: [Standing],
        events: [MatchEvent] = [],
        competition: Competition = Competition(
            code: "BSA", name: "Campeonato Brasileiro Série A", season: 2026,
            logoURL: URL(string: "https://example.com/logo.png")!
        )
    ) {
        self.matches = matches
        self.standings = standings
        self.events = events
        self.competition = competition
    }

    func fetchMatches() async throws -> [Match] {
        fetchMatchesCallCount += 1
        if shouldThrowOnFetch { throw StubServiceError.simulatedFailure }
        return matches
    }

    func fetchStandings() async throws -> [Standing] {
        fetchStandingsCallCount += 1
        if shouldThrowOnFetch { throw StubServiceError.simulatedFailure }
        return standings
    }

    func fetchEvents(matchID: Int) async throws -> [MatchEvent] { events }

    func fetchCompetition() async throws -> Competition {
        if shouldThrowOnFetch { throw StubServiceError.simulatedFailure }
        return competition
    }

    func cachedMatches() -> [Match] { cachedMatchesOverride ?? matches }
    func cachedStandings() -> [Standing] { cachedStandingsOverride ?? standings }
    func cachedCompetition() -> Competition? { cachedCompetitionOverride }
}

enum StubServiceError: Error {
    case simulatedFailure
}
