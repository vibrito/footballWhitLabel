import Foundation
import Observation

@Observable
@MainActor
final class FixturesViewModel {
    private(set) var matches: [Match] = []
    private(set) var isLoading = false
    var selectedRound: Int?
    private nonisolated(unsafe) let service: MatchService

    init(service: MatchService) {
        self.service = service
    }

    var matchesByRound: [(round: Int, matches: [Match])] {
        Dictionary(grouping: matches, by: \.matchday)
            .map { (round: $0.key, matches: $0.value.sorted { $0.utcDate < $1.utcDate }) }
            .sorted { $0.round < $1.round }
    }

    var rounds: [Int] {
        matchesByRound.map(\.round)
    }

    var selectedRoundMatches: [Match] {
        guard let selectedRound else { return [] }
        return matchesByRound.first { $0.round == selectedRound }?.matches ?? []
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        matches = (try? await service.fetchMatches()) ?? []
        if selectedRound == nil {
            selectedRound = currentRound()
        }
    }

    // The "current" round is the earliest one with a match that hasn't finished yet —
    // matching how the reference date-picker defaults to today. Once the whole season
    // is finished, fall back to the last round instead of leaving nothing selected.
    private func currentRound() -> Int? {
        let byRound = matchesByRound
        let firstUnfinished = byRound.first { $0.matches.contains { $0.status != .finished } }
        return firstUnfinished?.round ?? byRound.last?.round
    }
}
