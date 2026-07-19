import SwiftUI

/// Six comparison-bar rows (Possession, Shots, Shots on Target, Corners, Fouls, Pass
/// Accuracy) — teal fill for the home team's share, muted white for away's, proportional
/// to each stat's total. Matches the approved brainstorming-session mockup.
struct StatisticsView: View {
    let statistics: MatchStatistics
    @Environment(\.themeTokens) private var themeTokens
    @ScaledMetric private var valueFontSize: CGFloat = 15
    @ScaledMetric private var labelFontSize: CGFloat = 11

    private struct StatRow {
        let label: String
        let home: Int
        let away: Int
        let suffix: String
    }

    private var rows: [StatRow] {
        [
            StatRow(label: String(localized: "Possession", comment: "Match statistics row label: percentage of the match each team controlled the ball."), home: statistics.home.possession, away: statistics.away.possession, suffix: "%"),
            StatRow(label: String(localized: "Shots", comment: "Match statistics row label: total shot attempts."), home: statistics.home.shots, away: statistics.away.shots, suffix: ""),
            StatRow(label: String(localized: "Shots on Target", comment: "Match statistics row label: shot attempts that were on target."), home: statistics.home.shotsOnTarget, away: statistics.away.shotsOnTarget, suffix: ""),
            StatRow(label: String(localized: "Corners", comment: "Match statistics row label: corner kicks taken."), home: statistics.home.corners, away: statistics.away.corners, suffix: ""),
            StatRow(label: String(localized: "Fouls", comment: "Match statistics row label: fouls committed."), home: statistics.home.fouls, away: statistics.away.fouls, suffix: ""),
            StatRow(label: String(localized: "Pass Accuracy", comment: "Match statistics row label: percentage of completed passes."), home: statistics.home.passAccuracy, away: statistics.away.passAccuracy, suffix: "%")
        ]
    }

    var body: some View {
        VStack(spacing: 18) {
            ForEach(rows.indices, id: \.self) { index in
                statRow(rows[index])
            }
        }
    }

    private func statRow(_ row: StatRow) -> some View {
        let total = max(row.home + row.away, 1)
        let homeFraction = Double(row.home) / Double(total)
        return VStack(spacing: 6) {
            HStack {
                Text("\(row.home)\(row.suffix)")
                Spacer()
                Text("\(row.away)\(row.suffix)")
            }
            .font(.system(size: valueFontSize, weight: .heavy))
            .monospacedDigit()
            .foregroundStyle(themeTokens.textColor)

            Text(row.label)
                .font(.system(size: labelFontSize, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(themeTokens.textColor.opacity(0.5))
                .textCase(.uppercase)

            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(hex: "2dd4bf"))
                        .frame(width: geometry.size.width * homeFraction)
                    Rectangle()
                        .fill(Color.white.opacity(0.35))
                }
            }
            .frame(height: 6)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statAccessibilityLabel(row))
    }

    private func statAccessibilityLabel(_ row: StatRow) -> String {
        let homeText = "\(row.home)\(row.suffix)"
        let awayText = "\(row.away)\(row.suffix)"
        return String(
            localized: "\(row.label): Home \(homeText), Away \(awayText)",
            comment: "VoiceOver label for one match-statistics comparison row. Arguments: stat name (already localized), home team's value (already formatted, e.g. \"48%\"), away team's value (already formatted)."
        )
    }
}
