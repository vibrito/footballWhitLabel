import Foundation
import Observation

@Observable
@MainActor
final class StandingsViewModel {
    private(set) var standings: [Standing] = []
    private(set) var isRefreshing = false
    private nonisolated(unsafe) let service: MatchService

    init(service: MatchService) {
        self.service = service
    }

    func load() async {
        standings = service.cachedStandings().sorted { $0.position < $1.position }
        isRefreshing = true
        defer { isRefreshing = false }
        if let fresh = try? await service.fetchStandings() {
            standings = fresh.sorted { $0.position < $1.position }
        }
    }
}
