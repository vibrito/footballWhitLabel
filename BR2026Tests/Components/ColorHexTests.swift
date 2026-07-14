import Testing
import SwiftUI
@testable import BR2026

@Suite("Color hex shading")
struct ColorHexTests {
    private func components(_ color: Color) -> (Double, Double, Double) {
        let resolved = color.resolve(in: EnvironmentValues())
        return (Double(resolved.red), Double(resolved.green), Double(resolved.blue))
    }

    @Test("towardWhite: 0 returns the color unchanged")
    func zeroAmountIsUnchanged() {
        let original = components(Color(hex: "225638"))
        let shaded = components(Color.shaded(hex: "225638", towardWhite: 0))
        #expect(abs(original.0 - shaded.0) < 0.001)
        #expect(abs(original.1 - shaded.1) < 0.001)
        #expect(abs(original.2 - shaded.2) < 0.001)
    }

    @Test("towardWhite: 1 returns pure white")
    func fullPositiveAmountIsWhite() {
        let (r, g, b) = components(Color.shaded(hex: "225638", towardWhite: 1))
        #expect(abs(r - 1) < 0.001)
        #expect(abs(g - 1) < 0.001)
        #expect(abs(b - 1) < 0.001)
    }

    @Test("towardWhite: -1 returns pure black")
    func fullNegativeAmountIsBlack() {
        let (r, g, b) = components(Color.shaded(hex: "225638", towardWhite: -1))
        #expect(abs(r - 0) < 0.001)
        #expect(abs(g - 0) < 0.001)
        #expect(abs(b - 0) < 0.001)
    }
}
