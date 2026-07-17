import SwiftUI

struct LiveChip: View {
    var minute: Int? = nil
    var isHalftime: Bool = false
    @Environment(\.themeTokens) private var themeTokens
    @State private var pulse = false

    private var chipText: String {
        if isHalftime {
            return String(localized: "HT", comment: "Abbreviation shown in the live-match chip during halftime.")
        }
        if let minute {
            return "\(minute)'"
        }
        return String(localized: "LIVE", comment: "Text shown in the live-match chip when no minute is available yet.")
    }

    // A team theme's background gradient is built from that same team's accent color
    // (see ThemeTokens.themed), so an accent-colored chip on top of it can collapse to
    // near-invisible for saturated team colors — confirmed visually for at least two
    // themes. `textColor` is the color each theme already picks deliberately to read
    // well against its own palette, so it's a safe substitute whenever a theme is
    // active. The untethemed app keeps its original accent-colored chip exactly as
    // specified in CLAUDE.md's design system.
    private var chipColor: Color {
        themeTokens.overrideAccentColor != nil ? themeTokens.textColor : Color.accentColor
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(chipColor)
                .frame(width: 6, height: 6)
                .opacity(pulse ? 0.35 : 1)
                .scaleEffect(pulse ? 0.8 : 1)
            Text(chipText)
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.5)
                .monospacedDigit()
        }
        .foregroundStyle(chipColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(chipColor.opacity(0.18), in: Capsule())
        .overlay(Capsule().strokeBorder(chipColor.opacity(0.45), lineWidth: 0.5))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .accessibilityHidden(true)
    }
}
