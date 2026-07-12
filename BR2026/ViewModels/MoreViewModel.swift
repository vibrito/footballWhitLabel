import Foundation
import Observation

@Observable
@MainActor
final class MoreViewModel {
    private(set) var competitionName: String?
    private(set) var competitionLogoURL: URL?
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

    func loadCompetition() async {
        guard let competition = try? await service.fetchCompetition() else { return }
        competitionName = competition.name
        competitionLogoURL = competition.logoURL
    }
}
