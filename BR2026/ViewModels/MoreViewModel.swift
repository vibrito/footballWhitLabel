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
        ),
        MoreSection(
            id: "preferences",
            titleKey: "Preferences",
            rows: [
                MoreRow(
                    id: "appIcon",
                    titleKey: "App Icon",
                    systemImage: "app.badge",
                    destination: .appIconPicker,
                    isEnabled: true
                )
            ]
        )
    ]
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
