import Foundation
import SwiftData

@Model
final class Standing: Identifiable {
    @Attribute(.unique) var teamID: Int
    var position: Int
    var team: Team
    var playedGames: Int
    var won: Int
    var draw: Int
    var lost: Int
    var goalsFor: Int
    var goalsAgainst: Int
    var goalDifference: Int
    var points: Int
    var zoneDescription: String?

    var id: Int { teamID }

    init(
        position: Int,
        team: Team,
        playedGames: Int,
        won: Int,
        draw: Int,
        lost: Int,
        goalsFor: Int,
        goalsAgainst: Int,
        goalDifference: Int,
        points: Int,
        zoneDescription: String? = nil
    ) {
        self.teamID = team.id
        self.position = position
        self.team = team
        self.playedGames = playedGames
        self.won = won
        self.draw = draw
        self.lost = lost
        self.goalsFor = goalsFor
        self.goalsAgainst = goalsAgainst
        self.goalDifference = goalDifference
        self.points = points
        self.zoneDescription = zoneDescription
    }

    convenience init(dto: StandingDTO) {
        self.init(
            position: dto.position,
            team: Team(dto: dto.team),
            playedGames: dto.playedGames,
            won: dto.won,
            draw: dto.draw,
            lost: dto.lost,
            goalsFor: dto.goalsFor,
            goalsAgainst: dto.goalsAgainst,
            goalDifference: dto.goalDifference,
            points: dto.points,
            zoneDescription: dto.description
        )
    }

    /// Which zone (if any) this standings position falls into, classified from the raw API
    /// `description` text by keyword — see the plan's Global Constraints for the exact rule.
    /// Never derived from a per-competition position-range table (e.g. "bottom 4 teams") —
    /// those rules vary by competition/season and the API's own `description` field already
    /// encodes the current season's actual boundaries.
    var zone: StandingZone {
        guard let zoneDescription else { return .none }
        if zoneDescription.contains("Relegation") { return .relegation }
        let qualificationKeywords = ["Promotion", "Champions League", "Europa League", "Conference League", "Libertadores", "Sudamericana"]
        if qualificationKeywords.contains(where: { zoneDescription.contains($0) }) { return .qualification }
        return .none
    }

    /// Our own localized label for `zone` — never the raw `zoneDescription` API text, which
    /// is English-only and inconsistently worded across competitions. `nil` for `.none`.
    var zoneAccessibilityLabel: String? {
        switch zone {
        case .qualification:
            return String(localized: "Continental qualification", comment: "VoiceOver/legend label for a standings row in a continental-competition qualification position (Champions League, Copa Libertadores, Copa Sudamericana, etc., regardless of which specific competition or stage).")
        case .relegation:
            return String(localized: "Relegation zone", comment: "VoiceOver/legend label for a standings row in a relegation position.")
        case .none:
            return nil
        }
    }

    private static let ordinalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter
    }()

    var accessibilityLabel: String {
        let positionText = Self.ordinalFormatter.string(from: NSNumber(value: position)) ?? String(position)
        let playedGamesText = String(playedGames)
        let wonText = String(won)
        let drawText = String(draw)
        let lostText = String(lost)
        let pointsText = String(points)
        let goalDifferenceText: String
        if goalDifference > 0 {
            let plusWord = String(localized: "plus", comment: "VoiceOver: prefix spoken before a positive goal difference, e.g. \"plus 15\".")
            goalDifferenceText = "\(plusWord) \(goalDifference)"
        } else if goalDifference < 0 {
            let minusWord = String(localized: "minus", comment: "VoiceOver: prefix spoken before a negative goal difference, e.g. \"minus 4\".")
            goalDifferenceText = "\(minusWord) \(abs(goalDifference))"
        } else {
            goalDifferenceText = String(goalDifference)
        }
        let baseLabel = String(
            localized: "\(positionText) place, \(team.displayName), \(playedGamesText) played, \(wonText) won, \(drawText) drawn, \(lostText) lost, goal difference \(goalDifferenceText), \(pointsText) points",
            comment: "VoiceOver label for one standings table row. Arguments: ordinal position, team name, games played, wins, draws, losses, goal difference (already spelled out with plus/minus), points."
        )
        guard let zoneLabel = zoneAccessibilityLabel else { return baseLabel }
        return "\(baseLabel), \(zoneLabel)"
    }
}

enum StandingZone {
    case qualification
    case relegation
    case none
}
