import Testing
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
}
