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
        127: TeamThemeColorSet(home: TeamThemeColors(mainColorHex: "ab1b10", fontColorHex: "ffffff")),
        124: TeamThemeColorSet(home: TeamThemeColors(mainColorHex: "6e202e", fontColorHex: "ffffff")),
        134: TeamThemeColorSet(home: TeamThemeColors(mainColorHex: "cc0000", fontColorHex: "6c6360")),
        118: TeamThemeColorSet(home: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "043a73")),
        794: TeamThemeColorSet(home: TeamThemeColors(mainColorHex: "fcfcfc", fontColorHex: "f50000")),
        147: TeamThemeColorSet(home: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "000000")),
        126: TeamThemeColorSet(home: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "000000")),
        1062: TeamThemeColorSet(home: TeamThemeColors(mainColorHex: "000000", fontColorHex: "ffffff")),
        131: TeamThemeColorSet(home: TeamThemeColors(mainColorHex: "fcfbee", fontColorHex: "000000")),
        135: TeamThemeColorSet(home: TeamThemeColors(mainColorHex: "0455a3", fontColorHex: "ffffff")),
        119: TeamThemeColorSet(home: TeamThemeColors(mainColorHex: "e00618", fontColorHex: "ffffff")),
        1198: TeamThemeColorSet(home: TeamThemeColors(mainColorHex: "000000", fontColorHex: "ffffff")),
        120: TeamThemeColorSet(home: TeamThemeColors(mainColorHex: "f7f7f7", fontColorHex: "ffffff")),
        136: TeamThemeColorSet(home: TeamThemeColors(mainColorHex: "ff0000", fontColorHex: "ffffff")),
        7848: TeamThemeColorSet(home: TeamThemeColors(mainColorHex: "ffff00", fontColorHex: "076450")),
        132: TeamThemeColorSet(home: TeamThemeColors(mainColorHex: "f9fbfa", fontColorHex: "ffffff")),
        128: TeamThemeColorSet(home: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "000000")),
        130: TeamThemeColorSet(home: TeamThemeColors(mainColorHex: "b8edff", fontColorHex: "ffffff")),
        133: TeamThemeColorSet(home: TeamThemeColors(mainColorHex: "000000", fontColorHex: "ffffff"))
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
