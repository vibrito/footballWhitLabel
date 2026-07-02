import SwiftUI

struct TeamCrestBadge: View {
    let team: Team
    var size: CGFloat = 32

    var body: some View {
        AsyncImage(url: team.crestURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFit()
            default:
                placeholder
            }
        }
        .frame(width: size, height: size)
    }

    private var placeholder: some View {
        Circle()
            .fill(.white.opacity(0.07))
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
            )
    }

    private var initials: String {
        String(team.displayName.prefix(2)).uppercased()
    }
}
