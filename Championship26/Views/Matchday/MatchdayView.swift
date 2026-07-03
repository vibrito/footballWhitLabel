import SwiftUI

struct MatchdayView: View {
    @State private var viewModel: MatchdayViewModel

    init(service: MatchService) {
        _viewModel = State(initialValue: MatchdayViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.todaysMatches.isEmpty {
                        emptyState
                    } else {
                        ForEach(viewModel.todaysMatches, id: \.id) { match in
                            GlassCard {
                                ScoreRow(match: match)
                            }
                        }
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

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No matches today")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.70))
            Text("Check Fixtures for upcoming rounds")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.top, 60)
    }
}
