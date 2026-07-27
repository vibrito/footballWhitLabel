import SwiftUI

/// Where a match can be watched, as a row of channel chips.
///
/// Every broadcaster is drawn identically, free-to-air included. Highlighting one tier
/// editorialises on the reader's behalf, and the app does not know which services they
/// already pay for — to someone who has Premiere, a highlighted Globo chip is noise rather
/// than an answer. Type still decides the order, which is a predictable sequence rather than
/// a claim about which is better.
///
/// Not tappable, though most listings carry a `url`: a control that opens a site on some
/// matches and does nothing on others is one the reader cannot predict. Mirrors the same
/// component in Fixture 2026, so the two apps' cards read alike.
struct BroadcastChips: View {
    let broadcasts: [Broadcast]
    var alignment: HorizontalAlignment = .leading

    @Environment(\.themeTokens) private var themeTokens

    @ScaledMetric private var iconSize: CGFloat = 10
    @ScaledMetric private var chipSize: CGFloat = 11

    var body: some View {
        if !broadcasts.isEmpty {
            HStack(spacing: 6) {
                if alignment == .center { Spacer(minLength: 0) }
                Image(systemName: "tv")
                    .font(.system(size: iconSize))
                    .foregroundStyle(themeTokens.textColor.opacity(0.4))
                    .accessibilityHidden(true)
                ForEach(broadcasts, id: \.name) { broadcast in
                    Text(broadcast.name)
                        .font(.system(size: chipSize, weight: .bold))
                        .tracking(0.3)
                        .foregroundStyle(themeTokens.textColor.opacity(0.78))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(themeTokens.textColor.opacity(0.08), in: Capsule())
                        .overlay(
                            Capsule().strokeBorder(themeTokens.textColor.opacity(0.16),
                                                   lineWidth: 0.5)
                        )
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            // Announced as one phrase: the tv glyph is hidden from VoiceOver, so without this
            // the row would be read out as a bare run of proper nouns.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(
                "\(String(localized: "Where to watch")): "
                + broadcasts.map(\.name).formatted(.list(type: .and))
            ))
        }
    }
}
