import Testing

@Suite("Scaffold smoke test")
struct ChampionshipTests {
    @Test("Test target links and runs")
    func testTargetLinks() {
        #expect(1 + 1 == 2)
    }
}
