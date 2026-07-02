import Testing
import Foundation
@testable import Championship26

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
}
