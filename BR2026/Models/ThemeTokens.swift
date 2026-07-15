import SwiftUI

struct ThemeTokens: Equatable {
    var overrideAccentColor: Color?
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
            && lhs.textColor == rhs.textColor
            && lhs.gradientStops == rhs.gradientStops
            && lhs.blobColors.top == rhs.blobColors.top
            && lhs.blobColors.bottom == rhs.blobColors.bottom
    }

    static func themed(mainColorHex: String, fontColorHex: String) -> ThemeTokens {
        let accent = Color(hex: mainColorHex)
        return ThemeTokens(
            overrideAccentColor: accent,
            textColor: Color(hex: fontColorHex),
            gradientStops: [
                Color.shaded(hex: mainColorHex, towardWhite: 0.35),
                accent,
                Color.shaded(hex: mainColorHex, towardWhite: -0.75)
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
