import Foundation

/// Represents one sibling white-label app for cross-app linking (item #6 of the
/// multi-championship expansion). Not yet wired into any View — see
/// `docs/superpowers/specs/2026-07-13-multi-championship-expansion-design.md`.
struct CrossAppLink: Identifiable, Equatable {
    let id: String
    let displayName: String
    let accentColorHex: String
    let urlScheme: String
    /// Placeholder until each app's real App Store Connect app record exists.
    let appStoreID: String

    var customSchemeURL: URL {
        URL(string: "\(urlScheme)://")!
    }

    var appStoreURL: URL {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)")!
    }
}

extension CrossAppLink {
    static let brasileirao = CrossAppLink(
        id: "brasileirao",
        displayName: "Brasileirão",
        accentColorHex: "#ff4d5e",
        urlScheme: "br2026",
        appStoreID: "0000000000"
    )

    static let premierLeague = CrossAppLink(
        id: "premier-league",
        displayName: "Premier League",
        accentColorHex: "#3D195B",
        urlScheme: "premierleague2026",
        appStoreID: "0000000000"
    )

    static let ligue1 = CrossAppLink(
        id: "ligue-1",
        displayName: "Ligue 1",
        accentColorHex: "#FACC15",
        urlScheme: "ligue12026",
        appStoreID: "0000000000"
    )

    static let primeiraLiga = CrossAppLink(
        id: "primeira-liga",
        displayName: "Liga Portugal",
        accentColorHex: "#00235A",
        urlScheme: "primeiraliga2026",
        appStoreID: "0000000000"
    )

    static let scottishPremiership = CrossAppLink(
        id: "scottish-premiership",
        displayName: "Scottish Premiership",
        accentColorHex: "#005EB8",
        urlScheme: "scottishpremiership2026",
        appStoreID: "0000000000"
    )

    static let laLiga = CrossAppLink(
        id: "la-liga",
        displayName: "La Liga",
        accentColorHex: "#AA151B",
        urlScheme: "laliga2026",
        appStoreID: "0000000000"
    )

    static let all: [CrossAppLink] = [brasileirao, premierLeague, ligue1, primeiraLiga, scottishPremiership, laLiga]

    /// All sibling apps except the one currently running, matched by `ChampionshipConfig.id`.
    static func siblings(excluding currentID: String) -> [CrossAppLink] {
        all.filter { $0.id != currentID }
    }
}
