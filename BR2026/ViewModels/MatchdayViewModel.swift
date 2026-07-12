import Foundation
import Observation

@Observable
@MainActor
final class MatchdayViewModel {
    private(set) var matches: [Match] = []
    private(set) var isRefreshing = false
    private nonisolated(unsafe) let service: MatchService

    init(service: MatchService) {
        self.service = service
    }

    // The featured match is the earliest one still to be decided — a match already
    // live sorts before any future kickoff, so it naturally wins over a later
    // scheduled match without special-casing status.
    var nextMatch: Match? {
        matches
            .filter { $0.status == .live || $0.status == .scheduled }
            .min { $0.utcDate < $1.utcDate }
    }

    var otherMatchesForNextMatchDay: [Match] {
        guard let nextMatch else { return [] }
        let calendar = Calendar.current
        return matches
            .filter { $0.id != nextMatch.id && calendar.isDate($0.utcDate, inSameDayAs: nextMatch.utcDate) }
            .sorted { $0.utcDate < $1.utcDate }
    }

    var finishedMatchesForNextMatchDay: [Match] {
        otherMatchesForNextMatchDay.filter { $0.status == .finished }
    }

    var upcomingMatchesForNextMatchDay: [Match] {
        otherMatchesForNextMatchDay.filter { $0.status != .finished }
    }

    func load() async {
        matches = service.cachedMatches()
        isRefreshing = true
        defer { isRefreshing = false }
        if let fresh = try? await service.fetchMatches() {
            matches = fresh
        }
    }
}
