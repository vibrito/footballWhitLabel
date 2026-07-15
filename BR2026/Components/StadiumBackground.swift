import SwiftUI

/// The app-wide "stadium night" backdrop: a deep radial gradient with a top-center
/// light source, plus two soft blurred ambient glows. Colors come from `\.themeTokens`,
/// defaulting to the fixed navy/teal look below when no team theme is active — every
/// shipped app renders identically to before this feature existed.
/// See CLAUDE.md "Design System — Liquid Glass" → "Background".
struct StadiumBackground: View {
    @Environment(\.themeTokens) private var themeTokens

    var body: some View {
        ZStack {
            RadialGradient(
                colors: themeTokens.gradientStops,
                center: themeTokens.gradientCenter,
                startRadius: 0,
                endRadius: themeTokens.gradientEndRadius
            )

            Circle()
                .fill(themeTokens.blobColors.top.opacity(0.4))
                .frame(width: 420, height: 420)
                .blur(radius: 120)
                .offset(x: -160, y: -300)

            Circle()
                .fill(themeTokens.blobColors.bottom.opacity(0.32))
                .frame(width: 420, height: 420)
                .blur(radius: 120)
                .offset(x: 160, y: 320)
        }
        .ignoresSafeArea()
    }
}
