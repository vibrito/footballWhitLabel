import Foundation

struct MatchesResponse: Decodable {
    let matches: [MatchDTO]
}

struct StandingsResponse: Decodable {
    let standings: [Standing]
}

final class MockMatchService: MatchService {
    private let matches: [Match]
    private let standings: [Standing]

    init() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let matchesData = Data(MockDataProvider.matchesJSON.utf8)
        let standingsData = Data(MockDataProvider.standingsJSON.utf8)
        let matchResponse = try? decoder.decode(MatchesResponse.self, from: matchesData)
        let standingsResponse = try? decoder.decode(StandingsResponse.self, from: standingsData)
        self.matches = (matchResponse?.matches ?? []).map(Match.init(dto:))
        self.standings = standingsResponse?.standings ?? []
    }

    func fetchMatches() async throws -> [Match] { matches }
    func fetchStandings() async throws -> [Standing] { standings }
}
