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

    @Test("Returns Palmeiras's known real home color")
    func returnsPalmeirasTeamThemeColorSet() async throws {
        let service = MockMatchService()
        let colorSet = try await service.fetchTeamThemeColorSet(teamID: 121)

        #expect(colorSet.home == TeamThemeColors(mainColorHex: "225638", fontColorHex: "ffffff"))
        #expect(colorSet.away == nil)
        #expect(colorSet.third == nil)
    }

    @Test("Returns Flamengo's known real home color")
    func returnsFlamengoTeamThemeColorSet() async throws {
        let service = MockMatchService()
        let colorSet = try await service.fetchTeamThemeColorSet(teamID: 127)

        #expect(colorSet.home == TeamThemeColors(mainColorHex: "ab1b10", fontColorHex: "ffffff"))
    }

    @Test("Returns Fluminense's known real home color")
    func returnsFluminenseTeamThemeColorSet() async throws {
        let service = MockMatchService()
        let colorSet = try await service.fetchTeamThemeColorSet(teamID: 124)

        #expect(colorSet.home == TeamThemeColors(mainColorHex: "6e202e", fontColorHex: "ffffff"))
    }

    @Test("Returns Bahia's known real home color")
    func returnsBahiaTeamThemeColorSet() async throws {
        let service = MockMatchService()
        let colorSet = try await service.fetchTeamThemeColorSet(teamID: 118)

        #expect(colorSet.home == TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "043a73"))
    }

    @Test("Returns Red Bull Bragantino's known real home color")
    func returnsRedBullBragantinoTeamThemeColorSet() async throws {
        let service = MockMatchService()
        let colorSet = try await service.fetchTeamThemeColorSet(teamID: 794)

        #expect(colorSet.home == TeamThemeColors(mainColorHex: "fcfcfc", fontColorHex: "f50000"))
    }

    @Test("Returns Coritiba's known real home color")
    func returnsCoritibaTeamThemeColorSet() async throws {
        let service = MockMatchService()
        let colorSet = try await service.fetchTeamThemeColorSet(teamID: 147)

        #expect(colorSet.home == TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "000000"))
    }

    @Test("Returns São Paulo's known real home color")
    func returnsSaoPauloTeamThemeColorSet() async throws {
        let service = MockMatchService()
        let colorSet = try await service.fetchTeamThemeColorSet(teamID: 126)

        #expect(colorSet.home == TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "000000"))
    }

    @Test("Returns Atlético Mineiro's known real home color")
    func returnsAtleticoMineiroTeamThemeColorSet() async throws {
        let service = MockMatchService()
        let colorSet = try await service.fetchTeamThemeColorSet(teamID: 1062)

        #expect(colorSet.home == TeamThemeColors(mainColorHex: "000000", fontColorHex: "ffffff"))
    }

    @Test("Returns Corinthians's known real home color")
    func returnsCorinthiansTeamThemeColorSet() async throws {
        let service = MockMatchService()
        let colorSet = try await service.fetchTeamThemeColorSet(teamID: 131)

        #expect(colorSet.home == TeamThemeColors(mainColorHex: "fcfbee", fontColorHex: "000000"))
    }

    @Test("Throws for a team id with no canned colors")
    func throwsForUnknownTeam() async throws {
        let service = MockMatchService()
        await #expect(throws: (any Error).self) {
            try await service.fetchTeamThemeColorSet(teamID: 999)
        }
    }

    @Test("cachedTeamThemeColorSet returns the same canned values, with no fetch required")
    func cachedTeamThemeColorSetReturnsSameValues() async throws {
        let service = MockMatchService()
        let fetched = try await service.fetchTeamThemeColorSet(teamID: 121)
        #expect(service.cachedTeamThemeColorSet(teamID: 121) == fetched)
    }
}
