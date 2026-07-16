import Foundation
import Observation

@Observable
@MainActor
final class FixturesViewModel {
    private(set) var matches: [Match] = []
    private(set) var isRefreshing = false
    private var hasLoadedOnce = false
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

    // `.task` on the view restarts every time the tab reappears, not just on first
    // launch. Calling `load()` unconditionally there — on top of `.refreshable` also
    // being attached to the same ScrollView — caused a visible content jump on every
    // tab revisit: the pull-to-refresh control's layout negotiation collides with the
    // `isRefreshing`/`matches` state changes `load()` makes mid-reappear. Auto-loading
    // only once keeps the cached-then-refresh behavior on first launch while leaving
    // later refreshes to the explicit `.refreshable` pull gesture, which isn't racing
    // against a reappear transition.
    func loadOnce() async {
        guard !hasLoadedOnce else { return }
        hasLoadedOnce = true
        await load()
    }

    func load() async {
        matches = service.cachedMatches()
        selectRoundIfNeeded()
        isRefreshing = true
        defer { isRefreshing = false }
        if let fresh = try? await service.fetchMatches() {
            matches = fresh
            selectRoundIfNeeded()
        }
    }

    var hasLiveMatch: Bool {
        matches.contains { $0.status == .live }
    }

    func refreshIfNeeded() async {
        if hasLoadedOnce {
            await load()
        } else {
            await loadOnce()
        }
    }

    func pollWhileLive() async {
        await LivePoller.run(interval: .seconds(30), shouldContinue: { hasLiveMatch }, action: { await load() })
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

    // Called once from cache and again after a successful fetch — a no-op the second
    // time whenever the cache was already non-empty, since selectedRound is only ever
    // auto-picked once. Without the cache-time call, a returning user's round picker
    // would stay empty (selectedRoundMatches == []) during the instant-paint phase,
    // even though matches are already on screen.
    private func selectRoundIfNeeded() {
        if selectedRound == nil {
            selectedRound = currentRound()
        }
    }
}
