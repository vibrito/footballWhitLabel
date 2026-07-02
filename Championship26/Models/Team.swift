import Foundation

// Team is embedded directly inside the SwiftData `Match` model (as a composite
// attribute), which requires its Codable encoding to match its stored property names
// exactly — a custom CodingKeys remap (as this type used to have, `crestURL` -> "crest")
// crashes SwiftData's schema reflection at runtime. JSON decoding from the live API
// (whose field really is named "crest") goes through TeamDTO instead, and gets mapped
// into this plain, SwiftData-safe Team via `init(dto:)`.
struct Team: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let shortName: String?
    let crestURL: URL?

    init(id: Int, name: String, shortName: String?, crestURL: URL?) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.crestURL = crestURL
    }

    init(dto: TeamDTO) {
        self.init(id: dto.id, name: dto.name, shortName: dto.shortName, crestURL: dto.crest)
    }
}

struct TeamDTO: Decodable {
    let id: Int
    let name: String
    let shortName: String?
    let crest: URL?
}
