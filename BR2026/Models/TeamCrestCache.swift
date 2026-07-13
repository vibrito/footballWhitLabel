import Foundation
import SwiftData

@Model
final class TeamCrestCache {
    @Attribute(.unique) var teamID: Int
    var crestURL: URL
    var imageData: Data
    var cachedAt: Date

    init(teamID: Int, crestURL: URL, imageData: Data, cachedAt: Date = Date()) {
        self.teamID = teamID
        self.crestURL = crestURL
        self.imageData = imageData
        self.cachedAt = cachedAt
    }
}
