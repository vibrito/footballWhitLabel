import Foundation
import SwiftData

@Model
final class TeamThemeColorCache {
    @Attribute(.unique) var teamID: Int
    var homeMainColorHex: String
    var homeFontColorHex: String
    var awayMainColorHex: String
    var awayFontColorHex: String
    var thirdMainColorHex: String
    var thirdFontColorHex: String
    var cachedAt: Date

    init(teamID: Int, colors: TeamThemeColorSet, cachedAt: Date = Date()) {
        self.teamID = teamID
        self.homeMainColorHex = colors.home.mainColorHex
        self.homeFontColorHex = colors.home.fontColorHex
        self.awayMainColorHex = colors.away.mainColorHex
        self.awayFontColorHex = colors.away.fontColorHex
        self.thirdMainColorHex = colors.third.mainColorHex
        self.thirdFontColorHex = colors.third.fontColorHex
        self.cachedAt = cachedAt
    }

    var colorSet: TeamThemeColorSet {
        TeamThemeColorSet(
            home: TeamThemeColors(mainColorHex: homeMainColorHex, fontColorHex: homeFontColorHex),
            away: TeamThemeColors(mainColorHex: awayMainColorHex, fontColorHex: awayFontColorHex),
            third: TeamThemeColors(mainColorHex: thirdMainColorHex, fontColorHex: thirdFontColorHex)
        )
    }
}
