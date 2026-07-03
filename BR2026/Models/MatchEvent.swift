import Foundation

enum MatchEventTeam: String, Decodable {
    case home
    case away
}

enum MatchEventType: String, Decodable {
    case goal = "GOAL"
    case yellowCard = "YELLOW_CARD"
    case redCard = "RED_CARD"
    case substitution = "SUBSTITUTION"
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = MatchEventType(rawValue: raw) ?? .unknown
    }
}

/// A single timeline entry (goal, card, substitution) for a match. Fetched once per
/// match-detail view — not persisted, and not partially updated like `Match`.
struct MatchEvent: Decodable, Identifiable {
    let team: MatchEventTeam
    let type: MatchEventType
    let assist: String?
    let detail: String
    let minute: Int
    let player: String
    let playerOut: String?
    let extraMinute: Int?

    var id: String {
        "\(team.rawValue)-\(minute)-\(extraMinute ?? 0)-\(player)-\(type.rawValue)"
    }
}

struct MatchEventsResponse: Decodable {
    let events: [MatchEvent]
}
