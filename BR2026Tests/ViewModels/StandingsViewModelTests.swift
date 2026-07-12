import Testing
@testable import BR2026

@Suite("StandingsViewModel")
@MainActor
struct StandingsViewModelTests {
    @Test("Sorts standings by position ascending, regardless of fetch order")
    func sortsByPosition() async {
        let team1 = Team(id: 1, name: "First FC", shortName: "1FC", crestURL: nil)
        let team2 = Team(id: 2, name: "Second FC", shortName: "2FC", crestURL: nil)
        let second = Standing(position: 2, team: team2, playedGames: 10, won: 5, draw: 2, lost: 3, goalsFor: 15, goalsAgainst: 10, goalDifference: 5, points: 17)
        let first = Standing(position: 1, team: team1, playedGames: 10, won: 8, draw: 1, lost: 1, goalsFor: 20, goalsAgainst: 8, goalDifference: 12, points: 25)
        let service = StubMatchService(matches: [], standings: [second, first])
        let viewModel = StandingsViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.standings.map(\.position) == [1, 2])
    }

    @Test("load() shows cached standings immediately and keeps them if the background refresh fails")
    func loadKeepsCachedDataWhenRefreshFails() async {
        let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)
        let cachedStanding = Standing(
            position: 1, team: team, playedGames: 5, won: 3, draw: 1, lost: 1,
            goalsFor: 10, goalsAgainst: 5, goalDifference: 5, points: 10
        )
        let service = StubMatchService(matches: [], standings: [])
        service.cachedStandingsOverride = [cachedStanding]
        service.shouldThrowOnFetch = true
        let viewModel = StandingsViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.standings.map(\.id) == [cachedStanding.id])
    }

    @Test("load() replaces stale cached standings with freshly fetched ones on success")
    func loadReplacesCacheWithFreshDataOnSuccess() async {
        let staleTeam = Team(id: 1, name: "Stale FC", shortName: "STL", crestURL: nil)
        let freshTeam = Team(id: 2, name: "Fresh FC", shortName: "FRS", crestURL: nil)
        let staleStanding = Standing(
            position: 1, team: staleTeam, playedGames: 5, won: 3, draw: 1, lost: 1,
            goalsFor: 10, goalsAgainst: 5, goalDifference: 5, points: 10
        )
        let freshStanding = Standing(
            position: 1, team: freshTeam, playedGames: 6, won: 4, draw: 1, lost: 1,
            goalsFor: 12, goalsAgainst: 5, goalDifference: 7, points: 13
        )
        let service = StubMatchService(matches: [], standings: [freshStanding])
        service.cachedStandingsOverride = [staleStanding]
        let viewModel = StandingsViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.standings.map(\.id) == [freshStanding.id])
    }

    @Test("loadOnce() only fetches on the first call, not on repeated calls")
    func loadOnceOnlyFetchesOnce() async {
        let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)
        let standing = Standing(
            position: 1, team: team, playedGames: 5, won: 3, draw: 1, lost: 1,
            goalsFor: 10, goalsAgainst: 5, goalDifference: 5, points: 10
        )
        let service = StubMatchService(matches: [], standings: [standing])
        let viewModel = StandingsViewModel(service: service)

        await viewModel.loadOnce()
        await viewModel.loadOnce()
        await viewModel.loadOnce()

        #expect(service.fetchStandingsCallCount == 1)
        #expect(viewModel.standings.map(\.id) == [standing.id])
    }
}
