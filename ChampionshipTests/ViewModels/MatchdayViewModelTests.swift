import Testing
import Foundation
@testable import Championship26

@Suite("MatchdayViewModel")
@MainActor
struct MatchdayViewModelTests {
    @Test("Matchday tab shows only today's matches")
    func filtersToToday() async {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)
        let todayMatch = Match(
            id: 1, utcDate: today, status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let pastMatch = Match(
            id: 2, utcDate: yesterday, status: .finished, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 1, awayScore: 0, winner: "HOME_TEAM", venue: nil, minute: 90
        )
        let service = StubMatchService(matches: [todayMatch, pastMatch], standings: [])
        let viewModel = MatchdayViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.todaysMatches.map(\.id) == [1])
    }
}

final class StubMatchService: MatchService {
    let matches: [Match]
    let standings: [Standing]
    init(matches: [Match], standings: [Standing]) {
        self.matches = matches
        self.standings = standings
    }
    func fetchMatches() async throws -> [Match] { matches }
    func fetchStandings() async throws -> [Standing] { standings }
}
