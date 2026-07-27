import Foundation
import Observation
import UIKit

struct FixturesSection: Identifiable {
    let id: String
    let title: String
    let matches: [Match]
}

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

    /// The selected round split into live / finished / upcoming, mirroring Fixture 2026's
    /// Fixtures screen. Empty groups are dropped so no header appears without rows.
    var sections: [FixturesSection] {
        // Postponed matches stay in the list. This screen is the round, and a round of ten
        // with one called off is still a round of ten — dropping it made the round look
        // short with no explanation. What they must not do is sit among the upcoming ones:
        // they keep the kickoff they were called off from, and that time will not happen.
        // So they are excluded from every other section and collected into their own, last.
        let matches = selectedRoundMatches
        var result: [FixturesSection] = []

        let live = matches.filter(\.status.isLiveOrHalftime)
        if !live.isEmpty {
            result.append(FixturesSection(
                id: "live",
                title: String(localized: "Live now", comment: "Fixtures section header above matches currently being played."),
                matches: live
            ))
        }

        let upcoming = matches.filter {
            !$0.status.isLiveOrHalftime && $0.status != .finished && $0.status != .postponed
        }
        if !upcoming.isEmpty {
            // Fixture 2026 never says "later today" for a league, because a round can span
            // several days and the label would lie. Decide per round instead: only claim
            // "today" when every unplayed match in this round actually is today.
            let calendar = Calendar.current
            let allToday = upcoming.allSatisfy { calendar.isDateInToday($0.utcDate) }
            let title = allToday
                ? String(localized: "Later today", comment: "Fixtures section header above matches still to be played today.")
                : String(localized: "Upcoming", comment: "Fixtures section header above matches still to be played, on this or a later day.")
            result.append(FixturesSection(id: "upcoming", title: title, matches: upcoming))
        }

        // Finished goes last, below what is still to come — a round you are checking is
        // usually about the matches ahead, not the ones already played.
        let finished = matches.filter { $0.status == .finished }
        if !finished.isEmpty {
            result.append(FixturesSection(
                id: "finished",
                title: String(localized: "Finished", comment: "Fixtures section header above matches that have ended."),
                matches: finished
            ))
        }

        // Last, below even the finished ones: a called-off fixture is the least useful thing
        // on the screen, and its kickoff time is the one piece of information on the card
        // that is no longer true.
        let postponed = matches.filter { $0.status == .postponed }
        if !postponed.isEmpty {
            result.append(FixturesSection(
                id: "postponed",
                title: String(localized: "Postponed", comment: "Fixtures section header above matches that have been called off. They stay in the round but sit below everything else, because the kickoff they still carry will not happen."),
                matches: postponed
            ))
        }

        return result
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

    /// Listings for the loaded matches, keyed by match id, unfiltered by country. Not
    /// persisted with the matches, so empty until a refresh lands. See `Broadcast`.
    private(set) var broadcasts: [Int: [Broadcast]] = [:]

    /// Every country the loaded listings cover — what the More screen's picker offers.
    var broadcastCountries: [String] {
        Array(Set(broadcasts.values.flatMap { $0 }.map(\.country))).sorted()
    }

    func load() async {
        matches = service.cachedMatches()
        selectRoundIfNeeded()
        isRefreshing = true
        defer { isRefreshing = false }
        if let fresh = try? await service.fetchMatches() {
            announceChanges(from: matches, to: fresh)
            matches = fresh
            broadcasts = service.latestBroadcasts()
            selectRoundIfNeeded()
        }
    }

    private func announceChanges(from old: [Match], to new: [Match]) {
        let oldByID = Dictionary(uniqueKeysWithValues: old.map { ($0.id, $0) })
        for match in new {
            guard let previous = oldByID[match.id],
                  let announcement = match.accessibilityAnnouncement(comparedTo: previous) else { continue }
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }
    }

    var hasLiveMatch: Bool {
        matches.contains { $0.status.isLiveOrHalftime }
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
    // current round is the one right after the furthest round that is fully
    // finished (every match in it played) — i.e. where the season has actually
    // progressed to — falling back to the first round if nothing has been played
    // yet, or the last round if everything has. Deliberately "fully finished", not
    // "has any finished match": Brazilian rounds spread across several days, so a
    // round can have some matches already played and others still upcoming — that
    // round is still current, not skipped past in favor of the next one.
    private func currentRound() -> Int? {
        let byRound = matchesByRound
        guard !byRound.isEmpty else { return nil }

        if let liveRound = byRound.first(where: { round in round.matches.contains { $0.status.isLiveOrHalftime } }) {
            return liveRound.round
        }

        guard let maxFullyFinishedRound = byRound.filter({ round in
            round.matches.allSatisfy { $0.status == .finished }
        }).map(\.round).max() else {
            return byRound.first?.round
        }

        let nextRound = byRound.first { $0.round > maxFullyFinishedRound }
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
