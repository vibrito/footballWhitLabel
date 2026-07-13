import Testing
import Foundation
import SwiftData
@testable import BR2026

// Deliberate, scoped exception to "no SwiftData container in unit tests" (see
// MatchSwiftDataTests): this store's whole job is the SwiftData round-trip, so an
// in-memory container is the only way to actually exercise it.
@Suite("TeamCrestCacheStore")
@MainActor
struct TeamCrestCacheStoreTests {
    private func makeStore() throws -> TeamCrestCacheStore {
        let container = try ModelContainer(
            for: TeamCrestCache.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return TeamCrestCacheStore(modelContext: ModelContext(container))
    }

    @Test("Returns nil when nothing has been cached for a team")
    func cacheMiss() throws {
        let store = try makeStore()
        let url = URL(string: "https://media.api-sports.io/football/teams/121.png")!
        #expect(store.cachedImageData(forTeamID: 121, matching: url) == nil)
    }

    @Test("Stored image data round-trips for the same team and URL")
    func cacheHit() throws {
        let store = try makeStore()
        let url = URL(string: "https://media.api-sports.io/football/teams/121.png")!
        let data = Data([0x01, 0x02, 0x03])

        store.store(data, forTeamID: 121, url: url)

        #expect(store.cachedImageData(forTeamID: 121, matching: url) == data)
    }

    @Test("A cached entry is ignored if the team's crest URL has since changed")
    func staleURLIsIgnored() throws {
        let store = try makeStore()
        let oldURL = URL(string: "https://media.api-sports.io/football/teams/121.png")!
        let newURL = URL(string: "https://media.api-sports.io/football/teams/121-new.png")!
        store.store(Data([0x01]), forTeamID: 121, url: oldURL)

        #expect(store.cachedImageData(forTeamID: 121, matching: newURL) == nil)
    }

    @Test("Storing again for the same team replaces the previous entry rather than duplicating it")
    func storeReplacesExistingEntry() throws {
        let store = try makeStore()
        let url = URL(string: "https://media.api-sports.io/football/teams/121.png")!
        store.store(Data([0x01]), forTeamID: 121, url: url)
        store.store(Data([0x02]), forTeamID: 121, url: url)

        #expect(store.cachedImageData(forTeamID: 121, matching: url) == Data([0x02]))
    }
}
