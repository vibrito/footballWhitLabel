import Foundation

enum TeamKit: String, Codable, CaseIterable {
    case home, away, third
}

struct TeamThemeColors: Codable, Equatable {
    let mainColorHex: String
    let fontColorHex: String
}

struct TeamThemeColorSet: Codable, Equatable {
    let home: TeamThemeColors
    // Optional: the live API returns `null` for away/third for some teams (e.g. Flamengo,
    // team id 127) — only `home` is guaranteed present.
    let away: TeamThemeColors?
    let third: TeamThemeColors?

    init(home: TeamThemeColors, away: TeamThemeColors? = nil, third: TeamThemeColors? = nil) {
        self.home = home
        self.away = away
        self.third = third
    }

    subscript(kit: TeamKit) -> TeamThemeColors? {
        switch kit {
        case .home: home
        case .away: away
        case .third: third
        }
    }
}

struct TeamThemeColorsResponse: Decodable {
    let home: KitColorsDTO
    let away: KitColorsDTO?
    let third: KitColorsDTO?

    struct KitColorsDTO: Decodable {
        let fontColor: String
        let mainColor: String
    }
}

extension TeamThemeColorSet {
    init(response: TeamThemeColorsResponse) {
        func colors(_ dto: TeamThemeColorsResponse.KitColorsDTO) -> TeamThemeColors {
            TeamThemeColors(mainColorHex: dto.mainColor, fontColorHex: dto.fontColor)
        }
        self.init(
            home: colors(response.home),
            away: response.away.map(colors),
            third: response.third.map(colors)
        )
    }
}
