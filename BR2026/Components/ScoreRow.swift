import SwiftUI

struct ScoreRow: View {
    let match: Match
    @Environment(\.themeTokens) private var themeTokens

    var body: some View {
        HStack {
            teamLabel(match.homeTeam)
            Spacer()
            VStack(spacing: 4) {
                if match.status == .live {
                    LiveChip(minute: match.minute)
                }
                scoreText
            }
            Spacer()
            teamLabel(match.awayTeam)
        }
    }

    private func teamLabel(_ team: Team) -> some View {
        HStack(spacing: 8) {
            TeamCrestBadge(team: team)
            Text(team.displayName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(themeTokens.textColor)
        }
    }

    private var scoreText: some View {
        Group {
            if let home = match.homeScore, let away = match.awayScore {
                Text("\(home) – \(away)")
            } else {
                Text(match.utcDate, style: .time)
            }
        }
        .font(.system(size: 19, weight: .heavy))
        .monospacedDigit()
        .foregroundStyle(themeTokens.textColor)
    }
}
