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
}
