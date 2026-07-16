enum MatchStatus: String, Codable {
    case scheduled = "SCHEDULED"
    case live = "LIVE"
    // Synthetic raw value — never actually sent by the API. The decoder below maps the
    // real backend's "PAUSED" to this case; the raw value only exists to satisfy
    // RawRepresentable and is never round-tripped.
    case halftime = "HALFTIME"
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
        // passes through a ~15-minute halftime window using this status, kept as its own
        // case (rather than collapsed into .live) so the UI can show "HT" distinctly instead
        // of a live minute counter that's actually stuck. Both .live and .halftime must
        // still count as "live" for detection/polling purposes — see isLiveOrHalftime.
        if raw == "IN_PLAY" {
            self = .live
            return
        }
        if raw == "PAUSED" {
            self = .halftime
            return
        }
        self = MatchStatus(rawValue: raw) ?? .scheduled
    }

    /// True for both `.live` and `.halftime` — the two statuses where a match is currently
    /// in progress and should count as "live" for detection/polling purposes, even though
    /// the UI displays them differently (a live minute counter vs. an "HT" indicator).
    var isLiveOrHalftime: Bool {
        self == .live || self == .halftime
    }
}
