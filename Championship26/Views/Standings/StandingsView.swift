import SwiftUI

struct StandingsView: View {
    @State private var viewModel: StandingsViewModel
    // Test probe: true once the list has scrolled far enough that the header would be
    // pinned, false again back at the top — lets us visually confirm the pin is
    // actually triggering by snapping the header's fill to fully opaque while pinned.
    @State private var isHeaderPinned = false

    init(service: MatchService) {
        _viewModel = State(initialValue: StandingsViewModel(service: service))
    }

    private static let columnWidth: CGFloat = 24
    private static let goalDifferenceWidth: CGFloat = 34
    private static let positionWidth: CGFloat = 24
    private static let leadingWidth: CGFloat = 58

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
                    Section {
                        GlassCard(cornerRadius: 24, style: .transparent) {
                            VStack(spacing: 0) {
                                ForEach(viewModel.standings, id: \.id) { standing in
                                    row(for: standing)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    } header: {
                        header
                    }
                }
                .padding(.vertical, 16)
            }
            .scrollContentBackground(.hidden)
            .background(StadiumBackground())
            .navigationTitle("Standings")
            .task { await viewModel.load() }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y > 20
            } action: { _, isPastTop in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHeaderPinned = isPastTop
                }
            }
        }
    }

    // A real SwiftUI pinned section header: scrolls normally with the table until it
    // reaches the top of the viewport (right below the now-collapsed nav bar), then
    // sticks there while the rows scroll beneath it — and un-sticks, following the
    // content back down, when the user scrolls back up to the top. Same fill/corner
    // treatment as the row card below it (not `.ultraThinMaterial`, and the same 16pt
    // outer margin) so it reads as one consistent panel rather than a mismatched bar.
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
        .padding(16)
        .background(Color.white.opacity(isHeaderPinned ? 1 : 0.05))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
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
