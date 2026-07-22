import Foundation

struct ChampionshipConfig {
    let id: String
    let displayName: String
    let competitionCode: String
    let accentColorHex: String
    let tabSelectionColorHex: String
    let apiBaseURL: URL
    /// Name of the bundled national-flag image (in `Assets.xcassets`) shown as a
    /// World-Cup-style roundel in place of the competition logo on the More screen — the
    /// league's country. `nil` falls back to a generic soccerball.
    let flagAssetName: String?
}

extension ChampionshipConfig {
    private static let sharedAPIBaseURL: URL = {
        guard let url = URL(string: "https://football-api-production-16d9.up.railway.app") else {
            fatalError("Invalid shared API base URL literal")
        }
        return url
    }()

    static let brasileirao = ChampionshipConfig(
        id: "brasileirao",
        displayName: "Brasileirão",
        competitionCode: "BSA",
        accentColorHex: "#ff4d5e",
        tabSelectionColorHex: "#ff4d5e",
        apiBaseURL: sharedAPIBaseURL,
        flagAssetName: "Flag-Brazil"
    )

    static let premierLeague = ChampionshipConfig(
        id: "premier-league",
        displayName: "Premier League",
        competitionCode: "PL",
        accentColorHex: "#3D195B",
        // The brand purple is nearly invisible against the dark tab bar background,
        // so the selected tab item uses a bright cyan instead while other accent-colored
        // UI (live chips, pills) keeps the true brand color.
        tabSelectionColorHex: "#04f5ff",
        apiBaseURL: sharedAPIBaseURL,
        flagAssetName: "Flag-England"
    )

    static let ligue1 = ChampionshipConfig(
        id: "ligue-1",
        displayName: "Ligue 1",
        competitionCode: "FL1",
        accentColorHex: "#FACC15",
        tabSelectionColorHex: "#FACC15",
        apiBaseURL: sharedAPIBaseURL,
        flagAssetName: "Flag-France"
    )

    static let primeiraLiga = ChampionshipConfig(
        id: "primeira-liga",
        displayName: "Liga Portugal",
        competitionCode: "PPL",
        accentColorHex: "#00235A",
        // The brand navy is nearly invisible against the dark tab bar background,
        // so the selected tab item uses a bright green instead while other accent-colored
        // UI (live chips, pills) keeps the true brand color.
        tabSelectionColorHex: "#19FF91",
        apiBaseURL: sharedAPIBaseURL,
        flagAssetName: "Flag-Portugal"
    )

    static let scottishPremiership = ChampionshipConfig(
        id: "scottish-premiership",
        displayName: "Scottish Premiership",
        competitionCode: "SPL",
        accentColorHex: "#005EB8",
        tabSelectionColorHex: "#005EB8",
        apiBaseURL: sharedAPIBaseURL,
        flagAssetName: "Flag-Scotland"
    )

    static let laLiga = ChampionshipConfig(
        id: "la-liga",
        displayName: "La Liga",
        competitionCode: "PD",
        accentColorHex: "#AA151B",
        tabSelectionColorHex: "#F1BF00",
        apiBaseURL: sharedAPIBaseURL,
        flagAssetName: "Flag-Spain"
    )
}
