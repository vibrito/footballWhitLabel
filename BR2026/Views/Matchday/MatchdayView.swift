import SwiftUI

struct MatchdayView: View {
    @State private var viewModel: MatchdayViewModel
    @State private var selectedMatch: Match?
    let service: MatchService

    init(service: MatchService) {
        _viewModel = State(initialValue: MatchdayViewModel(service: service))
        self.service = service
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let nextMatch = viewModel.nextMatch {
                        header
                        Button { selectedMatch = nextMatch } label: {
                            HeroMatchCard(match: nextMatch)
                        }
                        .buttonStyle(.plain)
                        if !viewModel.finishedMatchesForNextMatchDay.isEmpty {
                            matchSection(title: Text("Finished"), matches: viewModel.finishedMatchesForNextMatchDay)
                        }
                        if !viewModel.upcomingMatchesForNextMatchDay.isEmpty {
                            matchSection(title: alsoTodayLabel, matches: viewModel.upcomingMatchesForNextMatchDay)
                        }
                    } else {
                        emptyState
                    }
                }
                .padding(16)
            }
            .scrollContentBackground(.hidden)
            .background(StadiumBackground())
            // Matchday renders its own title inline in the scrolled content (see `header`
            // below) rather than a system nav title, so this stays empty. But leaving
            // `.navigationTitle` unset entirely (the only one of the three tabs to do so)
            // combined with `.refreshable` caused a visible one-time upward content jump
            // shortly after appearing — the nav bar had no stable title to anchor its
            // layout against while `.refreshable`'s content-inset negotiation settled.
            // Fixtures/Standings don't need this because they already set a real title.
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isRefreshing {
                        RefreshPulseDot()
                    }
                }
            }
            .refreshable { await viewModel.load() }
            .task { await viewModel.loadOnce() }
            .sheet(item: $selectedMatch) { match in
                MatchDetailView(match: match, service: service)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            eyebrowLabel
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
            Text(titleLabel)
                .font(.system(size: 32, weight: .heavy))
                .tracking(-0.5)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func matchSection(title: Text, matches: [Match]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            title
                .font(.system(size: 13, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
            ForEach(matches, id: \.id) { match in
                Button { selectedMatch = match } label: {
                    FixtureMatchCard(match: match)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var eyebrowLabel: Text {
        guard let date = viewModel.nextMatch?.utcDate else { return Text("") }
        let weekday = Text(date, format: .dateTime.weekday(.abbreviated))
        let dayMonth = Text(date, format: .dateTime.day().month(.abbreviated))
        return Text("\(weekday) · \(dayMonth)")
    }

    private var titleLabel: String {
        guard let date = viewModel.nextMatch?.utcDate else { return "" }
        if Calendar.current.isDateInToday(date) {
            return String(localized: "Today")
        }
        return date.formatted(.dateTime.weekday(.wide))
    }

    private var alsoTodayLabel: Text {
        guard let date = viewModel.nextMatch?.utcDate else { return Text("") }
        if Calendar.current.isDateInToday(date) {
            return Text("Also Today")
        }
        let weekday = Text(date, format: .dateTime.weekday(.wide))
        return Text("Also \(weekday)")
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
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
