import SwiftUI

/// The app-wide "stadium night" backdrop: a deep radial gradient with a top-center
/// light source, plus two soft blurred ambient glows (top-left accent, bottom-right teal).
/// See CLAUDE.md "Design System — Liquid Glass" → "Background".
struct StadiumBackground: View {
    var body: some View {
        ZStack {
            RadialGradient(
                colors: [
                    Color(hex: "#173a68"),
                    Color(hex: "#0b2143"),
                    Color(hex: "#061325")
                ],
                center: .top,
                startRadius: 0,
                endRadius: 700
            )

            Circle()
                .fill(Color(hex: "#173a68").opacity(0.4))
                .frame(width: 420, height: 420)
                .blur(radius: 120)
                .offset(x: -160, y: -300)

            Circle()
                .fill(Color(red: 45.0 / 255, green: 212.0 / 255, blue: 191.0 / 255).opacity(0.32))
                .frame(width: 420, height: 420)
                .blur(radius: 120)
                .offset(x: 160, y: 320)
        }
        .ignoresSafeArea()
    }
}
