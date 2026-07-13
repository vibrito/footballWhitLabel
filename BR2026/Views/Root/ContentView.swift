import SwiftUI

struct ContentView: View {
    let config: ChampionshipConfig
    let service: MatchService

    var body: some View {
        TabView {
            MatchdayView(service: service)
                .tabItem { Label("Matchday", systemImage: "soccerball") }
                .tint(Color(hex: config.accentColorHex))
            FixturesView(service: service)
                .tabItem { Label("Fixtures", systemImage: "calendar") }
                .tint(Color(hex: config.accentColorHex))
            StandingsView(service: service)
                .tabItem { Label("Standings", systemImage: "chart.bar") }
                .tint(Color(hex: config.accentColorHex))
            MoreView(service: service)
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
                .tint(Color(hex: config.accentColorHex))
        }
        // Governs only the tab bar's own selected-item chrome; each tab's content above
        // re-applies the true brand accent so LiveChip/AccentPill etc. stay brand-colored.
        .tint(Color(hex: config.tabSelectionColorHex))
        .background(StadiumBackground())
    }
}
