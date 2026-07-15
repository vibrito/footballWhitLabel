import SwiftUI

struct ContentView: View {
    let config: ChampionshipConfig
    let service: MatchService
    let themeStore: TeamThemeStore
    let themePurchaseStore: PurchaseStore<TeamThemeOption>
    let iconPurchaseStore: PurchaseStore<TeamIconOption>

    var body: some View {
        TabView {
            MatchdayView(service: service, themeStore: themeStore)
                .tabItem { Label("Matchday", systemImage: "soccerball") }
                .tint(themeStore.tokens.overrideAccentColor ?? Color(hex: config.accentColorHex))
            FixturesView(service: service)
                .tabItem { Label("Fixtures", systemImage: "calendar") }
                .tint(themeStore.tokens.overrideAccentColor ?? Color(hex: config.accentColorHex))
            StandingsView(service: service)
                .tabItem { Label("Standings", systemImage: "chart.bar") }
                .tint(themeStore.tokens.overrideAccentColor ?? Color(hex: config.accentColorHex))
            MoreView(service: service, themeStore: themeStore, themePurchaseStore: themePurchaseStore, iconPurchaseStore: iconPurchaseStore)
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
                .tint(themeStore.tokens.overrideAccentColor ?? Color(hex: config.accentColorHex))
        }
        // Governs only the tab bar's own selected-item chrome; each tab's content above
        // re-applies the true brand accent so LiveChip/AccentPill etc. stay brand-colored.
        .tint(themeStore.tokens.overrideTabSelectionColor ?? themeStore.tokens.overrideAccentColor ?? Color(hex: config.tabSelectionColorHex))
        .background(StadiumBackground())
        .environment(\.themeTokens, themeStore.tokens)
        .task { await themeStore.loadOnce() }
        .task { await themePurchaseStore.loadOnce() }
        .task { await iconPurchaseStore.loadOnce() }
    }
}
