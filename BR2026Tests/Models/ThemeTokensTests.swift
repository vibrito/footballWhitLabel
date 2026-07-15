import Testing
import SwiftUI
@testable import BR2026

@Suite("ThemeTokens")
struct ThemeTokensTests {
    @Test("Default tokens have no accent override, white text, and today's fixed gradient/blob colors")
    func defaultsMatchTodaysFixedLook() {
        let tokens = ThemeTokens()
        #expect(tokens.overrideAccentColor == nil)
        #expect(tokens.textColor == .white)
        #expect(tokens.gradientStops == ThemeTokens.defaultGradientStops)
        #expect(tokens.blobColors.top == ThemeTokens.defaultBlobColors.top)
        #expect(tokens.blobColors.bottom == ThemeTokens.defaultBlobColors.bottom)
    }

    @Test("themed(mainColorHex:fontColorHex:) sets a non-nil accent, the given text color, and both blobs to the main color")
    func themedFactoryBuildsActiveTokens() {
        let tokens = ThemeTokens.themed(mainColorHex: "225638", fontColorHex: "ffffff")
        #expect(tokens.overrideAccentColor == Color(hex: "225638"))
        #expect(tokens.textColor == Color(hex: "ffffff"))
        #expect(tokens.blobColors.top == Color(hex: "225638"))
        #expect(tokens.blobColors.bottom == Color(hex: "225638"))
        #expect(tokens.gradientStops.count == 3)
    }

    @Test("The environment default value is today's fixed ThemeTokens")
    func environmentDefaultValue() {
        #expect(EnvironmentValues().themeTokens == ThemeTokens())
    }
}
