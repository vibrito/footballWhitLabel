import SwiftUI

struct ContentView: View {
    let config: ChampionshipConfig
    let service: MatchService

    var body: some View {
        TabView {
            MatchdayView(service: service)
                .tabItem { Label("Matchday", systemImage: "soccerball") }
            FixturesView(service: service)
                .tabItem { Label("Fixtures", systemImage: "calendar") }
            StandingsView(service: service)
                .tabItem { Label("Standings", systemImage: "chart.bar") }
            MoreView(service: service)
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
        }
        .tint(Color(hex: config.accentColorHex))
        .background(StadiumBackground())
    }
}
