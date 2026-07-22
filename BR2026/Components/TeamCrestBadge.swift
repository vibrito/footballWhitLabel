import SwiftUI
import SwiftData
import UIKit

struct TeamCrestBadge: View {
    let team: Team
    var size: CGFloat = 32

    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeTokens) private var themeTokens
    @State private var imageData: Data?
    // Seeded (not a static default) since it's derived from the caller-supplied `size`
    // parameter, not a fixed literal — still responsive to Dynamic Type via the normal
    // @ScaledMetric mechanism, just initialized proportionally instead of with a constant.
    @ScaledMetric private var initialsFontSize: CGFloat

    init(team: Team, size: CGFloat = 32) {
        self.team = team
        self.size = size
        self._initialsFontSize = ScaledMetric(wrappedValue: size * 0.4)
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
        .task(id: team.crestURL) {
            // Real club crests are hidden (see FeatureFlags.showsRemoteCrests) — the
            // initials placeholder stands in for every team.
            guard FeatureFlags.showsRemoteCrests else { return }
            await loadCrest()
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

    @ViewBuilder
    private var placeholder: some View {
        if let symbol = TeamCrestSymbols.symbol(forTeamID: team.id) {
            symbolBall(symbol)
        } else {
            Circle()
                .fill(.white.opacity(0.07))
                .overlay(
                    Text(initials)
                        .font(.system(size: initialsFontSize, weight: .bold))
                        .foregroundStyle(themeTokens.textColor)
                )
        }
    }

    // A curated jersey-style ball standing in for the club crest — no lettering, just the
    // club's colors in its pattern, styled like a glossy "futebol de botão" disc.
    private func symbolBall(_ symbol: TeamCrestSymbol) -> some View {
        symbolPattern(symbol)
            .frame(width: size, height: size)
            .clipShape(Circle())
        // Convex shading: darken toward the lower-right so the disc reads as domed, not flat.
        .overlay(
            Circle().fill(
                RadialGradient(
                    colors: [.clear, .black.opacity(0.38)],
                    center: UnitPoint(x: 0.36, y: 0.32),
                    startRadius: size * 0.08,
                    endRadius: size * 0.62
                )
            )
        )
        // Glossy specular highlight, upper-left, like light hitting a polished button.
        .overlay(
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.65), .clear],
                        center: .center, startRadius: 0, endRadius: size * 0.26
                    )
                )
                .frame(width: size * 0.5, height: size * 0.36)
                .offset(x: -size * 0.13, y: -size * 0.17)
                .blur(radius: size * 0.015)
        )
        // Beveled rim: light at the top, dark at the bottom.
        .overlay(
            Circle().strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.55), .black.opacity(0.35)],
                    startPoint: .top, endPoint: .bottom
                ),
                lineWidth: max(1, size * 0.035)
            )
        )
        // Drop shadow so the disc sits above the surface.
        .shadow(color: .black.opacity(0.45), radius: size * 0.05, x: 0, y: size * 0.045)
    }

    @ViewBuilder
    private func symbolPattern(_ symbol: TeamCrestSymbol) -> some View {
        switch symbol {
        case .verticalStripes(let bands):
            let total = bands.reduce(0) { $0 + $1.weight }
            HStack(spacing: 0) {
                ForEach(Array(bands.enumerated()), id: \.offset) { _, band in
                    Color(hex: band.hex)
                        .frame(width: size * band.weight / max(total, 1))
                }
            }
        case .horizontalStripes(let bands):
            let total = bands.reduce(0) { $0 + $1.weight }
            VStack(spacing: 0) {
                ForEach(Array(bands.enumerated()), id: \.offset) { _, band in
                    Color(hex: band.hex)
                        .frame(height: size * band.weight / max(total, 1))
                }
            }
        case .concentric(let bands):
            let total = bands.reduce(0) { $0 + $1.weight }
            // Draw outer→inner so each smaller circle sits on top. A band's circle spans the
            // radius from the centre out to the sum of its own and all inner bands' weights.
            ZStack {
                ForEach(Array(bands.enumerated()), id: \.offset) { index, band in
                    let innerWeight = bands[index...].reduce(0) { $0 + $1.weight }
                    Circle()
                        .fill(Color(hex: band.hex))
                        .frame(width: size * innerWeight / max(total, 1))
                }
            }
        }
    }

    private var initials: String {
        String(team.displayName.prefix(2)).uppercased()
    }
}
