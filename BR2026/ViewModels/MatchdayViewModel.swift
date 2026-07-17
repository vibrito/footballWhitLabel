import Foundation
import Observation
import UIKit

@Observable
@MainActor
final class MatchdayViewModel {
    private(set) var matches: [Match] = []
    private(set) var isRefreshing = false
    private var hasLoadedOnce = false
    private nonisolated(unsafe) let service: MatchService
    private let themeStore: TeamThemeStore

    init(service: MatchService, themeStore: TeamThemeStore) {
        self.service = service
        self.themeStore = themeStore
    }

    // The featured match is the selected Team Theme's own next match, but only when it's
    // happening today — the personalization is only worth surfacing when it's actually
    // relevant to what the user would see on screen right now, not a match weeks away
    // displacing something happening today for other teams. With no team selected (or
    // that team has no live/scheduled match today), this falls back to the league-wide
    // earliest one still to be decided — a match already live sorts before any future
    // kickoff there too, so it naturally wins over a later scheduled match without
    // special-casing status.
    var nextMatch: Match? {
        if let teamID = themeStore.selectedOption?.teamID {
            let teamMatch = matches
                .filter { ($0.homeTeam.id == teamID || $0.awayTeam.id == teamID) && ($0.status.isLiveOrHalftime || $0.status == .scheduled) }
                .min { $0.utcDate < $1.utcDate }
            if let teamMatch, Calendar.current.isDateInToday(teamMatch.utcDate) {
                return teamMatch
            }
        }
        return matches
            .filter { $0.status.isLiveOrHalftime || $0.status == .scheduled }
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
        isRefreshing = true
        defer { isRefreshing = false }
        if let fresh = try? await service.fetchMatches() {
            announceChanges(from: matches, to: fresh)
            matches = fresh
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

    // Distinguishes "first activation" (cache-then-refresh-once, matching loadOnce()'s
    // existing semantics) from "returning from background" (always refetch) — see the
    // design doc for why this can't just be two independent .task modifiers.
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
}
