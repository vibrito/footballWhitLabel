import SwiftUI

/// Makes the app's `MatchService` reachable from deep, service-less components — currently
/// only `TeamCrestBadge`, which loads a team's kit colors on its own the same way it used to
/// self-load crest images. `nil` default so previews and any host without a service simply
/// skip color loading and fall back to the plain initials placeholder.
private struct MatchServiceKey: EnvironmentKey {
    // The default is a constant `nil`, so there is no shared mutable state to protect — the
    // `nonisolated(unsafe)` just opts this immutable nil out of Swift 6's Sendable check,
    // since `MatchService` (a protocol) isn't itself Sendable.
    nonisolated(unsafe) static let defaultValue: MatchService? = nil
}

extension EnvironmentValues {
    var matchService: MatchService? {
        get { self[MatchServiceKey.self] }
        set { self[MatchServiceKey.self] = newValue }
    }
}
