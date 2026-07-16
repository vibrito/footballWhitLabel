import SwiftUI
import SwiftData

@main
struct ChampionshipApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #if TARGET_PREMIER_LEAGUE
    let config = ChampionshipConfig.premierLeague
    #elseif TARGET_LIGUE_1
    let config = ChampionshipConfig.ligue1
    #elseif TARGET_PRIMEIRA_LIGA
    let config = ChampionshipConfig.primeiraLiga
    #elseif TARGET_SCOTTISH_PREMIERSHIP
    let config = ChampionshipConfig.scottishPremiership
    #elseif TARGET_LA_LIGA
    let config = ChampionshipConfig.laLiga
    #else
    let config = ChampionshipConfig.brasileirao
    #endif
    let modelContainer: ModelContainer
    let service: MatchService
    let themeStore: TeamThemeStore
    let themePurchaseStore: PurchaseStore<TeamThemeOption>
    let iconPurchaseStore: PurchaseStore<TeamIconOption>

    init() {
        do {
            modelContainer = try ModelContainer(
                for: Match.self, Standing.self, Competition.self, TeamCrestCache.self, TeamThemeColorCache.self
            )
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }
        // Falls back to mock data if Secrets.xcconfig hasn't been set up yet, so the app
        // still runs in Simulator before a real API key is configured. This also covers
        // fastlane's `screenshots` lane — screenshots are captured against the real API.
        let context = ModelContext(modelContainer)
        if let live = try? LiveMatchService.makeFromBundle(config: config, modelContext: context) {
            service = live
        } else {
            service = MockMatchService()
        }
        themeStore = TeamThemeStore(setting: UserDefaultsTeamThemeSetting(), service: service)
        let purchaseService = LivePurchaseService()
        themePurchaseStore = PurchaseStore<TeamThemeOption>(service: purchaseService)
        iconPurchaseStore = PurchaseStore<TeamIconOption>(service: purchaseService)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(config: config, service: service, themeStore: themeStore, themePurchaseStore: themePurchaseStore, iconPurchaseStore: iconPurchaseStore)
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }
}
