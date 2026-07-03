// Main-actor isolated: `Match` is a SwiftData reference type and is not Sendable, so it
// must never cross actor boundaries. Every conformance (and every caller — all three
// ViewModels are already @MainActor) stays on the main actor for the whole call.
@MainActor
protocol MatchService {
    func fetchMatches() async throws -> [Match]
    func fetchStandings() async throws -> [Standing]
    func fetchEvents(matchID: Int) async throws -> [MatchEvent]
}
