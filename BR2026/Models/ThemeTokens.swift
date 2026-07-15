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
        gradientDarkAmount: Double = -0.75
    ) -> ThemeTokens {
        let accent = Color(hex: mainColorHex)
        return ThemeTokens(
            overrideAccentColor: accent,
            overrideTabSelectionColor: tabSelectionColorHex.map { Color(hex: $0) },
            overridePillFillColor: pillFillColorHex.map { Color(hex: $0) },
            textColor: Color(hex: fontColorHex),
            gradientStops: [
                Color.shaded(hex: mainColorHex, towardWhite: 0.35),
                accent,
                Color.shaded(hex: mainColorHex, towardWhite: gradientDarkAmount)
            ],
            blobColors: (top: accent, bottom: accent)
        )
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
