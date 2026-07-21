import SwiftUI
import SwiftData
import UIKit

struct TeamCrestBadge: View {
    let team: Team
    var size: CGFloat = 32
    // Overlays the team's initials on the color ball. Off by default (the team name is
    // usually shown right beside the badge); enabled only where the ball is large enough to
    // carry them legibly, e.g. the Matchday hero card.
    var showsInitials: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeTokens) private var themeTokens
    @Environment(\.matchService) private var matchService
    @State private var imageData: Data?
    // The team's kit colors (1–3), used to paint the placeholder ball when crests are
    // hidden — a curated palette when one exists, otherwise the distinct API kit colors.
    // `nil` until loaded / when unavailable.
    @State private var kitColorHexes: [String]?
    @ScaledMetric private var initialsFontSize: CGFloat

    init(team: Team, size: CGFloat = 32, showsInitials: Bool = false) {
        self.team = team
        self.size = size
        self.showsInitials = showsInitials
        self._initialsFontSize = ScaledMetric(wrappedValue: size * 0.32)
    }

    var body: some View {
        Group {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .task(id: team.id) {
            if FeatureFlags.showsRemoteCrests {
                await loadCrest()
            } else {
                await loadKitColors()
            }
        }
        .accessibilityHidden(true)
    }

    private func loadCrest() async {
        guard let url = team.crestURL else { return }
        let store = TeamCrestCacheStore(modelContext: modelContext)
        if let cached = store.cachedImageData(forTeamID: team.id, matching: url) {
            imageData = cached
            return
        }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return
        }
        imageData = data
        store.store(data, forTeamID: team.id, url: url)
    }

    private func loadKitColors() async {
        // A curated palette wins over the live API, which is often wrong or incomplete for
        // the clubs listed in TeamCrestPalette — and needs no network fetch.
        if let curated = TeamCrestPalette.hexes(forTeamID: team.id) {
            kitColorHexes = curated
            return
        }
        guard let matchService else { return }
        if let cached = matchService.cachedTeamThemeColorSet(teamID: team.id) {
            kitColorHexes = Self.distinctMainHexes(cached)
            return
        }
        if let fetched = try? await matchService.fetchTeamThemeColorSet(teamID: team.id) {
            kitColorHexes = Self.distinctMainHexes(fetched)
        }
    }

    /// The distinct home/away/third kit main colors, in that order, capped at three — the
    /// palette painted into the placeholder ball. Deduped case-insensitively so a team whose
    /// away kit repeats its home color doesn't render a "two-color" ball of one color.
    private static func distinctMainHexes(_ set: TeamThemeColorSet) -> [String] {
        var result: [String] = []
        for kit in [Optional(set.home), set.away, set.third] {
            guard let hex = kit?.mainColorHex else { continue }
            if !result.contains(where: { $0.caseInsensitiveCompare(hex) == .orderedSame }) {
                result.append(hex)
            }
        }
        return Array(result.prefix(3))
    }

    @ViewBuilder
    private var placeholder: some View {
        if let hexes = kitColorHexes, !hexes.isEmpty {
            colorBall(hexes.map { Color(hex: $0) })
        } else {
            Circle().fill(.white.opacity(0.07))
        }
    }

    // A colored ball standing in for the (unlicensed) club crest: two colors split
    // diagonally, three colors as vertical stripes, one color solid.
    private func colorBall(_ colors: [Color]) -> some View {
        Group {
            switch colors.count {
            case 1:
                colors[0]
            case 2:
                DiagonalSplit(top: colors[0], bottom: colors[1])
            default:
                HStack(spacing: 0) {
                    ForEach(Array(colors.prefix(3).enumerated()), id: \.offset) { _, color in
                        color
                    }
                }
            }
        }
        .clipShape(Circle())
        .overlay {
            if showsInitials {
                Text(initials)
                    .font(.system(size: initialsFontSize, weight: .heavy))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.55), radius: 2)
            }
        }
    }

    private var initials: String {
        String(team.displayName.prefix(2)).uppercased()
    }
}

/// A square split along its top-left → bottom-right diagonal: `top` fills the upper-right
/// triangle, `bottom` the lower-left. Clipped to a circle by the caller.
private struct DiagonalSplit: View {
    let top: Color
    let bottom: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                bottom
                Path { path in
                    path.move(to: .zero)
                    path.addLine(to: CGPoint(x: w, y: 0))
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.closeSubpath()
                }
                .fill(top)
            }
        }
    }
}
