import SwiftUI

enum GlassCardStyle {
    /// Frosted `.ultraThinMaterial` — the default look for match cards.
    case standard
    /// A much lighter tint that lets the stadium background gradient show through,
    /// for panels covering more of the screen (e.g. the Standings table).
    case transparent
}

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 22
    var style: GlassCardStyle = .standard
    @ViewBuilder var content: Content
    @Environment(\.themeTokens) private var themeTokens

    var body: some View {
        content
            .padding(16)
            .background { background }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.22), radius: 22, x: 0, y: 8)
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .standard:
            Rectangle().fill(.ultraThinMaterial)
        case .transparent:
            // Light-background themes (e.g. Corinthians/São Paulo's centered vignette) make
            // the usual white-tinted fill nearly invisible — a dark tint reads as a distinct
            // frosted panel against a light backdrop instead.
            Rectangle().fill(themeTokens.cardFillIsDark ? Color.black.opacity(0.12) : Color.white.opacity(0.05))
        }
    }

    private var borderColor: Color {
        themeTokens.cardFillIsDark ? Color.black.opacity(0.18) : Color.white.opacity(0.16)
    }
}
