import SwiftUI

struct FixturesView: View {
    @State private var viewModel: FixturesViewModel

    init(service: MatchService) {
        _viewModel = State(initialValue: FixturesViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(viewModel.matchesByRound, id: \.round) { group in
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Round \(group.round)")
                                .font(.system(size: 13, weight: .bold))
                                .tracking(0.8)
                                .foregroundStyle(.white.opacity(0.5))
                            ForEach(group.matches, id: \.id) { match in
                                GlassCard {
                                    ScoreRow(match: match)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Fixtures")
            .task { await viewModel.load() }
        }
    }
}
