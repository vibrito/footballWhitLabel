import SwiftUI

/// A single match card for the Fixtures list: a venue/status header bar followed by
/// two stacked team rows (crest, name, score), matching the reference World Cup
/// design rather than ScoreRow's side-by-side layout.
struct FixtureMatchCard: View {
    let match: Match
    @Environment(\.themeTokens) private var themeTokens

    var body: some View {
        GlassCard(cornerRadius: 22, style: .transparent) {
            VStack(spacing: 12) {
                header
                VStack(spacing: 0) {
                    teamRow(match.homeTeam, score: match.homeScore)
                    divider
                    teamRow(match.awayTeam, score: match.awayScore)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text(venueLabel)
                .lineLimit(1)
            Spacer()
            statusView
        }
        .font(.system(size: 11, weight: .bold))
        .tracking(0.6)
        .foregroundStyle(themeTokens.textColor.opacity(0.5))
    }

    private var venueLabel: String {
        match.venue?.uppercased() ?? String(localized: "Venue TBD").uppercased()
    }

    @ViewBuilder
    private var statusView: some View {
        switch match.status {
        case .finished:
            Text("\(dateLabel) · FT")
        case .live:
            LiveChip(minute: match.minute)
        case .halftime:
            LiveChip(isHalftime: true)
        case .postponed:
            // A postponed match's stored date may just be a stale placeholder from
            // before the postponement, so it isn't shown alongside the status.
            Text("PPD")
        case .scheduled:
            Text("\(dateLabel) · \(timeLabel)")
        }
    }

    private var dateLabel: Text {
        Text(match.utcDate, format: .dateTime.day().month(.abbreviated))
    }

    private var timeLabel: Text {
        Text(match.utcDate, style: .time)
    }

    private func teamRow(_ team: Team, score: Int?) -> some View {
        HStack(spacing: 12) {
            TeamCrestBadge(team: team, size: 28)
            Text(team.displayName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(themeTokens.textColor)
                .lineLimit(1)
            Spacer()
            if let score {
                Text("\(score)")
                    .font(.system(size: 19, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(themeTokens.textColor)
            }
        }
        .padding(.vertical, 10)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(height: 0.5)
    }
}
