import Foundation

struct Team: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let shortName: String?
    let crestURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, name, shortName
        case crestURL = "crest"
    }
}
