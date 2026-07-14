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
    let away: TeamThemeColors
    let third: TeamThemeColors

    subscript(kit: TeamKit) -> TeamThemeColors {
        switch kit {
        case .home: home
        case .away: away
        case .third: third
        }
    }
}

struct TeamThemeColorsResponse: Decodable {
    let home: KitColorsDTO
    let away: KitColorsDTO
    let third: KitColorsDTO

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
        self.init(home: colors(response.home), away: colors(response.away), third: colors(response.third))
    }
}
