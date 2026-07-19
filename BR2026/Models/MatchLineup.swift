// BR2026/Models/MatchLineup.swift
import Foundation

/// A single player in a lineup. Used directly as the `Decodable` target for both
/// `startingXI` (which has `col`/`row`) and `substitutes` (which doesn't) — Swift's
/// synthesized `Decodable` conformance already decodes an `Optional` property as `nil`
/// when its key is absent, so one type covers both API shapes with no separate DTO.
struct LineupPlayer: Decodable, Equatable {
    let name: String
    let number: Int
    let position: String   // "G" / "D" / "M" / "F"
    let col: Int?           // nil for substitutes
    let row: Int?           // nil for substitutes

    /// The API's bare position letter, spelled out for VoiceOver — mirrors
    /// `Standing.zoneAccessibilityLabel`'s pattern of never speaking a raw abbreviation.
    var positionAccessibilityLabel: String {
        switch position {
        case "G": String(localized: "Goalkeeper", comment: "VoiceOver: full word for a lineup player's position, abbreviated \"G\" by the API.")
        case "D": String(localized: "Defender", comment: "VoiceOver: full word for a lineup player's position, abbreviated \"D\" by the API.")
        case "M": String(localized: "Midfielder", comment: "VoiceOver: full word for a lineup player's position, abbreviated \"M\" by the API.")
        case "F": String(localized: "Forward", comment: "VoiceOver: full word for a lineup player's position, abbreviated \"F\" by the API.")
        default: position
        }
    }
}

/// One team's lineup. `kitColorHex`/`kitFontColorHex` are this specific match's actual
/// kit colors (distinct from `TeamThemeColorSet`'s generic per-team brand colors) — real,
/// live, per-match values that sometimes need correcting (see `MatchLineup.init(dto:)`).
struct TeamLineup {
    let formation: String
    let startingXI: [LineupPlayer]
    let substitutes: [LineupPlayer]
    let kitColorHex: String
    let kitFontColorHex: String
}

struct MatchLineup {
    let home: TeamLineup
    let away: TeamLineup

    init(dto: MatchLineupDTO) {
        home = Self.map(dto.home)
        away = Self.map(dto.away)
    }

    /// Real per-match kit colors sometimes fail to contrast with each other (confirmed
    /// directly against the live API: Botafogo's lineup response gave `fontColor: ffffff`
    /// against `mainColor: f7f7f7`, near-white on near-white) — corrected via the same
    /// "validate the real value, fall back to black/white only on failure" pattern already
    /// established for Team Theme colors (`ThemeTokens.accessibleFontColorHex`), not a
    /// per-team curated override table (which wouldn't exist for the other 5 leagues).
    /// `dto.colors` is nil for a scheduled match's still-empty lineup (see
    /// `TeamLineupDTO`'s doc comment) — `startingXI` is empty in that case too, so no
    /// jersey ever actually renders with the neutral gray/white fallback; the fallback
    /// only needs to be a valid, non-crashing pair of hex strings, not a meaningful color.
    private static func map(_ dto: TeamLineupDTO) -> TeamLineup {
        let mainColorHex = dto.colors?.mainColor ?? "808080"
        let fontColorHex = dto.colors?.fontColor ?? "FFFFFF"
        return TeamLineup(
            formation: dto.formation,
            startingXI: dto.startingXI,
            substitutes: dto.substitutes,
            kitColorHex: mainColorHex,
            kitFontColorHex: WCAGContrast.accessibleColorHex(candidateHex: fontColorHex, against: mainColorHex)
        )
    }
}
