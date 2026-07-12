import Testing
import Foundation
@testable import BR2026

@Suite("MoreViewModel")
@MainActor
struct MoreViewModelTests {
    @Test("Legal section has one enabled Terms of Service row")
    func legalSection() {
        let viewModel = MoreViewModel(service: StubMatchService(matches: [], standings: []))
        let legal = viewModel.sections.first { $0.id == "legal" }
        #expect(legal?.rows.count == 1)
        #expect(legal?.rows.first?.destination == .termsOfService)
        #expect(legal?.rows.first?.isEnabled == true)
    }

    @Test("Preferences section has one disabled, destination-less row")
    func preferencesSection() {
        let viewModel = MoreViewModel(service: StubMatchService(matches: [], standings: []))
        let preferences = viewModel.sections.first { $0.id == "preferences" }
        #expect(preferences?.rows.count == 1)
        #expect(preferences?.rows.allSatisfy { $0.destination == nil && !$0.isEnabled } == true)
    }

    @Test("loadCompetition() populates the competition name and logo URL")
    func loadCompetitionPopulatesNameAndLogo() async {
        let competition = Competition(
            code: "BSA", name: "Campeonato Brasileiro Série A", season: 2026,
            logoURL: URL(string: "https://media.api-sports.io/football/leagues/71.png")!
        )
        let service = StubMatchService(matches: [], standings: [], competition: competition)
        let viewModel = MoreViewModel(service: service)

        await viewModel.loadCompetition()

        #expect(viewModel.competitionName == "Campeonato Brasileiro Série A")
        #expect(viewModel.competitionLogoURL == competition.logoURL)
    }
}
