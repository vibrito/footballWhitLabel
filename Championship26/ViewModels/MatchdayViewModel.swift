import Foundation
import Observation

@Observable
@MainActor
final class MatchdayViewModel {
    private(set) var matches: [Match] = []
    private(set) var isLoading = false
    private nonisolated(unsafe) let service: MatchService

    init(service: MatchService) {
        self.service = service
    }

    var todaysMatches: [Match] {
        let calendar = Calendar.current
        return matches
            .filter { calendar.isDateInToday($0.utcDate) }
            .sorted { $0.utcDate < $1.utcDate }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        matches = (try? await service.fetchMatches()) ?? []
    }
}
