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

    @Test("accessibleFontColorHex returns the candidate unchanged when it passes both contrast checks")
    func accessibleFontColorHexPassesThrough() {
        // F2F2F2 (off-white) against a dark charcoal secondary background and the fixed
        // dark background both pass WCAG AA comfortably.
        let result = ThemeTokens.accessibleFontColorHex(candidateHex: "F2F2F2", secondaryBackgroundHex: "2B2B2E")
        #expect(result == "F2F2F2")
    }

    @Test("accessibleFontColorHex replaces a candidate that fails against the fixed dark background — the exact bug Corinthians' original API font color (000000) would have shipped with")
    func accessibleFontColorHexCatchesFixedBackgroundFailure() {
        // 000000 (pure black) fails against 061325 (the fixed dark background) and also
        // fails against a realistic dark secondary background like 2B2B2E (Atlético
        // Mineiro's charcoal) — this regresses the historical bug. (A near-white secondary
        // background here would be a pathological edge case — see the plan's note on this
        // — so this test deliberately uses a realistic dark team color instead.)
        let result = ThemeTokens.accessibleFontColorHex(candidateHex: "000000", secondaryBackgroundHex: "2B2B2E")
        #expect(result != "000000")
        #expect(result == "FFFFFF")
    }

    @Test("accessibleFontColorHex replaces a candidate that fails against its own secondary background — the exact bug LiveChip's contrast fix addressed")
    func accessibleFontColorHexCatchesSecondaryBackgroundFailure() {
        // A candidate identical to the secondary background always fails that check (1:1
        // ratio), regardless of how well it does against the fixed background.
        let result = ThemeTokens.accessibleFontColorHex(candidateHex: "2B2B2E", secondaryBackgroundHex: "2B2B2E")
        #expect(result != "2B2B2E")
    }

    @Test("accessibleFontColorHex's fallback is always white or black, never a color that still fails")
    func accessibleFontColorHexFallbackIsAlwaysWhiteOrBlack() {
        let result = ThemeTokens.accessibleFontColorHex(candidateHex: "808080", secondaryBackgroundHex: "707070")
        #expect(result == "FFFFFF" || result == "000000")
    }

    @Test("themed(...) resolves the secondary background via pillFillColorHex when present, not raw mainColorHex — this is the exact false positive that broke Santos's real, working colors when the check first used raw mainColorHex unconditionally")
    func themedFactoryResolvesSecondaryBackgroundViaPillFillOverride() {
        // Santos's real curated values: mainColorOverrideHex 82827F, fontColorOverrideHex
        // F2F2F2, pillFillColorOverrideHex 000000. F2F2F2 only scores 3.44:1 against raw
        // 82827F (would incorrectly fail), but the pill's fill never actually renders as
        // raw mainColorHex when pillFillColorHex is set — it renders as 000000, against
        // which F2F2F2 scores a very safe 18.76:1. themed(...) must check the surface that
        // actually renders, so F2F2F2 must pass through unchanged here.
        let tokens = ThemeTokens.themed(
            mainColorHex: "82827F",
            fontColorHex: "F2F2F2",
            pillFillColorHex: "000000"
        )
        #expect(tokens.textColor == Color(hex: "F2F2F2"))
    }

    @Test("themed(...) falls back to raw mainColorHex for the secondary-background check when no pillFillColorHex/tabSelectionColorHex override exists, and still replaces an unsafe font color in that case")
    func themedFactoryFallsBackToMainColorWhenNoOverride() {
        // Same fontColorHex/mainColorHex pair as Santos, but with no pillFillColorHex this
        // time — the secondary-background check has nothing but raw mainColorHex (82827F)
        // to fall back to, F2F2F2 fails that (3.44:1 < 4.5), so it must be replaced.
        let tokens = ThemeTokens.themed(mainColorHex: "82827F", fontColorHex: "F2F2F2")
        #expect(tokens.textColor != Color(hex: "F2F2F2"))
    }

    @Test("themed(mainColorHex:fontColorHex:) leaves an already-safe font color unchanged")
    func themedFactoryPassesThroughSafeFontColor() {
        // Matches the existing themedFactoryBuildsActiveTokens test's inputs — confirms
        // this task doesn't change behavior for colors that already pass.
        let tokens = ThemeTokens.themed(mainColorHex: "225638", fontColorHex: "ffffff")
        #expect(tokens.textColor == Color(hex: "ffffff"))
    }
}
