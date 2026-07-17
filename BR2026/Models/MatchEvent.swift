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

    var accessibilityLabel: String {
        let minuteText = extraMinute.map { "\(minute)+\($0)" } ?? String(minute)
        let eventWord: String
        switch type {
        case .goal:
            switch detail {
            case "Penalty":
                eventWord = String(localized: "penalty goal", comment: "VoiceOver: match-event type word for a penalty goal.")
            case "Own Goal":
                eventWord = String(localized: "own goal", comment: "VoiceOver: match-event type word for an own goal.")
            default:
                eventWord = String(localized: "goal", comment: "VoiceOver: match-event type word for a standard goal.")
            }
        case .yellowCard:
            eventWord = String(localized: "yellow card", comment: "VoiceOver: match-event type word for a yellow card.")
        case .redCard:
            eventWord = String(localized: "red card", comment: "VoiceOver: match-event type word for a red card.")
        case .substitution:
            eventWord = String(localized: "substitution", comment: "VoiceOver: match-event type word for a substitution.")
        case .unknown:
            return String(
                localized: "\(minuteText) minute",
                comment: "VoiceOver label for a match event of an unrecognized type — only the minute is known. Argument: the minute (with stoppage time if any, e.g. \"45+2\")."
            )
        }
        let detailText: String
        if type == .substitution, let playerOut {
            detailText = String(
                localized: "\(player) for \(playerOut)",
                comment: "VoiceOver: describes a substitution as the incoming player for the outgoing player. Arguments: player coming on, player going off."
            )
        } else {
            detailText = player
        }
        return String(
            localized: "\(minuteText) minute, \(eventWord), \(detailText)",
            comment: "VoiceOver label for one match timeline event. Arguments: the minute, the event type word (goal/yellow card/etc.), and the player detail."
        )
    }
}

struct MatchEventsResponse: Decodable {
    let events: [MatchEvent]
}
