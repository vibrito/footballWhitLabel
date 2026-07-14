import Testing
import Foundation
@testable import BR2026

@Suite("MockMatchService")
@MainActor
struct MockMatchServiceTests {
    @Test("Returns non-empty sample matches")
    func returnsMatches() async throws {
        let service = MockMatchService()
        let matches = try await service.fetchMatches()
        #expect(!matches.isEmpty)
    }

    @Test("Returns a full 20-team table led by Palmeiras with 33 points")
    func returnsStandings() async throws {
        let service = MockMatchService()
        let standings = try await service.fetchStandings()
        #expect(standings.count == 20)
        #expect(standings.first?.team.name == "Palmeiras")
        #expect(standings.first?.points == 33)
    }

    @Test("Sample data includes at least one finished, one scheduled, and one postponed match")
    func coversStatuses() async throws {
        let service = MockMatchService()
        let matches = try await service.fetchMatches()
        let statuses = Set(matches.map(\.status))
        #expect(statuses.contains(.finished))
        #expect(statuses.contains(.scheduled))
        #expect(statuses.contains(.postponed))
    }

    @Test("cachedMatches returns the same sample matches, with no fetch required")
    func cachedMatchesReturnsSampleData() {
        let service = MockMatchService()
        #expect(!service.cachedMatches().isEmpty)
    }

    @Test("cachedStandings returns the same full 20-team sample table")
    func cachedStandingsReturnsSampleData() {
        let service = MockMatchService()
        #expect(service.cachedStandings().count == 20)
    }

    @Test("Returns the Campeonato Brasileiro Série A competition with its logo URL")
    func returnsCompetition() async throws {
        let service = MockMatchService()
        let competition = try await service.fetchCompetition()
        #expect(competition.code == "BSA")
        #expect(competition.name == "Campeonato Brasileiro Série A")
        #expect(competition.logoURL == URL(string: "https://media.api-sports.io/football/leagues/71.png"))
    }

    @Test("Returns Palmeiras's known real colors for all 3 kits")
    func returnsTeamThemeColorSet() async throws {
        let service = MockMatchService()
        let colorSet = try await service.fetchTeamThemeColorSet(teamID: 121)

        #expect(colorSet.home == TeamThemeColors(mainColorHex: "225638", fontColorHex: "ffffff"))
        #expect(colorSet.away == TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "035336"))
        #expect(colorSet.third == TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "2c5434"))
    }

    @Test("cachedTeamThemeColorSet returns the same canned values, with no fetch required")
    func cachedTeamThemeColorSetReturnsSameValues() async throws {
        let service = MockMatchService()
        let fetched = try await service.fetchTeamThemeColorSet(teamID: 121)
        #expect(service.cachedTeamThemeColorSet(teamID: 121) == fetched)
    }
}
