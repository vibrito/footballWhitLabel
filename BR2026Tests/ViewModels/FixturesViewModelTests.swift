import Testing
import Foundation
@testable import BR2026

@Suite("FixturesViewModel")
@MainActor
struct FixturesViewModelTests {
    @Test("Groups matches by round, sorted ascending, each round's matches sorted by date")
    func groupsByRound() async {
        let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)
        let earlyRound2 = Match(
            id: 1, utcDate: Date(timeIntervalSince1970: 200), status: .scheduled, matchday: 2, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let lateRound2 = Match(
            id: 2, utcDate: Date(timeIntervalSince1970: 300), status: .scheduled, matchday: 2, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let round1 = Match(
            id: 3, utcDate: Date(timeIntervalSince1970: 100), status: .finished, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 1, awayScore: 0, winner: "HOME_TEAM", venue: nil, minute: 90
        )
        let service = StubMatchService(matches: [lateRound2, round1, earlyRound2], standings: [])
        let viewModel = FixturesViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.matchesByRound.map(\.round) == [1, 2])
        #expect(viewModel.matchesByRound[1].matches.map(\.id) == [1, 2])
    }

    @Test("rounds lists every distinct matchday, sorted ascending")
    func roundsListsDistinctMatchdaysSorted() async {
        let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)
        let matches = [2, 1, 3, 1].enumerated().map { index, round in
            Match(
                id: index, utcDate: Date(timeIntervalSince1970: Double(index)), status: .scheduled, matchday: round,
                stage: "REGULAR_SEASON", homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil,
                venue: nil, minute: nil
            )
        }
        let service = StubMatchService(matches: matches, standings: [])
        let viewModel = FixturesViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.rounds == [1, 2, 3])
    }

    @Test("Loading selects the round right after the furthest round with a finished match")
    func selectsRoundAfterFurthestFinishedRound() async {
        let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)
        let round17Finished = Match(
            id: 1, utcDate: Date(timeIntervalSince1970: 100), status: .finished, matchday: 17, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 1, awayScore: 0, winner: "HOME_TEAM", venue: nil, minute: 90
        )
        let round18Finished = Match(
            id: 2, utcDate: Date(timeIntervalSince1970: 200), status: .finished, matchday: 18, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 2, awayScore: 1, winner: "HOME_TEAM", venue: nil, minute: 90
        )
        let round19Scheduled = Match(
            id: 3, utcDate: Date(timeIntervalSince1970: 300), status: .scheduled, matchday: 19, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [round19Scheduled, round17Finished, round18Finished], standings: [])
        let viewModel = FixturesViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.selectedRound == 19)
    }

    @Test("A round holding makeup games rescheduled far later doesn't hijack selection from the round the season has actually reached")
    func makeupGamesInAnEarlyRoundDoNotHijackSelection() async {
        let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)
        // Round 4 mostly finished back in February, but two matches got rescheduled
        // (not postponed — still SCHEDULED) to July, alongside Round 19. Without
        // ignoring round order, an "earliest unplayed match" scan would pick Round 4
        // even though the league has actually progressed to Round 19.
        let round4FinishedA = Match(
            id: 1, utcDate: Date(timeIntervalSince1970: 100), status: .finished, matchday: 4, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 1, awayScore: 0, winner: "HOME_TEAM", venue: nil, minute: 90
        )
        let round4MakeupGame = Match(
            id: 2, utcDate: Date(timeIntervalSince1970: 1000), status: .scheduled, matchday: 4, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let round18Finished = Match(
            id: 3, utcDate: Date(timeIntervalSince1970: 200), status: .finished, matchday: 18, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 2, awayScore: 1, winner: "HOME_TEAM", venue: nil, minute: 90
        )
        let round19Scheduled = Match(
            id: 4, utcDate: Date(timeIntervalSince1970: 900), status: .scheduled, matchday: 19, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(
            matches: [round19Scheduled, round4FinishedA, round4MakeupGame, round18Finished], standings: []
        )
        let viewModel = FixturesViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.selectedRound == 19)
    }

    @Test("Loading selects the round with a live match, even if earlier rounds have unfinished makeup games")
    func selectsLiveRoundOverEarlierUnfinishedRound() async {
        let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)
        let round4Scheduled = Match(
            id: 1, utcDate: Date(timeIntervalSince1970: 1000), status: .scheduled, matchday: 4, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let round19Live = Match(
            id: 2, utcDate: Date(timeIntervalSince1970: 300), status: .live, matchday: 19, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 1, awayScore: 0, winner: nil, venue: nil, minute: 30
        )
        let service = StubMatchService(matches: [round4Scheduled, round19Live], standings: [])
        let viewModel = FixturesViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.selectedRound == 19)
    }

    @Test("Loading falls back to the first round when nothing has been played yet")
    func selectsFirstRoundWhenNothingFinished() async {
        let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)
        let round1 = Match(
            id: 1, utcDate: Date(timeIntervalSince1970: 100), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let round2 = Match(
            id: 2, utcDate: Date(timeIntervalSince1970: 200), status: .scheduled, matchday: 2, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [round2, round1], standings: [])
        let viewModel = FixturesViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.selectedRound == 1)
    }

    @Test("Loading falls back to the last round when every round has a finished match")
    func selectsLastRoundWhenEverythingFinished() async {
        let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)
        let round1 = Match(
            id: 1, utcDate: Date(timeIntervalSince1970: 100), status: .finished, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 1, awayScore: 0, winner: "HOME_TEAM", venue: nil, minute: 90
        )
        let round2 = Match(
            id: 2, utcDate: Date(timeIntervalSince1970: 200), status: .finished, matchday: 2, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 2, awayScore: 1, winner: "HOME_TEAM", venue: nil, minute: 90
        )
        let service = StubMatchService(matches: [round1, round2], standings: [])
        let viewModel = FixturesViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.selectedRound == 2)
    }

    @Test("selectedRoundMatches returns only the matches for the selected round")
    func selectedRoundMatchesFiltersToSelectedRound() async {
        let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)
        let round1 = Match(
            id: 1, utcDate: Date(timeIntervalSince1970: 100), status: .finished, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 1, awayScore: 0, winner: "HOME_TEAM", venue: nil, minute: 90
        )
        let round2 = Match(
            id: 2, utcDate: Date(timeIntervalSince1970: 200), status: .scheduled, matchday: 2, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [round1, round2], standings: [])
        let viewModel = FixturesViewModel(service: service)

        await viewModel.load()
        viewModel.selectedRound = 1

        #expect(viewModel.selectedRoundMatches.map(\.id) == [1])
    }

    @Test("load() shows cached matches immediately and keeps them if the background refresh fails")
    func loadKeepsCachedDataWhenRefreshFails() async {
        let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)
        let cachedMatch = Match(
            id: 99, utcDate: Date(timeIntervalSince1970: 100), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [], standings: [])
        service.cachedMatchesOverride = [cachedMatch]
        service.shouldThrowOnFetch = true
        let viewModel = FixturesViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.matches.map(\.id) == [99])
    }

    @Test("load() replaces stale cached matches with freshly fetched ones on success")
    func loadReplacesCacheWithFreshDataOnSuccess() async {
        let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)
        let staleMatch = Match(
            id: 1, utcDate: Date(timeIntervalSince1970: 100), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let freshMatch = Match(
            id: 2, utcDate: Date(timeIntervalSince1970: 200), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [freshMatch], standings: [])
        service.cachedMatchesOverride = [staleMatch]
        let viewModel = FixturesViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.matches.map(\.id) == [2])
    }

    @Test("loadOnce() only fetches on the first call, not on repeated calls")
    func loadOnceOnlyFetchesOnce() async {
        let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)
        let match = Match(
            id: 1, utcDate: Date(timeIntervalSince1970: 100), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [match], standings: [])
        let viewModel = FixturesViewModel(service: service)

        await viewModel.loadOnce()
        await viewModel.loadOnce()
        await viewModel.loadOnce()

        #expect(service.fetchMatchesCallCount == 1)
        #expect(viewModel.matches.map(\.id) == [1])
    }

    @Test("hasLiveMatch is true when any match is live")
    func hasLiveMatchTrueWhenLive() async {
        let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)
        let live = Match(
            id: 1, utcDate: Date(), status: .live, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 1, awayScore: 0, winner: nil, venue: nil, minute: 30
        )
        let service = StubMatchService(matches: [live], standings: [])
        let viewModel = FixturesViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.hasLiveMatch == true)
    }

    @Test("hasLiveMatch is false when no match is live")
    func hasLiveMatchFalseWhenNoneLive() async {
        let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)
        let scheduled = Match(
            id: 1, utcDate: Date(), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [scheduled], standings: [])
        let viewModel = FixturesViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.hasLiveMatch == false)
    }

    @Test("refreshIfNeeded does the one-time cache-then-refresh on its first call")
    func refreshIfNeededFirstCallLoadsOnce() async {
        let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)
        let scheduled = Match(
            id: 1, utcDate: Date(), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [scheduled], standings: [])
        let viewModel = FixturesViewModel(service: service)

        await viewModel.refreshIfNeeded()

        #expect(service.fetchMatchesCallCount == 1)
    }

    @Test("refreshIfNeeded refetches on every subsequent call")
    func refreshIfNeededSubsequentCallsAlwaysRefetch() async {
        let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)
        let scheduled = Match(
            id: 1, utcDate: Date(), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [scheduled], standings: [])
        let viewModel = FixturesViewModel(service: service)

        await viewModel.refreshIfNeeded()
        await viewModel.refreshIfNeeded()
        await viewModel.refreshIfNeeded()

        #expect(service.fetchMatchesCallCount == 3)
    }
}
