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

    // The "current" round is not the earliest round with an unplayed match: real
    // fixture lists have makeup games, so an early round can carry a couple of
    // matches rescheduled months later, long after later rounds have been played.
    // Instead: if a match is live right now, that round is current. Otherwise the
    // current round is the one right after the furthest round that has a finished
    // match — i.e. where the season has actually progressed to — falling back to
    // the first round if nothing has been played yet, or the last round if
    // everything has.
    private func currentRound() -> Int? {
        let byRound = matchesByRound
        guard !byRound.isEmpty else { return nil }

        if let liveRound = byRound.first(where: { round in round.matches.contains { $0.status == .live } }) {
            return liveRound.round
        }

        guard let maxFinishedRound = byRound.filter({ round in
            round.matches.contains { $0.status == .finished }
        }).map(\.round).max() else {
            return byRound.first?.round
        }

        let nextRound = byRound.first { $0.round > maxFinishedRound }
        return nextRound?.round ?? byRound.last?.round
    }
}
