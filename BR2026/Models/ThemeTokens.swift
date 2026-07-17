import SwiftUI

struct ThemeTokens: Equatable {
    var overrideAccentColor: Color?
    /// Separate from `overrideAccentColor` because some teams' brand has two distinct
    /// signature colors — Fluminense's tricolor crest is grenat/burgundy + green, and the
    /// green reads better as the tab bar's selected-item color / round pill fill than as the
    /// general content accent (which stays grenat, matching `ChampionshipConfig`'s existing
    /// `accentColorHex` vs `tabSelectionColorHex` split for the same reason). `nil` falls
    /// back to `overrideAccentColor`.
    var overrideTabSelectionColor: Color?
    /// Separate from `overrideTabSelectionColor` because that field itself drives two different
    /// visual roles — the tab bar's tint (icon/label directly on the dark glass chrome) and the
    /// Fixtures round pill's selected fill (a background behind `textColor`) — that for every
    /// team so far wanted the same color. Atlético Mineiro's charcoal main color is too close to
    /// the tab bar's own dark fill, so its `overrideTabSelectionColor` was set to white for tab
    /// bar legibility — but white then broke the round pill (white fill behind white
    /// `textColor`). `nil` falls back to `overrideTabSelectionColor ?? overrideAccentColor`, so
    /// every other team's pill fill is unaffected.
    var overridePillFillColor: Color?
    /// Vasco da Gama's crest is a diagonal black/white/black sash rather than a solid color —
    /// no single accent hex represents it, so this bypasses the normal radial gradient + blob
    /// background entirely in favor of a diagonal `LinearGradient` (see `StadiumBackground`).
    /// `false` for every other team — this doesn't touch `gradientStops`/`blobColors`, which
    /// keep driving the hero card border and tab bar tint as usual even when this is `true`.
    var usesDiagonalSashBackground: Bool = false
    var textColor: Color = .white
    var gradientStops: [Color] = ThemeTokens.defaultGradientStops
    var blobColors: (top: Color, bottom: Color) = ThemeTokens.defaultBlobColors

    static let defaultGradientStops = [
        Color(hex: "#173a68"),
        Color(hex: "#0b2143"),
        Color(hex: "#061325")
    ]
    static let defaultBlobColors: (top: Color, bottom: Color) = (
        Color(hex: "#173a68"),
        Color(red: 45.0 / 255, green: 212.0 / 255, blue: 191.0 / 255)
    )

    static func == (lhs: ThemeTokens, rhs: ThemeTokens) -> Bool {
        lhs.overrideAccentColor == rhs.overrideAccentColor
            && lhs.overrideTabSelectionColor == rhs.overrideTabSelectionColor
            && lhs.overridePillFillColor == rhs.overridePillFillColor
            && lhs.usesDiagonalSashBackground == rhs.usesDiagonalSashBackground
            && lhs.textColor == rhs.textColor
            && lhs.gradientStops == rhs.gradientStops
            && lhs.blobColors.top == rhs.blobColors.top
            && lhs.blobColors.bottom == rhs.blobColors.bottom
    }

    static func themed(
        mainColorHex: String,
        fontColorHex: String,
        tabSelectionColorHex: String? = nil,
        pillFillColorHex: String? = nil,
        gradientDarkAmount: Double = -0.75,
        usesDiagonalSashBackground: Bool = false
    ) -> ThemeTokens {
        let accent = Color(hex: mainColorHex)
        // The same fallback chain the round pill's fill already resolves to (see
        // `FixturesView.roundPill`'s `overridePillFillColor ?? overrideTabSelectionColor ??
        // Color.accentColor`) — checking raw mainColorHex unconditionally here would
        // validate a surface that never actually renders whenever a team overrides the
        // pill fill away from its main color (e.g. Corinthians/Santos both override it to
        // black), producing false positives.
        let secondaryBackgroundHex = pillFillColorHex ?? tabSelectionColorHex ?? mainColorHex
        let resolvedFontColorHex = accessibleFontColorHex(candidateHex: fontColorHex, secondaryBackgroundHex: secondaryBackgroundHex)
        return ThemeTokens(
            overrideAccentColor: accent,
            overrideTabSelectionColor: tabSelectionColorHex.map { Color(hex: $0) },
            overridePillFillColor: pillFillColorHex.map { Color(hex: $0) },
            usesDiagonalSashBackground: usesDiagonalSashBackground,
            textColor: Color(hex: resolvedFontColorHex),
            gradientStops: [
                Color.shaded(hex: mainColorHex, towardWhite: 0.35),
                accent,
                Color.shaded(hex: mainColorHex, towardWhite: gradientDarkAmount)
            ],
            blobColors: (top: accent, bottom: accent)
        )
    }

    /// The app's fixed darkest background stop (see `defaultGradientStops`) — one of two
    /// reference surfaces a team's font color must contrast against.
    private static let fixedDarkBackgroundHex = "061325"

    /// WCAG AA's minimum contrast ratio for normal text.
    private static let minimumContrastRatio = 4.5

    /// Validates `candidateHex` against both the app's fixed dark background and a second
    /// surface it's actually drawn on top of elsewhere (the round pill's fill, LiveChip's
    /// capsule) — the two failure patterns behind every contrast bug found in this app so
    /// far (see `TeamThemeOption`'s doc-comment history: Atlético Mineiro's tab bar
    /// legibility, LiveChip's self-referential chip contrast). If either check fails,
    /// returns whichever of pure white or pure black scores higher on the *minimum* of its
    /// two contrast ratios — the candidate that's least-bad against both surfaces at once.
    /// Otherwise returns `candidateHex` unchanged. Applied unconditionally: curated
    /// overrides and raw API values are validated identically, with no bypass.
    static func accessibleFontColorHex(candidateHex: String, secondaryBackgroundHex: String) -> String {
        let passesBackground = WCAGContrast.contrastRatio(candidateHex, fixedDarkBackgroundHex) >= minimumContrastRatio
        let passesSecondary = WCAGContrast.contrastRatio(candidateHex, secondaryBackgroundHex) >= minimumContrastRatio
        guard passesBackground, passesSecondary else {
            let whiteMinRatio = min(
                WCAGContrast.contrastRatio("FFFFFF", fixedDarkBackgroundHex),
                WCAGContrast.contrastRatio("FFFFFF", secondaryBackgroundHex)
            )
            let blackMinRatio = min(
                WCAGContrast.contrastRatio("000000", fixedDarkBackgroundHex),
                WCAGContrast.contrastRatio("000000", secondaryBackgroundHex)
            )
            return whiteMinRatio >= blackMinRatio ? "FFFFFF" : "000000"
        }
        return candidateHex
    }
}

private struct ThemeTokensKey: EnvironmentKey {
    static let defaultValue = ThemeTokens()
}

extension EnvironmentValues {
    var themeTokens: ThemeTokens {
        get { self[ThemeTokensKey.self] }
        set { self[ThemeTokensKey.self] = newValue }
    }
}
