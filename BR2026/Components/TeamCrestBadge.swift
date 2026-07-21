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

    private var placeholder: some View {
        Circle()
            .fill(.white.opacity(0.07))
            .overlay(
                Text(initials)
                    .font(.system(size: initialsFontSize, weight: .bold))
                    .foregroundStyle(themeTokens.textColor.opacity(0.55))
            )
    }

    private var initials: String {
        String(team.displayName.prefix(2)).uppercased()
    }
}
