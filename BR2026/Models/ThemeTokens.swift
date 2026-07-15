import SwiftUI

/// `.topAnchored` matches every team's default look — lighter near the top, darkening toward
/// the bottom/edges. `.centeredVignette` glows lighter in the middle of the screen and darkens
/// toward every edge, top and bottom both, with a tighter radius and a stronger black — used
/// for near-white teams (Corinthians, São Paulo), whose jerseys are white-bodied with dark
/// (black) trim — a white glow fading to black edges reads as "jersey body surrounded by dark
/// structural elements," closer to the actual kit than the top-anchored look.
enum GradientStyle: Equatable {
    case topAnchored
    case centeredVignette
}

struct ThemeTokens: Equatable {
    var overrideAccentColor: Color?
    var textColor: Color = .white
    var gradientStops: [Color] = ThemeTokens.defaultGradientStops
    var gradientCenter: UnitPoint = .top
    var gradientEndRadius: CGFloat = 700
    var blobColors: (top: Color, bottom: Color) = ThemeTokens.defaultBlobColors
    /// `.centeredVignette` themes have a light (white/gray) background, where `GlassCard`'s
    /// usual `white @ 5%` fill is nearly invisible — cards need a dark-tinted fill instead to
    /// read as distinct frosted panels.
    var cardFillIsDark = false

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
            && lhs.textColor == rhs.textColor
            && lhs.gradientStops == rhs.gradientStops
            && lhs.gradientCenter == rhs.gradientCenter
            && lhs.gradientEndRadius == rhs.gradientEndRadius
            && lhs.blobColors.top == rhs.blobColors.top
            && lhs.blobColors.bottom == rhs.blobColors.bottom
            && lhs.cardFillIsDark == rhs.cardFillIsDark
    }

    /// `backgroundColorHex` drives the gradient (jersey body tone); `accentColorHex` drives
    /// everything else that needs to read as a legible, branded color — blobs, the hero
    /// card's border, tab tint, `LiveChip`/`AccentPill` — separately, because a near-white
    /// `backgroundColorHex` (as with Corinthians/São Paulo) makes a poor accent: chips/pills
    /// rendered in it are nearly invisible. For teams with a normally-saturated main color
    /// (Palmeiras, Flamengo), callers pass the same hex for both and behavior is unchanged.
    static func themed(
        backgroundColorHex: String,
        accentColorHex: String,
        fontColorHex: String,
        gradientStyle: GradientStyle = .topAnchored
    ) -> ThemeTokens {
        let accent = Color(hex: accentColorHex)
        switch gradientStyle {
        case .topAnchored:
            return ThemeTokens(
                overrideAccentColor: accent,
                textColor: Color(hex: fontColorHex),
                gradientStops: [
                    Color.shaded(hex: backgroundColorHex, towardWhite: 0.35),
                    Color(hex: backgroundColorHex),
                    Color.shaded(hex: backgroundColorHex, towardWhite: -0.75)
                ],
                gradientCenter: .top,
                gradientEndRadius: 700,
                blobColors: (top: accent, bottom: accent)
            )
        case .centeredVignette:
            // Only the center-most stop uses the team's actual (undarkened) background color —
            // enough to tell teams apart (Corinthians' warm cream glow vs. São Paulo's pure
            // white one) without reintroducing the muddy brown/olive artifact from shading a
            // warm color toward black: the remaining stops stay neutral gray→near-black, so
            // there's only one blend step involving the tint instead of compounding it across
            // two.
            return ThemeTokens(
                overrideAccentColor: accent,
                textColor: Color(hex: fontColorHex),
                gradientStops: [Color(hex: backgroundColorHex), Color(white: 0.4), Color(white: 0.05)],
                gradientCenter: .center,
                gradientEndRadius: 320,
                blobColors: (top: accent, bottom: accent),
                cardFillIsDark: true
            )
        }
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
