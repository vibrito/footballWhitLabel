import SwiftUI

struct LiveChip: View {
    var minute: Int? = nil
    var isHalftime: Bool = false
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

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 6, height: 6)
                .opacity(pulse ? 0.35 : 1)
                .scaleEffect(pulse ? 0.8 : 1)
            Text(chipText)
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.5)
                .monospacedDigit()
        }
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.18), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.45), lineWidth: 0.5))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
