import Testing
import Foundation
import SwiftData
@testable import Championship26

// Deliberate, scoped exception to "no SwiftData container in unit tests": this is a
// regression test for a real crash (Team's custom CodingKeys conflicting with
// SwiftData's composite-attribute schema for the embedded homeTeam/awayTeam), which
// only reproduces with an actual ModelContainer round-trip. LiveMatchService's own
// persistence path was the one piece of the app never exercised by any test or smoke
// test, which is exactly how this shipped.
@Suite("Match SwiftData persistence")
struct MatchSwiftDataTests {
    @Test("Match with an embedded Team round-trips through a real SwiftData container")
    func persistsAndFetchesMatch() throws {
        let container = try ModelContainer(
            for: Match.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let team = Team(
            id: 121,
            name: "Palmeiras",
            shortName: "Palmeiras",
            crestURL: URL(string: "https://media.api-sports.io/football/teams/121.png")
        )
        let match = Match(
            id: 1, utcDate: Date(), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )

        context.insert(match)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Match>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.homeTeam.name == "Palmeiras")
        #expect(fetched.first?.homeTeam.crestURL?.absoluteString == "https://media.api-sports.io/football/teams/121.png")
    }
}
