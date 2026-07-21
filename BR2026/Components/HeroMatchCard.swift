import SwiftUI

/// The featured card at the top of Matchday: the next match still to be decided,
/// centered around large crests and a "vs" separator rather than the compact
/// side-by-side layout used elsewhere.
struct HeroMatchCard: View {
    let match: Match
    @Environment(\.themeTokens) private var themeTokens
    @ScaledMetric private var venueFontSize: CGFloat = 13
    @ScaledMetric private var kickoffFontSize: CGFloat = 15
    @ScaledMetric private var teamNameFontSize: CGFloat = 19
    @ScaledMetric private var scoreFontSize: CGFloat = 40
    @ScaledMetric private var vsFontSize: CGFloat = 30

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
                    .font(.system(size: venueFontSize, weight: .medium))
                    .foregroundStyle(themeTokens.textColor.opacity(0.5))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(themeTokens.overrideTabSelectionColor ?? themeTokens.overrideAccentColor ?? .clear, lineWidth: 1.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(match.accessibilityLabel)
        .accessibilityHint(Text("Double tap to view match details", comment: "VoiceOver hint on a match card button."))
    }

    @ViewBuilder
    private var topInfo: some View {
        switch match.status {
        case .live:
            LiveChip(minute: match.minute)
        case .halftime:
            LiveChip(isHalftime: true)
        default:
            Text(match.utcDate, style: .time)
                .font(.system(size: kickoffFontSize, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(themeTokens.textColor.opacity(0.65))
        }
    }

    private var venueLabel: String {
        match.venue ?? String(localized: "Venue TBD")
    }

    private func teamColumn(_ team: Team) -> some View {
        VStack(spacing: 12) {
            TeamCrestBadge(team: team, size: 88, showsInitials: true)
            Text(team.displayName)
                .font(.system(size: teamNameFontSize, weight: .bold))
                .foregroundStyle(themeTokens.textColor)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                // Without this, a long name (e.g. "Chapecoense-sc") that still doesn't fit
                // on 2 lines at larger Dynamic Type sizes truncates with "…" on the second
                // line — caught by AccessibilityAuditUITests' `.textClipped` audit. Matches
                // `centerContent`'s existing `.minimumScaleFactor(0.6)` below for the same
                // reason.
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var centerContent: some View {
        if let home = match.homeScore, let away = match.awayScore {
            Text("\(home) – \(away)")
                .font(.system(size: scoreFontSize, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(themeTokens.textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        } else {
            Text("VS")
                .font(.system(size: vsFontSize, weight: .heavy))
                .foregroundStyle(themeTokens.textColor.opacity(0.35))
        }
    }
}
