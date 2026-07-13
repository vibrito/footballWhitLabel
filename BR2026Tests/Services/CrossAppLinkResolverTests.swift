import Foundation
import Testing
@testable import BR2026

@Suite("CrossAppLinkResolver")
@MainActor
struct CrossAppLinkResolverTests {
    @Test("Resolves to the custom scheme URL when the sibling app is installed")
    func resolvesToCustomSchemeWhenInstalled() {
        let checker = StubURLOpenabilityChecker(canOpenResult: true)
        let url = CrossAppLinkResolver.url(for: .premierLeague, using: checker)
        #expect(url == CrossAppLink.premierLeague.customSchemeURL)
    }

    @Test("Falls back to the App Store URL when the sibling app is not installed")
    func fallsBackToAppStoreWhenNotInstalled() {
        let checker = StubURLOpenabilityChecker(canOpenResult: false)
        let url = CrossAppLinkResolver.url(for: .premierLeague, using: checker)
        #expect(url == CrossAppLink.premierLeague.appStoreURL)
    }
}

@MainActor
final class StubURLOpenabilityChecker: URLOpenabilityChecking {
    let canOpenResult: Bool

    init(canOpenResult: Bool) {
        self.canOpenResult = canOpenResult
    }

    func canOpen(_ url: URL) -> Bool { canOpenResult }
}
