import SwiftUI

/// A single match card for the Fixtures list: a venue/status header bar followed by
/// two stacked team rows (crest, name, score), matching the reference World Cup
/// design rather than ScoreRow's side-by-side layout.
struct FixtureMatchCard: View {
    let match: Match
    @Environment(\.themeTokens) private var themeTokens
    @ScaledMetric private var headerFontSize: CGFloat = 11
    @ScaledMetric private var teamNameFontSize: CGFloat = 16
    @ScaledMetric private var scoreFontSize: CGFloat = 19

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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(match.accessibilityLabel)
        .accessibilityHint(Text("Double tap to view match details", comment: "VoiceOver hint on a match card button."))
    }

    private var header: some View {
        HStack {
            Text(venueLabel)
                .lineLimit(1)
                // Long venue names ("Estádio José Maria de Campos Maia") clip at larger
                // Dynamic Type sizes when sharing the row with statusView — same fix as
                // every other fixed-width/shared-row text cell in the app (Standings
                // headers, team names), but needs a lower floor than those cells' usual
                // 0.7: this string is long enough that 0.7 still clipped in practice.
                // Caught by AccessibilityAuditUITests' `.textClipped` audit once a round
                // with FINISHED matches (which show a venue) became reachable as the
                // default selected round.
                .minimumScaleFactor(0.5)
            Spacer()
            statusView
        }
        .font(.system(size: headerFontSize, weight: .bold))
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
            Text(team.displayName)
                .font(.system(size: teamNameFontSize, weight: .semibold))
                .foregroundStyle(themeTokens.textColor)
                .lineLimit(1)
            Spacer()
            if let score {
                Text("\(score)")
                    .font(.system(size: scoreFontSize, weight: .heavy))
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
