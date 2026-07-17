import SwiftUI

struct MatchDetailView: View {
    @State private var viewModel: MatchDetailViewModel
    @Environment(\.themeTokens) private var themeTokens
    @Environment(\.scenePhase) private var scenePhase

    init(match: Match, service: MatchService) {
        _viewModel = State(initialValue: MatchDetailViewModel(match: match, service: service))
    }

    private var match: Match { viewModel.match }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.horizontal, 16)
                timelineSection
                    .padding(.top, 24)
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
        .background(StadiumBackground())
        .presentationDragIndicator(.visible)
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await viewModel.load()
            await viewModel.pollWhileLive()
        }
        .trackScreen("MatchDetail")
    }

    private var header: some View {
        VStack(spacing: 12) {
            Text("Round \(match.matchday)")
                .font(.system(size: 12, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(themeTokens.textColor.opacity(0.5))
                .textCase(.uppercase)

            statusLine
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(themeTokens.textColor.opacity(0.6))

            HStack(alignment: .center, spacing: 16) {
                teamColumn(match.homeTeam, isDimmed: isHomeDimmed)
                centerScore
                    .frame(minWidth: 80)
                teamColumn(match.awayTeam, isDimmed: isAwayDimmed)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(match.accessibilityLabel)

            if let halfTimeText {
                halfTimeText
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(themeTokens.textColor.opacity(0.45))
                    .textCase(.uppercase)
            }

            if let venue = match.venue {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                    Text(venue)
                }
                .font(.system(size: 13))
                .foregroundStyle(themeTokens.textColor.opacity(0.5))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(localized: "Venue: \(venue)", comment: "VoiceOver label for the match detail venue row. Argument: the venue name."))
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var statusLine: some View {
        switch match.status {
        case .finished:
            Text("FT")
        case .live:
            LiveChip(minute: match.minute)
        case .halftime:
            LiveChip(isHalftime: true)
        case .postponed:
            Text("PPD")
        case .scheduled:
            Text(match.utcDate, style: .time)
        }
    }

    private var isHomeDimmed: Bool { match.winner == "AWAY_TEAM" }
    private var isAwayDimmed: Bool { match.winner == "HOME_TEAM" }

    private func teamColumn(_ team: Team, isDimmed: Bool) -> some View {
        VStack(spacing: 12) {
            TeamCrestBadge(team: team, size: 80)
            Text(team.displayName)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(isDimmed ? themeTokens.textColor.opacity(0.45) : themeTokens.textColor)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var centerScore: some View {
        if let home = match.homeScore, let away = match.awayScore {
            Text("\(home) – \(away)")
                .font(.system(size: 48, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(themeTokens.textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        } else {
            Text("VS")
                .font(.system(size: 32, weight: .heavy))
                .foregroundStyle(themeTokens.textColor.opacity(0.35))
        }
    }

    private var halfTimeText: Text? {
        guard match.status == .finished || match.status.isLiveOrHalftime else { return nil }
        guard let home = match.halfTimeHomeScore, let away = match.halfTimeAwayScore else { return nil }
        return Text("Half-time \(home)–\(away)")
    }

    private var timelineSection: some View {
        VStack(spacing: 0) {
            Text("Timeline")
                .font(.system(size: 13, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(themeTokens.textColor.opacity(0.5))
                .textCase(.uppercase)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
                .accessibilityAddTraits(.isHeader)

            if sortedEvents.isEmpty {
                Text("No events yet")
                    .font(.system(size: 14))
                    .foregroundStyle(themeTokens.textColor.opacity(0.45))
                    .padding(.top, 20)
            } else {
                ForEach(sortedEvents) { event in
                    MatchTimelineRow(event: event)
                    if event.id != sortedEvents.last?.id {
                        Divider().background(Color.white.opacity(0.08))
                    }
                }
            }
        }
    }

    private var sortedEvents: [MatchEvent] {
        viewModel.events.sorted {
            ($0.minute, $0.extraMinute ?? 0) < ($1.minute, $1.extraMinute ?? 0)
        }
    }
}
