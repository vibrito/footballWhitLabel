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

    // The App Icon row is always present. The Team Theme row is additionally gated behind
    // both this being the Brasileirão target and FeatureFlags.iapEnabled — so this mirrors
    // production's exact condition rather than hard-coding a row count that a flag flip
    // (or a different target) would silently invalidate.
    @Test("Preferences section always has App Icon, and Team Theme only when enabled")
    func preferencesSection() {
        let viewModel = MoreViewModel(service: StubMatchService(matches: [], standings: []))
        let preferences = viewModel.sections.first { $0.id == "preferences" }
        let destinations = preferences?.rows.map(\.destination) ?? []

        #expect(destinations.contains(.appIconPicker))
        #expect(preferences?.rows.allSatisfy { $0.isEnabled } == true)

        #if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA || TARGET_SCOTTISH_PREMIERSHIP || TARGET_LA_LIGA)
        let expectsTeamTheme = FeatureFlags.iapEnabled
        #else
        let expectsTeamTheme = false
        #endif

        if expectsTeamTheme {
            #expect(preferences?.rows.count == 2)
            #expect(destinations.contains(.teamThemePicker))
        } else {
            #expect(destinations == [.appIconPicker])
        }
    }

    @Test("load() shows a fresh cached competition immediately, with no network fetch")
    func loadWithFreshCacheSkipsFetch() async {
        let cached = Competition(
            code: "BSA", name: "Cached Name", season: 2026,
            logoURL: URL(string: "https://example.com/cached-logo.png")!,
            logoData: Data([0x01, 0x02]),
            cachedAt: Date()
        )
        let service = StubMatchService(matches: [], standings: [])
        service.cachedCompetitionOverride = cached
        let viewModel = MoreViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.competitionName == "Cached Name")
        #expect(viewModel.competitionLogoData == Data([0x01, 0x02]))
        #expect(service.fetchCompetitionCallCount == 0)
    }

    @Test("load() shows a stale cached competition immediately, then refreshes in the background")
    func loadWithStaleCacheStillFetches() async {
        let eightDaysAgo = Date().addingTimeInterval(-8 * 24 * 60 * 60)
        let cached = Competition(
            code: "BSA", name: "Stale Name", season: 2026,
            logoURL: URL(string: "https://example.com/stale-logo.png")!,
            logoData: Data([0x01]),
            cachedAt: eightDaysAgo
        )
        let freshCompetition = Competition(
            code: "BSA", name: "Fresh Name", season: 2026,
            logoURL: URL(string: "https://example.com/fresh-logo.png")!
        )
        let service = StubMatchService(matches: [], standings: [], competition: freshCompetition)
        service.cachedCompetitionOverride = cached
        let viewModel = MoreViewModel(service: service)

        await viewModel.load()

        #expect(service.fetchCompetitionCallCount == 1)
        #expect(viewModel.competitionName == "Fresh Name")
    }

    @Test("load() fetches immediately when there is no cached competition")
    func loadWithNoCacheFetchesImmediately() async {
        let competition = Competition(
            code: "BSA", name: "Campeonato Brasileiro Série A", season: 2026,
            logoURL: URL(string: "https://media.api-sports.io/football/leagues/71.png")!
        )
        let service = StubMatchService(matches: [], standings: [], competition: competition)
        let viewModel = MoreViewModel(service: service)

        await viewModel.load()

        #expect(service.fetchCompetitionCallCount == 1)
        #expect(viewModel.competitionName == "Campeonato Brasileiro Série A")
        #expect(viewModel.competitionLogoURL == competition.logoURL)
    }
}
