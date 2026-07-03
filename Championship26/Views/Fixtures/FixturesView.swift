import SwiftUI

struct FixturesView: View {
    @State private var viewModel: FixturesViewModel

    init(service: MatchService) {
        _viewModel = State(initialValue: FixturesViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                roundPicker
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.selectedRoundMatches, id: \.id) { match in
                            FixtureMatchCard(match: match)
                        }
                    }
                    .padding(16)
                }
                .scrollContentBackground(.hidden)
            }
            .background(StadiumBackground())
            .navigationTitle("Fixtures")
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.load() }
        }
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
            .foregroundStyle(isSelected ? .white : .white.opacity(0.55))
            .frame(width: 60, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color.white.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .id(round)
    }
}
