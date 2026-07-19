// BR2026Tests/Models/MatchStatisticsTests.swift
import Testing
import Foundation
@testable import BR2026

@Suite("MatchStatistics decoding")
struct MatchStatisticsTests {
    @Test("Decodes match statistics from real-shaped API JSON")
    func decodesStatistics() throws {
        // Real response for BSA match 1492291 (Botafogo vs Santos, round 19).
        let json = Data("""
        {
            "home": { "fouls": 10, "shots": 17, "corners": 5, "possession": 48, "passAccuracy": 81, "shotsOnTarget": 7 },
            "away": { "fouls": 13, "shots": 22, "corners": 5, "possession": 52, "passAccuracy": 79, "shotsOnTarget": 9 }
        }
        """.utf8)
        let stats = try JSONDecoder().decode(MatchStatistics.self, from: json)
        #expect(stats.home.fouls == 10)
        #expect(stats.home.possession == 48)
        #expect(stats.away.shotsOnTarget == 9)
    }
}
