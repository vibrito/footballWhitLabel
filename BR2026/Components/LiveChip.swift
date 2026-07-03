import SwiftUI

struct LiveChip: View {
    var minute: Int? = nil
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 6, height: 6)
                .opacity(pulse ? 0.35 : 1)
                .scaleEffect(pulse ? 0.8 : 1)
            Text(minute.map { "\($0)'" } ?? "LIVE")
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
