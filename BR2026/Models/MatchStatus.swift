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
        // as .scheduled. The same backend also sends "PAUSED" during halftime — every match
        // passes through a ~15-minute halftime window using this status. Both "IN_PLAY" and
        // "PAUSED" are backend-sent live-family statuses that must count as .live for this
        // app's purposes (live-detection, polling, live-chip display) — otherwise halftime
        // would stop live-polling and show the match as upcoming with its original kickoff time.
        if raw == "IN_PLAY" || raw == "PAUSED" {
            self = .live
            return
        }
        self = MatchStatus(rawValue: raw) ?? .scheduled
    }
}
