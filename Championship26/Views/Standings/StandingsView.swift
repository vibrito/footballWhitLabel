import SwiftUI

struct StandingsView: View {
    @State private var viewModel: StandingsViewModel

    init(service: MatchService) {
        _viewModel = State(initialValue: StandingsViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                GlassCard(cornerRadius: 24) {
                    VStack(spacing: 0) {
                        ForEach(viewModel.standings, id: \.id) { standing in
                            HStack {
                                Text("\(standing.position)")
                                    .frame(width: 24, alignment: .leading)
                                TeamCrestBadge(team: standing.team, size: 20)
                                Text(standing.team.shortName ?? standing.team.name)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(standing.points)")
                                    .fontWeight(.bold)
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .padding(.vertical, 8)
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Standings")
            .task { await viewModel.load() }
        }
    }
}
