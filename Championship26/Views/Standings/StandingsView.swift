import SwiftUI

struct StandingsView: View {
    @State private var viewModel: StandingsViewModel
    // Measured height of the fixed header chrome (including its own top/side margins),
    // so the scrolling content below can reserve exactly that much space and the rows
    // start right where the header visually ends, with no gap and no overlap.
    @State private var headerChromeHeight: CGFloat = 0

    init(service: MatchService) {
        _viewModel = State(initialValue: StandingsViewModel(service: service))
    }

    private static let columnWidth: CGFloat = 24
    private static let goalDifferenceWidth: CGFloat = 34
    private static let positionWidth: CGFloat = 24
    private static let leadingWidth: CGFloat = 58

    private static let cardFill = Color.white.opacity(0.05)
    private static let cardStroke = Color.white.opacity(0.16)

    // The header is NOT part of the ScrollView's content — SwiftUI's native
    // LazyVStack(pinnedViews: [.sectionHeaders]) mechanism did not actually stay fixed
    // in practice under this NavigationStack. Instead it's a permanent ZStack overlay
    // above the ScrollView, which is unconditionally fixed by construction, and the
    // scrolling content reserves matching empty space (`headerChromeHeight`) at its top
    // so the row card starts exactly where the header visually ends.
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: headerChromeHeight)
                        VStack(spacing: 0) {
                            ForEach(viewModel.standings, id: \.id) { standing in
                                row(for: standing)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                        .background(rowsShape.fill(Self.cardFill))
                        .overlay(rowsShape.strokeBorder(Self.cardStroke, lineWidth: 0.5))
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 16)
                }
                .scrollContentBackground(.hidden)

                header
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .background {
                        GeometryReader { proxy in
                            Color.clear.onAppear { headerChromeHeight = proxy.size.height }
                        }
                    }
            }
            .background(StadiumBackground())
            .navigationTitle("Standings")
            .task { await viewModel.load() }
        }
    }

    // Header and rows share one fill/stroke and sit flush against each other (no gap,
    // no independent rounded pill) so they read as a single card — only the header's
    // top corners and the rows' bottom corners are rounded, like one shape split in two
    // pieces.
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
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(headerShape.fill(Self.cardFill))
        .overlay(headerShape.strokeBorder(Self.cardStroke, lineWidth: 0.5))
        .padding(.horizontal, 16)
    }

    private var headerShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 24,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 24,
            style: .continuous
        )
    }

    private var rowsShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 24,
            bottomTrailingRadius: 24,
            topTrailingRadius: 0,
            style: .continuous
        )
    }

    private func columnHeader(_ text: String, width: CGFloat = columnWidth) -> some View {
        Text(text)
            .lineLimit(1)
            .frame(width: width)
            .font(.system(size: 11, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(.white.opacity(0.5))
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
        .foregroundStyle(.white)
        .padding(.vertical, 8)
    }

    private func statCell(_ text: String, width: CGFloat = columnWidth, emphasized: Bool = false) -> some View {
        Text(text)
            .lineLimit(1)
            .frame(width: width)
            .fontWeight(emphasized ? .heavy : .regular)
            .foregroundStyle(emphasized ? .white : .white.opacity(0.85))
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }
}
