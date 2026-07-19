// BR2026/Components/LineupsView.swift
import SwiftUI

/// A jersey-shaped marker: sleeves plus a V-neck notch. Polygon points are fractions of
/// the marker's own bounding box, matching the approved brainstorming-session mockup's
/// CSS `clip-path: polygon(...)` exactly.
private struct JerseyShape: Shape {
    private static let points: [(CGFloat, CGFloat)] = [
        (0.30, 0.0), (0.42, 0.0), (0.50, 0.16), (0.58, 0.0), (0.70, 0.0),
        (1.0, 0.22), (0.85, 0.40), (0.85, 1.0), (0.15, 1.0), (0.15, 0.40), (0.0, 0.22)
    ]

    func path(in rect: CGRect) -> Path {
        let scaled = Self.points.map { CGPoint(x: rect.minX + $0.0 * rect.width, y: rect.minY + $0.1 * rect.height) }
        var path = Path()
        path.move(to: scaled[0])
        for point in scaled.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }
}

private enum PitchSide {
    case home
    case away
}

private struct PlacedPlayer: Identifiable {
    let id: String
    let player: LineupPlayer
    let xPercent: Double
    let yPercent: Double
    let teamName: String
    let kitColorHex: String
    let kitFontColorHex: String
}

/// A soccer-pitch-shaped formation grid: each starting player renders as a jersey marker
/// positioned via the API's col/row grid coordinates, confined strictly to its own team's
/// half. Substitutes (which have no col/row) render as a plain list below. Matches the
/// approved brainstorming-session mockup, including the fix for a real overlap bug found
/// during that review (see `bylineMargin`/`halfwayMargin`).
struct LineupsView: View {
    let lineup: MatchLineup
    let homeTeamName: String
    let awayTeamName: String
    @Environment(\.themeTokens) private var themeTokens
    @ScaledMetric private var jerseyNumberFontSize: CGFloat = 11
    @ScaledMetric private var playerNameFontSize: CGFloat = 9
    @ScaledMetric private var formationLabelFontSize: CGFloat = 12
    @ScaledMetric private var substitutesHeaderFontSize: CGFloat = 13
    @ScaledMetric private var substituteRowFontSize: CGFloat = 13

    private static let jerseyWidth: CGFloat = 30
    private static let jerseyHeight: CGFloat = 32
    // GK stays off the very edge (byline); the deepest attacking line stays well clear of
    // the halfway line so the two teams' closest rows never collide regardless of
    // formation. An earlier mockup iteration used halfwayMargin = 2, which visually
    // collided the two teams' lone strikers (each centered horizontally, since each was
    // the only player in its row) directly on the halfway line — do not regress this
    // value back down without re-checking that exact case.
    private static let bylineMargin: Double = 6
    private static let halfwayMargin: Double = 12

    var body: some View {
        VStack(spacing: 16) {
            formationLabels
            pitch
            substitutesList
        }
    }

    private var formationLabels: some View {
        HStack {
            Text("\(homeTeamName.uppercased()) · \(lineup.home.formation)")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(formationAccessibilityLabel(teamName: homeTeamName, formation: lineup.home.formation))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Text("\(awayTeamName.uppercased()) · \(lineup.away.formation)")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(formationAccessibilityLabel(teamName: awayTeamName, formation: lineup.away.formation))
                .accessibilityAddTraits(.isHeader)
        }
        .font(.system(size: formationLabelFontSize, weight: .bold))
        .foregroundStyle(themeTokens.textColor.opacity(0.55))
    }

    private func formationAccessibilityLabel(teamName: String, formation: String) -> String {
        String(
            localized: "\(teamName), formation \(formation)",
            comment: "VoiceOver heading label spoken before a team's players on the lineup formation pitch. Arguments: team name, formation string (e.g. \"4-2-3-1\")."
        )
    }

