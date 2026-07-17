import SwiftUI

struct MatchdayView: View {
    @State private var viewModel: MatchdayViewModel
    @State private var selectedMatch: Match?
    let service: MatchService
    let themeStore: TeamThemeStore
    @Environment(\.themeTokens) private var themeTokens
    @Environment(\.scenePhase) private var scenePhase

    init(service: MatchService, themeStore: TeamThemeStore) {
        _viewModel = State(initialValue: MatchdayViewModel(service: service, themeStore: themeStore))
        self.service = service
        self.themeStore = themeStore
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Color.clear.frame(height: 0).id(Self.topAnchor)
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
                // Matchday renders its own title inline in the scrolled content (see
                // `header` below) rather than a system nav title, so this stays empty.
                // But leaving `.navigationTitle` unset entirely (the only one of the
                // three tabs to do so) combined with `.refreshable` caused a visible
                // content jump right at first launch — the nav bar had no stable title
                // to anchor its layout against while `.refreshable`'s content-inset
                // negotiation settled. Fixtures/Standings don't need this because they
                // already set a real title.
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                // Unlike Fixtures/Standings, Matchday doesn't show `RefreshPulseDot` in
                // its toolbar: even after the fixes above, a report of the screen still
                // shifting during refresh went away once the dot was removed here.
                // The exact mechanism wasn't isolated the way `.navigationTitle` and
                // `.refreshable`'s scroll correction were above — Matchday's blank
                // system title is the one structural difference from Fixtures/Standings
                // (which still show the dot without issue), so the dot's mount/unmount
                // likely interacts with that, but this fix is empirical, not proven.
                // `isRefreshing` is still tracked on the ViewModel; it's just not
                // surfaced here.
                // `.refreshable`'s content-inset negotiation can leave the scroll
                // position settled somewhere other than where it started once `load()`
                // reassigns `matches` mid-gesture — visible as the list appearing
                // shifted after a pull-to-refresh completes. Forcing it back to the top
                // anchor is safe (pull-to-refresh only triggers from at/near the top
                // already) and matches what most apps do after a manual refresh anyway.
                .refreshable {
                    await viewModel.load()
                    proxy.scrollTo(Self.topAnchor, anchor: .top)
                }
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    await viewModel.refreshIfNeeded()
                    await viewModel.pollWhileLive()
                }
                .sheet(item: $selectedMatch) { match in
                    MatchDetailView(match: match, service: service)
                }
            }
        }
        .trackScreen("Matchday")
    }

    private static let topAnchor = "matchdayTop"

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            eyebrowLabel
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(themeTokens.textColor.opacity(0.5))
                .textCase(.uppercase)
            Text(titleLabel)
                .font(.system(size: 32, weight: .heavy))
                .tracking(-0.5)
                .foregroundStyle(themeTokens.textColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func matchSection(title: Text, matches: [Match]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            title
                .font(.system(size: 13, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(themeTokens.textColor.opacity(0.5))
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
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
                .foregroundStyle(themeTokens.textColor.opacity(0.70))
            Text("Check Fixtures for the full schedule")
                .font(.system(size: 13))
                .foregroundStyle(themeTokens.textColor.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
