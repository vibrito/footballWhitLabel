import SwiftUI

/// The featured card at the top of Matchday: the next match still to be decided,
/// centered around large crests and a "vs" separator rather than the compact
/// side-by-side layout used elsewhere.
struct HeroMatchCard: View {
    let match: Match
    @Environment(\.themeTokens) private var themeTokens

    var body: some View {
        GlassCard(cornerRadius: 28, style: .transparent) {
            VStack(spacing: 20) {
                topInfo
                HStack(alignment: .center, spacing: 12) {
                    teamColumn(match.homeTeam)
                    centerContent
                        .frame(minWidth: 70)
                    teamColumn(match.awayTeam)
                }
                Text(venueLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(themeTokens.textColor.opacity(0.5))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(themeTokens.overrideTabSelectionColor ?? themeTokens.overrideAccentColor ?? .clear, lineWidth: 1.5)
        )
    }

    @ViewBuilder
    private var topInfo: some View {
        if match.status == .live {
            LiveChip(minute: match.minute)
        } else {
            Text(match.utcDate, style: .time)
                .font(.system(size: 15, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(themeTokens.textColor.opacity(0.65))
        }
    }

    private var venueLabel: String {
        match.venue ?? String(localized: "Venue TBD")
    }

    private func teamColumn(_ team: Team) -> some View {
        VStack(spacing: 12) {
            TeamCrestBadge(team: team, size: 88)
            Text(team.displayName)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(themeTokens.textColor)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var centerContent: some View {
        if let home = match.homeScore, let away = match.awayScore {
            Text("\(home) – \(away)")
                .font(.system(size: 40, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(themeTokens.textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        } else {
            Text("VS")
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(themeTokens.textColor.opacity(0.35))
        }
    }
}
