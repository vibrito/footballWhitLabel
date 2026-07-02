import Foundation

struct ChampionshipConfig {
    let id: String
    let displayName: String
    let competitionCode: String
    let accentColorHex: String
    let apiBaseURL: URL
}

extension ChampionshipConfig {
    static let brasileirao: ChampionshipConfig = {
        guard let url = URL(string: "https://football-api-production-16d9.up.railway.app") else {
            fatalError("Invalid Brasileirão API base URL literal")
        }
        return ChampionshipConfig(
            id: "brasileirao",
            displayName: "Brasileirão",
            competitionCode: "BSA",
            accentColorHex: "#ff4d5e",
            apiBaseURL: url
        )
    }()
}
