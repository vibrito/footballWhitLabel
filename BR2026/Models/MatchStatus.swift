enum MatchStatus: String, Codable {
    case scheduled = "SCHEDULED"
    case live = "LIVE"
    case finished = "FINISHED"
    case postponed = "POSTPONED"

    init(from decoder: Decoder) throws {
        // The API may add new status values over time; default to `.scheduled` rather
        // than crash the whole decode for a status this app doesn't know about yet.
        let raw = try decoder.singleValueContainer().decode(String.self)
        // The live backend actually sends "IN_PLAY" for a live match (a football-data.org
        // convention), never the literal "LIVE" this enum's rawValue expects — confirmed
        // against the real API 2026-07-16. Without this, every live match silently decoded
        // as .scheduled.
        if raw == "IN_PLAY" {
            self = .live
            return
        }
        self = MatchStatus(rawValue: raw) ?? .scheduled
    }
}
