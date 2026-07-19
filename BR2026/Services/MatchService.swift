// Main-actor isolated: `Match` is a SwiftData reference type and is not Sendable, so it
// must never cross actor boundaries. Every conformance (and every caller — all three
// ViewModels are already @MainActor) stays on the main actor for the whole call.
@MainActor
protocol MatchService {
    func fetchMatches() async throws -> [Match]
    func fetchStandings() async throws -> [Standing]
    func fetchEvents(matchID: Int) async throws -> [MatchEvent]
    /// Returns match statistics, or nil if not yet available (e.g. the match hasn't
    /// started). Not cached — same transient, per-sheet-visit lifecycle as fetchEvents.
    func fetchMatchStatistics(matchID: Int) async throws -> MatchStatistics?
    /// Returns both teams' lineups, or nil if not yet published. Not cached — same
    /// transient, per-sheet-visit lifecycle as fetchEvents.
    func fetchMatchLineups(matchID: Int) async throws -> MatchLineup?
    func fetchCompetition() async throws -> Competition
    func fetchTeamThemeColorSet(teamID: Int) async throws -> TeamThemeColorSet
    func cachedMatches() -> [Match]
    func cachedStandings() -> [Standing]
    func cachedCompetition() -> Competition?
    func cachedTeamThemeColorSet(teamID: Int) -> TeamThemeColorSet?
}
