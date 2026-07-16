import Foundation
import Observation

@Observable
@MainActor
final class MoreViewModel {
    private(set) var competitionName: String?
    private(set) var competitionLogoURL: URL?
    private(set) var competitionLogoData: Data?
    let sections: [MoreSection] = [
        MoreSection(
            id: "preferences",
            titleKey: "Preferences",
            rows: MoreViewModel.preferencesRows
        ),
        MoreSection(
            id: "legal",
            titleKey: "Legal",
            rows: [
                MoreRow(
                    id: "termsOfService",
                    titleKey: "Terms of Service",
                    systemImage: "doc.text",
                    destination: .termsOfService,
                    isEnabled: true
                )
            ]
        )
    ]

    // Team Theme is Brasileirão-only - see `TeamThemeOption`'s own comment for
    // why the *type* itself isn't per-target #if-gated; this is the actual gate other
    // championship targets rely on to never show the row.
    private static var preferencesRows: [MoreRow] {
        var rows = [
            MoreRow(
                id: "appIcon",
                titleKey: "App Icon",
                systemImage: "app.badge",
                destination: .appIconPicker,
                isEnabled: true
            )
        ]
        #if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA || TARGET_SCOTTISH_PREMIERSHIP || TARGET_LA_LIGA)
        rows.append(
            MoreRow(
                id: "teamTheme",
                titleKey: "Team Theme",
                systemImage: "paintpalette",
                destination: .teamThemePicker,
                isEnabled: true
            )
        )
        #endif
        return rows
    }
    private nonisolated(unsafe) let service: MatchService

    init(service: MatchService) {
        self.service = service
    }

    private static let refreshInterval: TimeInterval = 7 * 24 * 60 * 60
    private var hasLoadedOnce = false

    func loadOnce() async {
        guard !hasLoadedOnce else { return }
        hasLoadedOnce = true
        await load()
    }

    func load() async {
        if let cached = service.cachedCompetition() {
            apply(cached)
            guard Date().timeIntervalSince(cached.cachedAt) > Self.refreshInterval else { return }
        }
        if let fresh = try? await service.fetchCompetition() {
            apply(fresh)
        }
    }

    private func apply(_ competition: Competition) {
        competitionName = competition.name
        competitionLogoURL = competition.logoURL
        competitionLogoData = competition.logoData
    }
}
