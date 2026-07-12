import Foundation

struct CompetitionDTO: Decodable {
    let code: String
    let name: String
    let season: Int
    let logoURL: URL

    private enum CodingKeys: String, CodingKey {
        case code, name, season
        case logoURL = "logo"
    }
}
