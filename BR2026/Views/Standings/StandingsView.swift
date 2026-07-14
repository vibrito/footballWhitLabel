import SwiftUI

struct StandingsView: View {
    @State private var viewModel: StandingsViewModel
    @Environment(\.themeTokens) private var themeTokens

    init(service: MatchService) {
        _viewModel = State(initialValue: StandingsViewModel(service: service))
    }

    private static let columnWidth: CGFloat = 24
    private static let goalDifferenceWidth: CGFloat = 34
    private static let positionWidth: CGFloat = 24
    private static let leadingWidth: CGFloat = 58

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    GlassCard(cornerRadius: 24, style: .transparent) {
                        VStack(spacing: 0) {
                            Color.clear.frame(height: 0).id(Self.topAnchor)
                            header
                            ForEach(viewModel.standings, id: \.id) { standing in
                                row(for: standing)
                            }
                        }
                    }
                    .padding(16)
                }
                .scrollContentBackground(.hidden)
                // See MatchdayView's `.refreshable` for why: `.refreshable`'s
                // content-inset negotiation can leave the scroll position settled away
                // from where it started once `load()` reassigns `standings` mid-gesture.
                // Forcing it back to the top anchor is safe since pull-to-refresh only
                // triggers from at/near the top already.
                .refreshable {
                    await viewModel.load()
                    proxy.scrollTo(Self.topAnchor, anchor: .top)
                }
                .background(StadiumBackground())
                .navigationTitle("Standings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        if viewModel.isRefreshing {
                            RefreshPulseDot()
                        }
                    }
                }
                .task { await viewModel.loadOnce() }
            }
        }
        .trackScreen("Standings")
    }

    private static let topAnchor = "standingsTop"

    private var header: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: Self.leadingWidth)
            Color.clear.frame(maxWidth: .infinity)
            columnHeader("P")
            columnHeader("W")
            columnHeader("D")
            columnHeader("L")
            columnHeader("GD", width: Self.goalDifferenceWidth)
            columnHeader("Pts")
        }
        .padding(.bottom, 8)
    }

    private func columnHeader(_ text: String, width: CGFloat = columnWidth) -> some View {
        Text(text)
            .lineLimit(1)
            .frame(width: width)
            .font(.system(size: 11, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(themeTokens.textColor.opacity(0.5))
    }

    private func row(for standing: Standing) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("\(standing.position)")
                    .lineLimit(1)
                    .frame(width: Self.positionWidth, alignment: .leading)
                TeamCrestBadge(team: standing.team, size: 20)
            }
            .frame(width: Self.leadingWidth, alignment: .leading)
            Text(standing.team.displayName)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            statCell("\(standing.playedGames)")
            statCell("\(standing.won)")
            statCell("\(standing.draw)")
            statCell("\(standing.lost)")
            statCell(signed(standing.goalDifference), width: Self.goalDifferenceWidth)
            statCell("\(standing.points)", emphasized: true)
        }
        .font(.system(size: 14, weight: .semibold))
        .monospacedDigit()
        .foregroundStyle(themeTokens.textColor)
        .padding(.vertical, 8)
    }

    private func statCell(_ text: String, width: CGFloat = columnWidth, emphasized: Bool = false) -> some View {
        Text(text)
            .lineLimit(1)
            .frame(width: width)
            .fontWeight(emphasized ? .heavy : .regular)
            .foregroundStyle(emphasized ? themeTokens.textColor : themeTokens.textColor.opacity(0.85))
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }
}
