import Foundation
import SwiftData

/// Persists downloaded team crest bytes in SwiftData, keyed by team id — the same
/// pattern `Competition` uses for its logo. `Team` is a plain value type recreated on
/// almost every data refresh (standings/matches refetch), so `TeamCrestBadge`'s own view
/// identity can't be relied on to survive across refreshes; this store gives crest bytes
/// a stable home independent of that.
@MainActor
struct TeamCrestCacheStore {
    let modelContext: ModelContext

    func cachedImageData(forTeamID teamID: Int, matching url: URL) -> Data? {
        let descriptor = FetchDescriptor<TeamCrestCache>(predicate: #Predicate { $0.teamID == teamID })
        guard let cached = try? modelContext.fetch(descriptor).first, cached.crestURL == url else {
            return nil
        }
        return cached.imageData
    }

    func store(_ imageData: Data, forTeamID teamID: Int, url: URL) {
        let descriptor = FetchDescriptor<TeamCrestCache>(predicate: #Predicate { $0.teamID == teamID })
        if let existing = try? modelContext.fetch(descriptor).first {
            modelContext.delete(existing)
        }
        modelContext.insert(TeamCrestCache(teamID: teamID, crestURL: url, imageData: imageData))
        try? modelContext.save()
    }
}
