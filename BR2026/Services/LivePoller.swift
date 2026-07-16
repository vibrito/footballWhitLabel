import Foundation

// @MainActor because every current caller (MatchdayViewModel, FixturesViewModel,
// MatchDetailViewModel) is itself @MainActor-isolated — avoids any ambiguity about which
// actor the shouldContinue/action closures run on.
@MainActor
enum LivePoller {
    static func run(interval: Duration, shouldContinue: () -> Bool, action: () async -> Void) async {
        while !Task.isCancelled && shouldContinue() {
            try? await Task.sleep(for: interval)
            guard !Task.isCancelled && shouldContinue() else { break }
            await action()
        }
    }
}
