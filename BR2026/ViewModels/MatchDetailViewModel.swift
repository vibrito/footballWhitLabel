import Foundation
import Observation

@Observable
@MainActor
final class MatchDetailViewModel {
    let match: Match
    private(set) var events: [MatchEvent] = []
    private(set) var isLoading = false
    private nonisolated(unsafe) let service: MatchService

    init(match: Match, service: MatchService) {
        self.match = match
        self.service = service
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        events = (try? await service.fetchEvents(matchID: match.id)) ?? []
    }

    var isLive: Bool {
        match.status == .live
    }

    func pollWhileLive() async {
        await LivePoller.run(interval: .seconds(30), shouldContinue: { isLive }, action: { await load() })
    }
}
