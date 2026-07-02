import SwiftUI

struct MoreView: View {
    let config: ChampionshipConfig

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.55))
                Text(config.displayName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Text("More settings coming soon")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(StadiumBackground())
            .navigationTitle("More")
        }
    }
}
