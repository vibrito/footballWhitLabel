import SwiftUI
import SwiftData

@main
struct ChampionshipApp: App {
    let config = ChampionshipConfig.brasileirao
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: Match.self)
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

    static func shouldUseMockService(environment: [String: String]) -> Bool {
        environment["FASTLANE_SNAPSHOT"] == "YES"
    }

    private func makeService() -> MatchService {
        // fastlane's `snapshot` action sets FASTLANE_SNAPSHOT=YES in the launch environment;
        // screenshots must use fixed mock data regardless of the live season/API state.
        if Self.shouldUseMockService(environment: ProcessInfo.processInfo.environment) {
            return MockMatchService()
        }
        // Falls back to mock data if Secrets.xcconfig hasn't been set up yet, so the app
        // still runs in Simulator before a real API key is configured.
        let context = ModelContext(modelContainer)
        if let live = try? LiveMatchService.makeFromBundle(config: config, modelContext: context) {
            return live
        }
        return MockMatchService()
    }
}
