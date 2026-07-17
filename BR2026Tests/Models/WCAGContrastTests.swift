// BR2026Tests/Models/WCAGContrastTests.swift
import Testing
@testable import BR2026

@Suite("WCAGContrast")
struct WCAGContrastTests {
    @Test("Pure black vs. pure white is the maximum possible contrast ratio, 21:1")
    func blackWhiteIsMaximumContrast() {
        let ratio = WCAGContrast.contrastRatio("000000", "FFFFFF")
        #expect(abs(ratio - 21.0) < 0.01)
    }

    @Test("Identical colors have the minimum possible contrast ratio, 1:1")
    func identicalColorsAreMinimumContrast() {
        #expect(abs(WCAGContrast.contrastRatio("2B2B2E", "2B2B2E") - 1.0) < 0.01)
        #expect(abs(WCAGContrast.contrastRatio("FFFFFF", "FFFFFF") - 1.0) < 0.01)
    }

    @Test("contrastRatio is symmetric regardless of argument order")
    func contrastRatioIsSymmetric() {
        let a = WCAGContrast.contrastRatio("061325", "F2F2F2")
        let b = WCAGContrast.contrastRatio("F2F2F2", "061325")
        #expect(abs(a - b) < 0.0001)
    }

    @Test("Off-white F2F2F2 against the app's fixed dark background passes WCAG AA (>= 4.5)")
    func offWhiteAgainstFixedDarkBackgroundPasses() {
        #expect(WCAGContrast.contrastRatio("F2F2F2", "061325") >= 4.5)
    }

    @Test("Pure black against the app's fixed dark background fails WCAG AA — this is the exact bug Corinthians' original API font color (000000) would have shipped with")
    func blackAgainstFixedDarkBackgroundFails() {
        #expect(WCAGContrast.contrastRatio("000000", "061325") < 4.5)
    }

    @Test("relativeLuminance of pure black is 0 and pure white is 1")
    func relativeLuminanceOfBlackAndWhite() {
        #expect(abs(WCAGContrast.relativeLuminance(hex: "000000") - 0.0) < 0.0001)
        #expect(abs(WCAGContrast.relativeLuminance(hex: "FFFFFF") - 1.0) < 0.0001)
    }
}
