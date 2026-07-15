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
        #expect(tokens.gradientCenter == .top)
        #expect(tokens.cardFillIsDark == false)
        #expect(tokens.blobColors.top == ThemeTokens.defaultBlobColors.top)
        #expect(tokens.blobColors.bottom == ThemeTokens.defaultBlobColors.bottom)
    }

    @Test("themed(backgroundColorHex:accentColorHex:fontColorHex:) sets a non-nil accent, the given text color, top-anchored gradient by default, and both blobs to the accent color")
    func themedFactoryBuildsActiveTokens() {
        let tokens = ThemeTokens.themed(backgroundColorHex: "225638", accentColorHex: "225638", fontColorHex: "ffffff")
        #expect(tokens.overrideAccentColor == Color(hex: "225638"))
        #expect(tokens.textColor == Color(hex: "ffffff"))
        #expect(tokens.gradientCenter == .top)
        #expect(tokens.gradientEndRadius == 700)
        #expect(tokens.cardFillIsDark == false)
        #expect(tokens.blobColors.top == Color(hex: "225638"))
        #expect(tokens.blobColors.bottom == Color(hex: "225638"))
        #expect(tokens.gradientStops.count == 3)
    }

    @Test("backgroundColorHex and accentColorHex can differ: the gradient follows background, blobs/border follow accent")
    func backgroundAndAccentAreIndependent() {
        let tokens = ThemeTokens.themed(backgroundColorHex: "fcfbee", accentColorHex: "C8102E", fontColorHex: "000000")
        #expect(tokens.overrideAccentColor == Color(hex: "C8102E"))
        #expect(tokens.blobColors.top == Color(hex: "C8102E"))
        #expect(tokens.blobColors.bottom == Color(hex: "C8102E"))
        // The middle gradient stop is the raw backgroundColorHex, not the accent.
        #expect(tokens.gradientStops[1] == Color(hex: "fcfbee"))
    }

    @Test(".centeredVignette glows from the middle with a tighter radius, a stronger black, and dark-tinted glass cards")
    func centeredVignetteStyle() {
        let topAnchored = ThemeTokens.themed(backgroundColorHex: "fcfbee", accentColorHex: "C8102E", fontColorHex: "000000")
        let centered = ThemeTokens.themed(backgroundColorHex: "fcfbee", accentColorHex: "C8102E", fontColorHex: "000000", gradientStyle: .centeredVignette)

        #expect(topAnchored.gradientCenter == .top)
        #expect(topAnchored.cardFillIsDark == false)
        #expect(centered.gradientCenter == .center)
        #expect(centered.gradientEndRadius < topAnchored.gradientEndRadius)
        #expect(centered.gradientStops != topAnchored.gradientStops)
        #expect(centered.cardFillIsDark == true)
        #expect(centered.overrideAccentColor == topAnchored.overrideAccentColor)
        #expect(centered.textColor == topAnchored.textColor)
        #expect(centered.blobColors.top == topAnchored.blobColors.top)
        #expect(centered.blobColors.bottom == topAnchored.blobColors.bottom)
    }

    @Test(".centeredVignette uses the raw (undarkened) backgroundColorHex as its center stop, and neutral gray/near-black for the rest")
    func centeredVignetteUsesBackgroundCenterAndNeutralTail() {
        // Regression guard: shading a warm off-white (fcfbee) toward black produces a muddy
        // brown/olive midtone instead of a clean spotlight — only the center stop may carry
        // the team's tint, the tail must stay neutral grayscale regardless of the team's hue.
        let tokens = ThemeTokens.themed(backgroundColorHex: "fcfbee", accentColorHex: "C8102E", fontColorHex: "000000", gradientStyle: .centeredVignette)
        #expect(tokens.gradientStops == [Color(hex: "fcfbee"), Color(white: 0.4), Color(white: 0.05)])
    }

    @Test(".centeredVignette center stop differs per team's background color, so two near-white teams don't look identical")
    func centeredVignetteDistinguishesTeams() {
        let corinthians = ThemeTokens.themed(backgroundColorHex: "fcfbee", accentColorHex: "C8102E", fontColorHex: "000000", gradientStyle: .centeredVignette)
        let saoPaulo = ThemeTokens.themed(backgroundColorHex: "ffffff", accentColorHex: "E4022B", fontColorHex: "000000", gradientStyle: .centeredVignette)

        #expect(corinthians.gradientStops != saoPaulo.gradientStops)
        #expect(corinthians.gradientStops[0] == Color(hex: "fcfbee"))
        #expect(saoPaulo.gradientStops[0] == Color(hex: "ffffff"))
        #expect(corinthians.overrideAccentColor != saoPaulo.overrideAccentColor)
    }

    @Test("The environment default value is today's fixed ThemeTokens")
    func environmentDefaultValue() {
        #expect(EnvironmentValues().themeTokens == ThemeTokens())
    }
}
