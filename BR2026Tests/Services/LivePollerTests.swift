import Testing
@testable import BR2026

@Suite("LivePoller")
@MainActor
struct LivePollerTests {
    @Test("does not call action when shouldContinue is false from the start")
    func neverCallsActionWhenShouldContinueIsFalse() async {
        var actionCallCount = 0

        await LivePoller.run(interval: .seconds(30), shouldContinue: { false }, action: { actionCallCount += 1 })

        #expect(actionCallCount == 0)
    }
}
