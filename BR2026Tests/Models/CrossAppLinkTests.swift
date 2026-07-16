import Testing
@testable import BR2026

@Suite("CrossAppLink")
struct CrossAppLinkTests {
    @Test("siblings(excluding:) returns the other 4 apps, not the current one")
    func siblingsExcludesCurrentApp() {
        let siblings = CrossAppLink.siblings(excluding: "premier-league")
        #expect(siblings.count == 4)
        #expect(!siblings.contains { $0.id == "premier-league" })
        #expect(siblings.contains { $0.id == "brasileirao" })
        #expect(siblings.contains { $0.id == "ligue-1" })
        #expect(siblings.contains { $0.id == "primeira-liga" })
        #expect(siblings.contains { $0.id == "scottish-premiership" })
    }

    @Test("customSchemeURL and appStoreURL are built from the link's own fields")
    func urlsAreBuiltCorrectly() {
        let link = CrossAppLink.ligue1
        #expect(link.customSchemeURL.absoluteString == "ligue12026://")
        #expect(link.appStoreURL.absoluteString == "https://apps.apple.com/app/id0000000000")
    }
}
