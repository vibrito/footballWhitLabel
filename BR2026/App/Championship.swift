import SwiftUI
import SwiftData

@main
struct ChampionshipApp: App {
    let config = ChampionshipConfig.brasileirao
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: Match.self, Standing.self)
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(config: config, service: makeService())
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }

    private func makeService() -> MatchService {
        // Falls back to mock data if Secrets.xcconfig hasn't been set up yet, so the app
        // still runs in Simulator before a real API key is configured. This also covers
        // fastlane's `screenshots` lane — screenshots are captured against the real API.
        let context = ModelContext(modelContainer)
        if let live = try? LiveMatchService.makeFromBundle(config: config, modelContext: context) {
            return live
        }
        return MockMatchService()
    }
}
