// BR2026/Models/MatchLineupDTO.swift
import Foundation

struct LineupColorsDTO: Decodable {
    let fontColor: String
    let mainColor: String
    let secondaryColor: String
}

struct TeamLineupDTO: Decodable {
    // Optional: a scheduled match's lineups response returns `"colors": null` (confirmed
    // directly against the live backend) alongside an empty formation/startingXI — there's
    // no real kit to report yet. `MatchLineup.map(_:)` supplies a neutral fallback when nil.
    let colors: LineupColorsDTO?
    let formation: String
    let startingXI: [LineupPlayer]
    let substitutes: [LineupPlayer]
}

struct MatchLineupDTO: Decodable {
    let home: TeamLineupDTO
    let away: TeamLineupDTO
}
