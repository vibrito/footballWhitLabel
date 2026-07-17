import SwiftUI

struct AccentPill: View {
    let text: String

    @ScaledMetric private var fontSize: CGFloat = 11

    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .bold))
            .tracking(0.3)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.accentColor.opacity(0.18), in: Capsule())
            .foregroundStyle(Color.accentColor)
            .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.45), lineWidth: 0.5))
    }
}
