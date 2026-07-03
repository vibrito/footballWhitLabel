import Foundation
import SwiftData

enum MatchServiceError: Error {
    case missingAPIKey
    case invalidResponse
}

// Confined to the main actor: `ModelContext` and the `Match` objects it fetches/inserts
// are not safe to touch from more than one thread. Without this, `fetchMatches()` could
// resume (after its `await` on the network call) on a background executor, mutating and
// fetching from the same ModelContext the main-actor UI is simultaneously reading —
// exactly the cross-thread SwiftData access that crashed FixtureMatchCard with a bad
// memory access reading `Match.awayTeam`.
@MainActor
final class LiveMatchService: MatchService {
    private let config: ChampionshipConfig
    private let apiKey: String
    private let urlSession: URLSession
    private let modelContext: ModelContext
    private let decoder: JSONDecoder

    init(config: ChampionshipConfig, apiKey: String, modelContext: ModelContext, urlSession: URLSession = .shared) {
        self.config = config
        self.apiKey = apiKey
        self.modelContext = modelContext
        self.urlSession = urlSession
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    static func makeFromBundle(config: ChampionshipConfig, modelContext: ModelContext) throws -> LiveMatchService {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "API_KEY") as? String,
              !apiKey.isEmpty, apiKey != "your-api-key-here" else {
            throw MatchServiceError.missingAPIKey
        }
        return LiveMatchService(config: config, apiKey: apiKey, modelContext: modelContext)
    }

    func fetchMatches() async throws -> [Match] {
        let url = config.apiBaseURL.appendingPathComponent("v4/competitions/\(config.competitionCode)/matches")
        let response: MatchesResponse = try await get(url)
        for dto in response.matches {
            upsert(dto)
        }
        try modelContext.save()
        let fetchedIDs = Set(response.matches.map(\.id))
        return try modelContext.fetch(FetchDescriptor<Match>()).filter { fetchedIDs.contains($0.id) }
    }

    func fetchStandings() async throws -> [Standing] {
        let url = config.apiBaseURL.appendingPathComponent("v4/competitions/\(config.competitionCode)/standings")
        let response: StandingsResponse = try await get(url)
        return response.standings
    }

    func fetchEvents(matchID: Int) async throws -> [MatchEvent] {
        let url = config.apiBaseURL
            .appendingPathComponent("v4/competitions/\(config.competitionCode)/matches/\(matchID)/events")
        let response: MatchEventsResponse = try await get(url)
        return response.events
    }

    private func upsert(_ dto: MatchDTO) {
        let targetID = dto.id
        let descriptor = FetchDescriptor<Match>(predicate: #Predicate { $0.id == targetID })
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.update(from: dto)
        } else {
            modelContext.insert(Match(dto: dto))
        }
    }

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Auth-Token")
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MatchServiceError.invalidResponse
        }
        return try decoder.decode(T.self, from: data)
    }
}
