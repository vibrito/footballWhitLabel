import Foundation
import Observation

@Observable
@MainActor
final class StandingsViewModel {
    private(set) var standings: [Standing] = []
    private(set) var isRefreshing = false
    private var hasLoadedOnce = false
    private nonisolated(unsafe) let service: MatchService

    init(service: MatchService) {
        self.service = service
    }

    // `.task` on the view restarts every time the tab reappears, not just on first
    // launch. Calling `load()` unconditionally there — on top of `.refreshable` also
    // being attached to the same ScrollView — caused a visible content jump on every
    // tab revisit: the pull-to-refresh control's layout negotiation collides with the
    // `isRefreshing`/`standings` state changes `load()` makes mid-reappear. Auto-loading
    // only once keeps the cached-then-refresh behavior on first launch while leaving
    // later refreshes to the explicit `.refreshable` pull gesture, which isn't racing
    // against a reappear transition.
    func loadOnce() async {
        guard !hasLoadedOnce else { return }
        hasLoadedOnce = true
        await load()
    }

    func load() async {
        standings = service.cachedStandings().sorted { $0.position < $1.position }
        isRefreshing = true
        defer { isRefreshing = false }
        if let fresh = try? await service.fetchStandings() {
            standings = fresh.sorted { $0.position < $1.position }
        }
    }
}
