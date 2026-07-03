import Foundation
import Observation

@Observable
@MainActor
final class StandingsViewModel {
    private(set) var standings: [Standing] = []
    private(set) var isLoading = false
    private nonisolated(unsafe) let service: MatchService

    init(service: MatchService) {
        self.service = service
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        let fetched = (try? await service.fetchStandings()) ?? []
        standings = fetched.sorted { $0.position < $1.position }
    }
}
