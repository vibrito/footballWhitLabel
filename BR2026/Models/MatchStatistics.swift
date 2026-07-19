// BR2026/Models/MatchStatistics.swift
import Foundation

/// Per-team match statistics. Fetched once per match-detail Stats tab selection — not
/// persisted, and not partially updated like `Match` (mirrors `MatchEvent`'s lifecycle:
/// no SwiftData caching, no DTO layer needed since every field decodes directly with no
/// computation required).
struct TeamStats: Decodable {
    let fouls: Int
    let shots: Int
    let corners: Int
    let possession: Int
    let passAccuracy: Int
    let shotsOnTarget: Int

    /// The API always returns HTTP 200 with this shape, even for a match that hasn't
    /// started yet — as a block of zeros, never an omitted/null response (confirmed
    /// directly against the live backend: `GET .../matches/{scheduled-match-id}/statistics`
    /// returns `{"fouls":0,"shots":0,...}` for both teams, not 404 or an empty body).
    /// `LiveMatchService.fetchMatchStatistics` uses this to decide when to surface `nil`
    /// ("not yet available") instead of a real-but-empty `MatchStatistics`.
    var hasAnyValue: Bool {
        fouls != 0 || shots != 0 || corners != 0 || possession != 0 || passAccuracy != 0 || shotsOnTarget != 0
    }
}

struct MatchStatistics: Decodable {
    let home: TeamStats
    let away: TeamStats
}
