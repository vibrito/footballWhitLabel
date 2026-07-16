import SwiftUI

struct FixturesView: View {
    @State private var viewModel: FixturesViewModel
    @State private var selectedMatch: Match?
    let service: MatchService
    @Environment(\.themeTokens) private var themeTokens
    @Environment(\.scenePhase) private var scenePhase

    init(service: MatchService) {
        _viewModel = State(initialValue: FixturesViewModel(service: service))
        self.service = service
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                roundPicker
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            Color.clear.frame(height: 0).id(Self.topAnchor)
                            ForEach(viewModel.selectedRoundMatches, id: \.id) { match in
                                Button { selectedMatch = match } label: {
                                    FixtureMatchCard(match: match)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                    .scrollContentBackground(.hidden)
                    // See MatchdayView's `.refreshable` for why: `.refreshable`'s
                    // content-inset negotiation can leave the scroll position settled
                    // away from where it started once `load()` reassigns `matches`
                    // mid-gesture. Forcing it back to the top anchor is safe since
                    // pull-to-refresh only triggers from at/near the top already.
                    .refreshable {
                        await viewModel.load()
                        proxy.scrollTo(Self.topAnchor, anchor: .top)
                    }
                }
            }
            .background(StadiumBackground())
            .navigationTitle("Fixtures")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isRefreshing {
                        RefreshPulseDot()
                    }
                }
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
        .trackScreen("Fixtures")
    }

    private var roundPicker: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.rounds, id: \.self) { round in
                        roundPill(round)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.selectedRound) { _, newValue in
                guard let newValue else { return }
                withAnimation {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    private func roundPill(_ round: Int) -> some View {
        let isSelected = viewModel.selectedRound == round
        return Button {
            viewModel.selectedRound = round
        } label: {
            VStack(spacing: 2) {
                Text("Round")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.4)
                Text("\(round)")
                    .font(.system(size: 17, weight: .heavy))
                    .monospacedDigit()
            }
            .foregroundStyle(isSelected ? themeTokens.textColor : themeTokens.textColor.opacity(0.55))
            .frame(width: 60, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? (themeTokens.overridePillFillColor ?? themeTokens.overrideTabSelectionColor ?? Color.accentColor) : Color.white.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .id(round)
    }

    private static let topAnchor = "fixturesTop"
}
