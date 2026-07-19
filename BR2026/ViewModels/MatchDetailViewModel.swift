import Foundation
import Observation

enum MatchDetailSegment: CaseIterable {
    case timeline
    case stats
    case lineups
}

@Observable
@MainActor
final class MatchDetailViewModel {
    let match: Match
    private(set) var events: [MatchEvent] = []
    private(set) var statistics: MatchStatistics?
    private(set) var lineups: MatchLineup?
    private(set) var isLoading = false
    var selectedSegment: MatchDetailSegment = .timeline
    private var hasLoadedStatistics = false
    private var hasLoadedLineups = false
    private nonisolated(unsafe) let service: MatchService

    init(match: Match, service: MatchService) {
        self.match = match
        self.service = service
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        if let fresh = try? await service.fetchEvents(matchID: match.id) {
            events = fresh
        }
    }

    var isLive: Bool {
        match.status.isLiveOrHalftime
    }

    func pollWhileLive() async {
        await LivePoller.run(interval: .seconds(30), shouldContinue: { isLive }, action: { await load() })
    }

    // Guarded the same way selectRoundIfNeeded() guards FixturesViewModel's round
    // auto-selection — the segmented control's onChange fires every time the user taps a
    // tab, including tapping back to one already loaded, but the fetch itself should only
    // ever happen once per sheet visit.
    func loadStatisticsIfNeeded() async {
        guard !hasLoadedStatistics else { return }
        hasLoadedStatistics = true
        statistics = try? await service.fetchMatchStatistics(matchID: match.id)
    }

    func loadLineupsIfNeeded() async {
        guard !hasLoadedLineups else { return }
        hasLoadedLineups = true
        lineups = try? await service.fetchMatchLineups(matchID: match.id)
    }
}
