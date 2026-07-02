import SwiftUI

/// A single match card for the Fixtures list: a venue/status header bar followed by
/// two stacked team rows (crest, name, score), matching the reference World Cup
/// design rather than ScoreRow's side-by-side layout.
struct FixtureMatchCard: View {
    let match: Match

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
        .foregroundStyle(.white.opacity(0.5))
    }

    private var venueLabel: String {
        match.venue?.uppercased() ?? String(localized: "Venue TBD").uppercased()
    }

    @ViewBuilder
    private var statusView: some View {
        switch match.status {
        case .finished:
            Text("FT")
        case .live:
            LiveChip(minute: match.minute)
        case .postponed:
            Text("PPD")
        case .scheduled:
            Text(match.utcDate, style: .time)
        }
    }

    private func teamRow(_ team: Team, score: Int?) -> some View {
        HStack(spacing: 12) {
            TeamCrestBadge(team: team, size: 28)
            Text(team.displayName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
            if let score {
                Text("\(score)")
                    .font(.system(size: 19, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(.white)
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
