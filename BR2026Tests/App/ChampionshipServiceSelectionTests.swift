import Testing
@testable import BR2026

@Suite("Snapshot service selection")
struct ChampionshipServiceSelectionTests {
    @Test("Uses mock data when the -FASTLANE_SNAPSHOT launch argument is present")
    func usesMockWhenSnapshotting() {
        #expect(ChampionshipApp.shouldUseMockService(arguments: ["/path/to/app", "-FASTLANE_SNAPSHOT", "YES"]))
    }

    @Test("Does not force mock data in normal launches")
    func doesNotForceOtherwise() {
        #expect(!ChampionshipApp.shouldUseMockService(arguments: ["/path/to/app"]))
    }
}
