import SwiftUI

/// The uppercase section label used above a group of match cards, on both Matchday and
/// Fixtures. Mirrors the component of the same name in the Fixture 2026 app.
struct SectionHeader: View {
    let title: Text
    @Environment(\.themeTokens) private var themeTokens
    @ScaledMetric private var fontSize: CGFloat = 13

    init(_ title: Text) {
        self.title = title
    }

    init(_ title: String) {
        self.title = Text(title)
    }

    var body: some View {
        title
            .font(.system(size: fontSize, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(themeTokens.textColor.opacity(0.5))
            .textCase(.uppercase)
            .accessibilityAddTraits(.isHeader)
    }
}
