import Foundation
import Observation

@Observable
@MainActor
final class FixturesViewModel {
    private(set) var matches: [Match] = []
    private(set) var isLoading = false
    private nonisolated(unsafe) let service: MatchService

    init(service: MatchService) {
        self.service = service
    }

    var matchesByRound: [(round: Int, matches: [Match])] {
        Dictionary(grouping: matches, by: \.matchday)
            .map { (round: $0.key, matches: $0.value.sorted { $0.utcDate < $1.utcDate }) }
            .sorted { $0.round < $1.round }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        matches = (try? await service.fetchMatches()) ?? []
    }
}
