import Testing
@testable import BR2026

@Suite("Snapshot service selection")
struct ChampionshipServiceSelectionTests {
    @Test("Uses mock data when FASTLANE_SNAPSHOT is set")
    func usesMockWhenSnapshotting() {
        #expect(ChampionshipApp.shouldUseMockService(environment: ["FASTLANE_SNAPSHOT": "YES"]))
    }

    @Test("Does not force mock data in normal launches")
    func doesNotForceOtherwise() {
        #expect(!ChampionshipApp.shouldUseMockService(environment: [:]))
    }
}