    private var pitch: some View {
        GeometryReader { geometry in
            ZStack {
                pitchLines
                ForEach(placedPlayers(for: lineup.home, side: .home, teamName: homeTeamName)) { placed in
                    playerMarker(placed, in: geometry.size)
                }
                ForEach(placedPlayers(for: lineup.away, side: .away, teamName: awayTeamName)) { placed in
                    playerMarker(placed, in: geometry.size)
                }
            }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .background(
            LinearGradient(
                colors: [Color(hex: "1d6b3a"), Color(hex: "1a5f33"), Color(hex: "1d6b3a")],
                startPoint: .top, endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    private var pitchLines: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                    .frame(width: geometry.size.width, height: 0)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                Circle()
                    .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                    .frame(width: 70, height: 70)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                Rectangle()
                    .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                    .frame(width: geometry.size.width * 0.55, height: geometry.size.height * 0.14)
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.07)
                Rectangle()
                    .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                    .frame(width: geometry.size.width * 0.55, height: geometry.size.height * 0.14)
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.93)
            }
        }
        .accessibilityHidden(true)
    }

    private func placedPlayers(for team: TeamLineup, side: PitchSide, teamName: String) -> [PlacedPlayer] {
        guard let maxRow = team.startingXI.compactMap(\.row).max(), maxRow >= 1 else { return [] }
        let rows = Dictionary(grouping: team.startingXI, by: { $0.row ?? 0 })
        var placed: [PlacedPlayer] = []
        for (row, players) in rows {
            let sorted = players.sorted { ($0.col ?? 0) < ($1.col ?? 0) }
            for (index, player) in sorted.enumerated() {
                let xPercent = Double(index + 1) / Double(sorted.count + 1) * 100
                let t = maxRow == 1 ? 0.0 : Double(row - 1) / Double(maxRow - 1)
                let yPercent: Double
                switch side {
                case .home:
                    yPercent = (100 - Self.bylineMargin) - t * ((100 - Self.bylineMargin) - (50 + Self.halfwayMargin))
                case .away:
                    yPercent = Self.bylineMargin + t * ((50 - Self.halfwayMargin) - Self.bylineMargin)
                }
                placed.append(PlacedPlayer(
                    id: "\(side == .home ? "home" : "away")-\(player.number)",
                    player: player,
                    xPercent: xPercent,
                    yPercent: yPercent,
                    teamName: teamName,
                    kitColorHex: team.kitColorHex,
                    kitFontColorHex: team.kitFontColorHex
                ))
            }
        }
        return placed
    }

    private func playerMarker(_ placed: PlacedPlayer, in size: CGSize) -> some View {
        VStack(spacing: 2) {
            JerseyShape()
                .fill(Color(hex: placed.kitColorHex))
                .frame(width: Self.jerseyWidth, height: Self.jerseyHeight)
                .overlay(JerseyShape().stroke(Color.black.opacity(0.25), lineWidth: 1))
                .overlay(
                    Text("\(placed.player.number)")
                        .font(.system(size: jerseyNumberFontSize, weight: .heavy))
                        .foregroundStyle(Color(hex: placed.kitFontColorHex))
                        .padding(.top, 6)
                )
            Text(placed.player.name)
                .font(.system(size: playerNameFontSize, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .fixedSize()
        }
        .position(x: size.width * placed.xPercent / 100, y: size.height * placed.yPercent / 100)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(playerAccessibilityLabel(placed))
    }

    private func playerAccessibilityLabel(_ placed: PlacedPlayer) -> String {
        String(
            localized: "\(placed.player.name), number \(String(placed.player.number)), \(placed.player.positionAccessibilityLabel), \(placed.teamName)",
            comment: "VoiceOver label for one lineup player marker on the formation pitch. Arguments: player name, jersey number (already formatted as a string), position (already localized, e.g. \"Goalkeeper\"), team name."
        )
    }

    private var substitutesList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Substitutes", comment: "Match detail Lineups tab section header, above the list of bench players.")
                .font(.system(size: substitutesHeaderFontSize, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(themeTokens.textColor.opacity(0.5))
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)

            // Enumerated, not `id: \.number` — two different teams' substitutes can share
            // the same jersey number (e.g. both backup goalkeepers wearing #12), which
            // would break ForEach's identity requirement across the combined array.
            ForEach(Array((lineup.home.substitutes + lineup.away.substitutes).enumerated()), id: \.offset) { _, player in
                Text("\(player.number)  \(player.name) (\(player.position))")
                    .font(.system(size: substituteRowFontSize, weight: .medium))
                    .foregroundStyle(themeTokens.textColor.opacity(0.65))
            }
        }
    }
}
