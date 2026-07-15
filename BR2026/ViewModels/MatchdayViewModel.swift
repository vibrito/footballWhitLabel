import Foundation
import Observation

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

    // The featured match is the selected Team Theme's own next match, if one exists —
    // this is a personalized "your team" card, so a match live elsewhere never displaces
    // it, and how far out it is doesn't matter as long as the season has one left. With
    // no team selected (or that team has no live/scheduled match), this falls back to the
    // league-wide earliest one still to be decided — a match already live sorts before any
    // future kickoff there too, so it naturally wins over a later scheduled match without
    // special-casing status.
    var nextMatch: Match? {
        if let teamID = themeStore.selectedOption?.teamID {
            let teamMatch = matches
                .filter { ($0.homeTeam.id == teamID || $0.awayTeam.id == teamID) && ($0.status == .live || $0.status == .scheduled) }
                .min { $0.utcDate < $1.utcDate }
            if let teamMatch { return teamMatch }
        }
        return matches
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
            matches = fresh
        }
    }
}
