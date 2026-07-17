import SwiftUI

struct RefreshPulseDot: View {
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(.white.opacity(0.5))
            .frame(width: 6, height: 6)
            .opacity(pulse ? 0.35 : 1)
            .scaleEffect(pulse ? 0.8 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
            .accessibilityHidden(true)
    }
}
