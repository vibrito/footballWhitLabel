enum MatchStatus: String, Codable {
    case scheduled = "SCHEDULED"
    case live = "LIVE"
    case finished = "FINISHED"
    case postponed = "POSTPONED"

    init(from decoder: Decoder) throws {
        // The API may add new status values over time; default to `.scheduled` rather
        // than crash the whole decode for a status this app doesn't know about yet.
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = MatchStatus(rawValue: raw) ?? .scheduled
    }
}
