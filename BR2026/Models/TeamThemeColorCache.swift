import Foundation
import SwiftData

@Model
final class TeamThemeColorCache {
    @Attribute(.unique) var teamID: Int
    var homeMainColorHex: String
    var homeFontColorHex: String
    // Optional: away/third aren't always present in the API response (e.g. Flamengo, team
    // id 127, returns `null` for both) — only home is guaranteed.
    var awayMainColorHex: String?
    var awayFontColorHex: String?
    var thirdMainColorHex: String?
    var thirdFontColorHex: String?
    var cachedAt: Date

    init(teamID: Int, colors: TeamThemeColorSet, cachedAt: Date = Date()) {
        self.teamID = teamID
        self.homeMainColorHex = colors.home.mainColorHex
        self.homeFontColorHex = colors.home.fontColorHex
        self.awayMainColorHex = colors.away?.mainColorHex
        self.awayFontColorHex = colors.away?.fontColorHex
        self.thirdMainColorHex = colors.third?.mainColorHex
        self.thirdFontColorHex = colors.third?.fontColorHex
        self.cachedAt = cachedAt
    }

    var colorSet: TeamThemeColorSet {
        let away: TeamThemeColors? = {
            guard let awayMainColorHex, let awayFontColorHex else { return nil }
            return TeamThemeColors(mainColorHex: awayMainColorHex, fontColorHex: awayFontColorHex)
        }()
        let third: TeamThemeColors? = {
            guard let thirdMainColorHex, let thirdFontColorHex else { return nil }
            return TeamThemeColors(mainColorHex: thirdMainColorHex, fontColorHex: thirdFontColorHex)
        }()
        return TeamThemeColorSet(
            home: TeamThemeColors(mainColorHex: homeMainColorHex, fontColorHex: homeFontColorHex),
            away: away,
            third: third
        )
    }
}
