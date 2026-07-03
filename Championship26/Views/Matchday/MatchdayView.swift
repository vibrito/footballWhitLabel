import SwiftUI

struct MatchdayView: View {
    @State private var viewModel: MatchdayViewModel

    init(service: MatchService) {
        _viewModel = State(initialValue: MatchdayViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let nextMatch = viewModel.nextMatch {
                        HeroMatchCard(match: nextMatch)
                        if !viewModel.otherMatchesForNextMatchDay.isEmpty {
                            dayMatches
                        }
                    } else {
                        emptyState
                    }
                }
                .padding(16)
            }
            .scrollContentBackground(.hidden)
            .background(StadiumBackground())
            .navigationTitle("Matchday")
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.load() }
        }
    }

    private var dayMatches: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(dayLabel)
                .font(.system(size: 13, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.5))
            ForEach(viewModel.otherMatchesForNextMatchDay, id: \.id) { match in
                GlassCard(style: .transparent) {
                    ScoreRow(match: match)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dayLabel: String {
        guard let date = viewModel.nextMatch?.utcDate else { return "" }
        if Calendar.current.isDateInToday(date) {
            return String(localized: "Today")
        }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No upcoming matches")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.70))
            Text("Check Fixtures for the full schedule")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.top, 60)
    }
}
