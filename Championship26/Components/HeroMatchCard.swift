import SwiftUI

/// The featured card at the top of Matchday: the next match still to be decided,
/// shown larger than a regular ScoreRow/FixtureMatchCard entry.
struct HeroMatchCard: View {
    let match: Match

    var body: some View {
        GlassCard(cornerRadius: 28, style: .transparent) {
            VStack(spacing: 20) {
                header
                HStack(alignment: .top, spacing: 12) {
                    teamColumn(match.homeTeam)
                    centerContent
                        .frame(maxWidth: 90)
                    teamColumn(match.awayTeam)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text(venueLabel)
                .lineLimit(1)
            Spacer()
            if match.status == .live {
                LiveChip(minute: match.minute)
            }
        }
        .font(.system(size: 11, weight: .bold))
        .tracking(0.6)
        .foregroundStyle(.white.opacity(0.5))
    }

    private var venueLabel: String {
        match.venue?.uppercased() ?? String(localized: "Venue TBD").uppercased()
    }

    private func teamColumn(_ team: Team) -> some View {
        VStack(spacing: 10) {
            TeamCrestBadge(team: team, size: 52)
            Text(team.displayName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var centerContent: some View {
        if let home = match.homeScore, let away = match.awayScore {
            Text("\(home) – \(away)")
                .font(.system(size: 46, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        } else {
            VStack(spacing: 4) {
                Text(match.utcDate, format: .dateTime.day().month(.abbreviated))
                Text(match.utcDate, style: .time)
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white.opacity(0.7))
        }
    }
}
