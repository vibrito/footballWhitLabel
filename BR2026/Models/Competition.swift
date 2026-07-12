import Foundation
import SwiftData

@Model
final class Competition {
    @Attribute(.unique) var code: String
    var name: String
    var season: Int
    var logoURL: URL
    var logoData: Data?
    var cachedAt: Date

    init(
        code: String,
        name: String,
        season: Int,
        logoURL: URL,
        logoData: Data? = nil,
        cachedAt: Date = Date()
    ) {
        self.code = code
        self.name = name
        self.season = season
        self.logoURL = logoURL
        self.logoData = logoData
        self.cachedAt = cachedAt
    }

    convenience init(dto: CompetitionDTO, logoData: Data? = nil) {
        self.init(
            code: dto.code,
            name: dto.name,
            season: dto.season,
            logoURL: dto.logoURL,
            logoData: logoData
        )
    }
}
