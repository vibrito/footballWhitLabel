import Testing
@testable import BR2026

@Suite("ChampionshipConfig")
struct ChampionshipConfigTests {
    @Test("Brasileirão config has expected values")
    func brasileiraoDefaults() {
        let config = ChampionshipConfig.brasileirao
        #expect(config.id == "brasileirao")
        #expect(config.competitionCode == "BSA")
        #expect(config.displayName == "Brasileirão")
        #expect(config.accentColorHex == "#ff4d5e")
        #expect(config.apiBaseURL.absoluteString == "https://football-api-production-16d9.up.railway.app")
    }
}
