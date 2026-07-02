import Testing
@testable import Championship26

@Suite("MockMatchService")
@MainActor
struct MockMatchServiceTests {
    @Test("Returns non-empty sample matches")
    func returnsMatches() async throws {
        let service = MockMatchService()
        let matches = try await service.fetchMatches()
        #expect(!matches.isEmpty)
    }

    @Test("Returns standings led by Palmeiras with 41 points")
    func returnsStandings() async throws {
        let service = MockMatchService()
        let standings = try await service.fetchStandings()
        #expect(standings.first?.team.name == "Palmeiras")
        #expect(standings.first?.points == 41)
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
}
