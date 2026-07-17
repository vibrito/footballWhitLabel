// BR2026/Models/WCAGContrast.swift
import Foundation

/// WCAG 2.x contrast-ratio math. Plain Swift, no UI dependency, so it's independently
/// testable and reusable from both View-layer color pickers and Model-layer validation
/// (see `ThemeTokens.accessibleFontColorHex(candidateHex:secondaryBackgroundHex:)`).
enum WCAGContrast {
    /// WCAG 2.x relative luminance: gamma-corrects each sRGB channel, then applies the
    /// standard perceptual weights (0.2126 R, 0.7152 G, 0.0722 B). Returns a value in
    /// [0, 1], where 0 is pure black and 1 is pure white.
    static func relativeLuminance(hex: String) -> Double {
        let (red, green, blue) = rgbComponents(hex: hex)
        return 0.2126 * linearize(red) + 0.7152 * linearize(green) + 0.0722 * linearize(blue)
    }

    /// WCAG 2.x contrast ratio between two colors: `(L1 + 0.05) / (L2 + 0.05)`, where `L1`
    /// is the lighter of the two relative luminances. Always >= 1.0 (identical colors);
    /// WCAG AA requires >= 4.5 for normal text.
    static func contrastRatio(_ hex1: String, _ hex2: String) -> Double {
        let l1 = relativeLuminance(hex: hex1)
        let l2 = relativeLuminance(hex: hex2)
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func linearize(_ channel: Double) -> Double {
        channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }

    // Deliberately not shared with `Color+Hex.swift`'s identical-shaped private helper:
    // that one lives on a `Color` extension (`import SwiftUI`), and this file must stay
    // UI-import-free per this codebase's Model-layer convention. The duplication is a
    // handful of lines of hex parsing.
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
