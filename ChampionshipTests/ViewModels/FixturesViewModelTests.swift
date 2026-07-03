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

    @Test("Loading selects the earliest round that still has an unplayed match")
    func selectsCurrentRoundAsFirstRoundWithUnplayedMatch() async {
        let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)
        let round1Finished = Match(
            id: 1, utcDate: Date(timeIntervalSince1970: 100), status: .finished, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 1, awayScore: 0, winner: "HOME_TEAM", venue: nil, minute: 90
        )
        let round2Scheduled = Match(
            id: 2, utcDate: Date(timeIntervalSince1970: 200), status: .scheduled, matchday: 2, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let round3Scheduled = Match(
            id: 3, utcDate: Date(timeIntervalSince1970: 300), status: .scheduled, matchday: 3, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [round3Scheduled, round1Finished, round2Scheduled], standings: [])
        let viewModel = FixturesViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.selectedRound == 2)
    }

    @Test("Loading skips a round whose only match was postponed, in favor of the next scheduled round")
    func skipsRoundWithOnlyPostponedMatches() async {
        let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)
        let round1Finished = Match(
            id: 1, utcDate: Date(timeIntervalSince1970: 100), status: .finished, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 1, awayScore: 0, winner: "HOME_TEAM", venue: nil, minute: 90
        )
        let round2Postponed = Match(
            id: 2, utcDate: Date(timeIntervalSince1970: 200), status: .postponed, matchday: 2, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let round3Scheduled = Match(
            id: 3, utcDate: Date(timeIntervalSince1970: 300), status: .scheduled, matchday: 3, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [round3Scheduled, round1Finished, round2Postponed], standings: [])
        let viewModel = FixturesViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.selectedRound == 3)
    }

    @Test("Loading falls back to the last round when every match is finished")
    func selectsLastRoundWhenAllMatchesFinished() async {
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
}
