import Testing
import SwiftUI
@testable import BR2026

@Suite("ThemeTokens")
struct ThemeTokensTests {
    @Test("Default tokens have no accent override, white text, and today's fixed gradient/blob colors")
    func defaultsMatchTodaysFixedLook() {
        let tokens = ThemeTokens()
        #expect(tokens.overrideAccentColor == nil)
        #expect(tokens.overrideTabSelectionColor == nil)
        #expect(tokens.overridePillFillColor == nil)
        #expect(tokens.usesDiagonalSashBackground == false)
        #expect(tokens.textColor == .white)
        #expect(tokens.gradientStops == ThemeTokens.defaultGradientStops)
        #expect(tokens.blobColors.top == ThemeTokens.defaultBlobColors.top)
        #expect(tokens.blobColors.bottom == ThemeTokens.defaultBlobColors.bottom)
    }

    @Test("themed(mainColorHex:fontColorHex:) sets a non-nil accent, no tab selection/pill fill override by default, the given text color, and both blobs to the main color")
    func themedFactoryBuildsActiveTokens() {
        let tokens = ThemeTokens.themed(mainColorHex: "225638", fontColorHex: "ffffff")
        #expect(tokens.overrideAccentColor == Color(hex: "225638"))
        #expect(tokens.overrideTabSelectionColor == nil)
        #expect(tokens.overridePillFillColor == nil)
        #expect(tokens.textColor == Color(hex: "ffffff"))
        #expect(tokens.blobColors.top == Color(hex: "225638"))
        #expect(tokens.blobColors.bottom == Color(hex: "225638"))
        #expect(tokens.gradientStops.count == 3)
    }

    @Test("tabSelectionColorHex sets a distinct overrideTabSelectionColor, independent of the main accent")
    func tabSelectionColorHexIsIndependent() {
        let tokens = ThemeTokens.themed(mainColorHex: "870A28", fontColorHex: "ffffff", tabSelectionColorHex: "00613C")
        #expect(tokens.overrideAccentColor == Color(hex: "870A28"))
        #expect(tokens.overrideTabSelectionColor == Color(hex: "00613C"))
        #expect(tokens.overrideAccentColor != tokens.overrideTabSelectionColor)
    }

    @Test("pillFillColorHex sets a distinct overridePillFillColor, independent of the tab selection color")
    func pillFillColorHexIsIndependent() {
        let tokens = ThemeTokens.themed(
            mainColorHex: "2B2B2E",
            fontColorHex: "ffffff",
            tabSelectionColorHex: "FFFFFF",
            pillFillColorHex: "2B2B2E"
        )
        #expect(tokens.overrideTabSelectionColor == Color(hex: "FFFFFF"))
        #expect(tokens.overridePillFillColor == Color(hex: "2B2B2E"))
        #expect(tokens.overrideTabSelectionColor != tokens.overridePillFillColor)
    }

    @Test("gradientDarkAmount defaults to -0.75 but can be overridden to lighten the bottom gradient stop")
    func gradientDarkAmountIsConfigurable() {
        let defaultTokens = ThemeTokens.themed(mainColorHex: "2F529E", fontColorHex: "ffffff")
        let lightenedTokens = ThemeTokens.themed(mainColorHex: "2F529E", fontColorHex: "ffffff", gradientDarkAmount: -0.5)

        #expect(defaultTokens.gradientStops[2] == Color.shaded(hex: "2F529E", towardWhite: -0.75))
        #expect(lightenedTokens.gradientStops[2] == Color.shaded(hex: "2F529E", towardWhite: -0.5))
        #expect(defaultTokens.gradientStops[2] != lightenedTokens.gradientStops[2])
    }

    @Test("usesDiagonalSashBackground defaults to false but can be set true")
    func usesDiagonalSashBackgroundIsConfigurable() {
        let defaultTokens = ThemeTokens.themed(mainColorHex: "242426", fontColorHex: "ffffff")
        let sashTokens = ThemeTokens.themed(mainColorHex: "242426", fontColorHex: "ffffff", usesDiagonalSashBackground: true)

        #expect(defaultTokens.usesDiagonalSashBackground == false)
        #expect(sashTokens.usesDiagonalSashBackground == true)
    }

    @Test("The environment default value is today's fixed ThemeTokens")
    func environmentDefaultValue() {
        #expect(EnvironmentValues().themeTokens == ThemeTokens())
    }
}
