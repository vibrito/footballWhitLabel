import UIKit

@MainActor
protocol URLOpenabilityChecking {
    func canOpen(_ url: URL) -> Bool
}

@MainActor
final class UIKitURLOpenabilityChecker: URLOpenabilityChecking {
    func canOpen(_ url: URL) -> Bool {
        UIApplication.shared.canOpenURL(url)
    }
}

/// Decides which URL to open for a sibling app: its custom scheme if installed,
/// otherwise its App Store listing. Not yet wired into any View — see
/// `docs/superpowers/specs/2026-07-13-multi-championship-expansion-design.md`.
@MainActor
enum CrossAppLinkResolver {
    static func url(for link: CrossAppLink, using checker: URLOpenabilityChecking) -> URL {
        checker.canOpen(link.customSchemeURL) ? link.customSchemeURL : link.appStoreURL
    }
}
