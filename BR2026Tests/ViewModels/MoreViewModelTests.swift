import Testing
@testable import BR2026

@Suite("MoreViewModel")
struct MoreViewModelTests {
    @Test("Legal section has one enabled Terms of Service row")
    func legalSection() {
        let viewModel = MoreViewModel()
        let legal = viewModel.sections.first { $0.id == "legal" }
        #expect(legal?.rows.count == 1)
        #expect(legal?.rows.first?.destination == .termsOfService)
        #expect(legal?.rows.first?.isEnabled == true)
    }

    @Test("Preferences section has one disabled, destination-less row")
    func preferencesSection() {
        let viewModel = MoreViewModel()
        let preferences = viewModel.sections.first { $0.id == "preferences" }
        #expect(preferences?.rows.count == 1)
        #expect(preferences?.rows.allSatisfy { $0.destination == nil && !$0.isEnabled } == true)
    }
}
