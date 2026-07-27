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

    /// Injectable so the hold window can be tested without waiting for real time to pass.
    var now: () -> Date = Date.init

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

    /// How long a finished match stays on the board after kickoff.
    ///
    /// Measured from kickoff rather than the final whistle because the API reports no end
    /// time, and a fixed offset from a known instant beats guessing at stoppage.
    nonisolated static let holdWindow: TimeInterval = 24 * 60 * 60

    /// The rule shared with the marketing site and the Fixture 2026 app. A match belongs
    /// on the board when *any* of these hold:
    ///
    /// 1. it falls on the featured match's calendar day — the day being shown;
    /// 2. it is being played right now, whatever day it started on;
    /// 3. it kicked off within the last `holdWindow`.
    ///
    /// (2) and (3) are the two failures a day-only filter has, both found on the site.
    /// A 21:30 UTC kickoff is still the 25th in São Paulo but already the 26th in Lisbon,
    /// so a European reader watched live matches vanish mid-first-half; and last night's
    /// results disappeared at local midnight, leaving only upcoming fixtures for anyone
    /// opening the app over breakfast.
    var otherMatchesForNextMatchDay: [Match] {
        guard let nextMatch else { return [] }
        let calendar = Calendar.current
        let now = now()
        return matches
            .filter { match in
                guard match.id != nextMatch.id else { return false }
                // A postponed match is not being played on the day it still claims, so it
                // is noise on a board about today. Excluded here rather than per section,
                // so it cannot reappear in one of them later.
                guard match.status != .postponed else { return false }
                if calendar.isDate(match.utcDate, inSameDayAs: nextMatch.utcDate) { return true }
                if match.status.isLiveOrHalftime { return true }
                let since = now.timeIntervalSince(match.utcDate)
                return since >= 0 && since <= Self.holdWindow
            }
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

    /// Listings for the loaded matches, keyed by match id, unfiltered by country.
    ///
    /// Empty on a cold launch until the refresh lands: they are not persisted with the
    /// matches, so cached cards appear first and their chips a moment later. See `Broadcast`.
    private(set) var broadcasts: [Int: [Broadcast]] = [:]

    /// Every country the loaded listings cover — what the settings picker is built from.
    var broadcastCountries: [String] {
        Array(Set(broadcasts.values.flatMap { $0 }.map(\.country))).sorted()
    }

    func load() async {
        matches = service.cachedMatches()
        isRefreshing = true
        defer { isRefreshing = false }
        if let fresh = try? await service.fetchMatches() {
            announceChanges(from: matches, to: fresh)
            matches = fresh
            broadcasts = service.latestBroadcasts()
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
