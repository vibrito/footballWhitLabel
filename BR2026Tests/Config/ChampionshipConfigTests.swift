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
        #expect(config.tabSelectionColorHex == "#ff4d5e")
        #expect(config.apiBaseURL.absoluteString == "https://football-api-production-16d9.up.railway.app")
    }

    @Test("Premier League config has expected values")
    func premierLeagueDefaults() {
        let config = ChampionshipConfig.premierLeague
        #expect(config.id == "premier-league")
        #expect(config.competitionCode == "PL")
        #expect(config.displayName == "Premier League")
        #expect(config.accentColorHex == "#3D195B")
        #expect(config.tabSelectionColorHex == "#04f5ff")
        #expect(config.apiBaseURL.absoluteString == "https://football-api-production-16d9.up.railway.app")
    }

    @Test("Ligue 1 config has expected values")
    func ligue1Defaults() {
        let config = ChampionshipConfig.ligue1
        #expect(config.id == "ligue-1")
        #expect(config.competitionCode == "FL1")
        #expect(config.displayName == "Ligue 1")
        #expect(config.accentColorHex == "#FACC15")
        #expect(config.tabSelectionColorHex == "#FACC15")
        #expect(config.apiBaseURL.absoluteString == "https://football-api-production-16d9.up.railway.app")
    }

    @Test("Liga Portugal config has expected values")
    func primeiraLigaDefaults() {
        let config = ChampionshipConfig.primeiraLiga
        #expect(config.id == "primeira-liga")
        #expect(config.competitionCode == "PPL")
        #expect(config.displayName == "Liga Portugal")
        #expect(config.accentColorHex == "#00235A")
        #expect(config.tabSelectionColorHex == "#19FF91")
        #expect(config.apiBaseURL.absoluteString == "https://football-api-production-16d9.up.railway.app")
    }

    @Test("Scottish Premiership config has expected values")
    func scottishPremiershipDefaults() {
        let config = ChampionshipConfig.scottishPremiership
        #expect(config.id == "scottish-premiership")
        #expect(config.competitionCode == "SPL")
        #expect(config.displayName == "Scottish Premiership")
        #expect(config.accentColorHex == "#005EB8")
        #expect(config.tabSelectionColorHex == "#005EB8")
        #expect(config.apiBaseURL.absoluteString == "https://football-api-production-16d9.up.railway.app")
    }

    @Test("La Liga config has expected values")
    func laLigaDefaults() {
        let config = ChampionshipConfig.laLiga
        #expect(config.id == "la-liga")
        #expect(config.competitionCode == "PD")
        #expect(config.displayName == "La Liga")
        #expect(config.accentColorHex == "#AA151B")
        #expect(config.tabSelectionColorHex == "#F1BF00")
        #expect(config.apiBaseURL.absoluteString == "https://football-api-production-16d9.up.railway.app")
    }
}
