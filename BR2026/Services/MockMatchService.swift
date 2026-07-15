import Foundation

struct MatchesResponse: Decodable {
    let matches: [MatchDTO]
}

struct StandingsResponse: Decodable {
    let standings: [StandingDTO]
}

final class MockMatchService: MatchService {
    private let matches: [Match]
    private let standings: [Standing]
    private let events: [MatchEvent]
    private let competition: Competition?
    // Keyed by team id (the live API's own identifier) — mirrors the real /colors endpoint's
    // per-team shape, which only guarantees `home` (away/third are `null` for some teams,
    // e.g. Flamengo).
    private static let teamThemeColorSets: [Int: TeamThemeColorSet] = [
        121: TeamThemeColorSet(home: TeamThemeColors(mainColorHex: "225638", fontColorHex: "ffffff")),
        127: TeamThemeColorSet(home: TeamThemeColors(mainColorHex: "ab1b10", fontColorHex: "ffffff"))
    ]

    init() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let matchesData = Data(MockDataProvider.matchesJSON.utf8)
        let standingsData = Data(MockDataProvider.standingsJSON.utf8)
        let eventsData = Data(MockDataProvider.eventsJSON.utf8)
        let competitionData = Data(MockDataProvider.competitionJSON.utf8)
        let matchResponse = try? decoder.decode(MatchesResponse.self, from: matchesData)
        let standingsResponse = try? decoder.decode(StandingsResponse.self, from: standingsData)
        let eventsResponse = try? decoder.decode(MatchEventsResponse.self, from: eventsData)
        self.matches = (matchResponse?.matches ?? []).map(Match.init(dto:))
        self.standings = (standingsResponse?.standings ?? []).map(Standing.init(dto:))
        self.events = eventsResponse?.events ?? []
        let competitionDTO = try? decoder.decode(CompetitionDTO.self, from: competitionData)
        self.competition = competitionDTO.map { Competition(dto: $0) }
    }

    func fetchMatches() async throws -> [Match] { matches }
    func fetchStandings() async throws -> [Standing] { standings }
    func fetchEvents(matchID: Int) async throws -> [MatchEvent] { events }

    func fetchCompetition() async throws -> Competition {
        guard let competition else { throw MatchServiceError.invalidResponse }
        return competition
    }

    func fetchTeamThemeColorSet(teamID: Int) async throws -> TeamThemeColorSet {
        guard let colorSet = Self.teamThemeColorSets[teamID] else { throw MatchServiceError.invalidResponse }
        return colorSet
    }

    func cachedMatches() -> [Match] { matches }
    func cachedStandings() -> [Standing] { standings }
    func cachedCompetition() -> Competition? { competition }
    func cachedTeamThemeColorSet(teamID: Int) -> TeamThemeColorSet? { Self.teamThemeColorSets[teamID] }
}
