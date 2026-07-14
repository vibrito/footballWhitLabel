import SwiftUI

extension Color {
    init(hex: String) {
        let (red, green, blue) = Color.rgbComponents(hex: hex)
        self.init(red: red, green: green, blue: blue)
    }

    /// Blends a hex color toward white (`amount` > 0) or black (`amount` < 0) by linear
    /// interpolation in RGB space — a simple, non-perceptual blend, which is fine for a
    /// stylistic background gradient rather than brand-critical color matching.
    static func shaded(hex: String, towardWhite amount: Double) -> Color {
        let (red, green, blue) = rgbComponents(hex: hex)
        let target = amount >= 0 ? 1.0 : 0.0
        let t = abs(amount)
        return Color(
            red: red + (target - red) * t,
            green: green + (target - green) * t,
            blue: blue + (target - blue) * t
        )
    }

    private static func rgbComponents(hex: String) -> (red: Double, green: Double, blue: Double) {
        let hexValue = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var rgb: UInt64 = 0
        Scanner(string: hexValue).scanHexInt64(&rgb)
        return (
            Double((rgb & 0xFF0000) >> 16) / 255,
            Double((rgb & 0x00FF00) >> 8) / 255,
            Double(rgb & 0x0000FF) / 255
        )
    }
}
