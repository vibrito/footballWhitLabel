// ⚠️ SHARED FILE — kept byte-identical with the Fixture 2026 app.
//
// The white-label repo is the source of truth. After editing, run
// `scripts/sync-crests.sh` there to copy this into ../worldcup and refresh the
// integrity hash below. CrestSyncTests fails if the file and its hash disagree,
// which is how an un-synced edit gets caught in either repo.
//
// crest-sync: 81c7519084475cd5e2e13daea877bcaf29b3bd0203d8730491acfcc5101bb8ad

import SwiftUI

/// A curated jersey-style disc standing in for a club crest — no lettering, just the
/// club's colours in its pattern, styled like a glossy *futebol de botão* button.
///
/// Only draws the disc. Deciding *whether* a team gets one — versus a national flag, a
/// remote crest, or initials — belongs to each app's own badge view, because that policy
/// genuinely differs between them.
struct CrestDisc: View {
    let symbol: TeamCrestSymbol
    let size: CGFloat

    var body: some View {
        pattern
            .frame(width: size, height: size)
            .clipShape(Circle())
            // Convex shading: darken toward the lower-right so the disc reads as domed,
            // not flat.
            .overlay(
                Circle().fill(
                    RadialGradient(
                        colors: [.clear, .black.opacity(0.38)],
                        center: UnitPoint(x: 0.36, y: 0.32),
                        startRadius: size * 0.08,
                        endRadius: size * 0.62
                    )
                )
            )
            // Glossy specular highlight, upper-left, like light hitting a polished button.
            .overlay(
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.65), .clear],
                            center: .center, startRadius: 0, endRadius: size * 0.26
                        )
                    )
                    .frame(width: size * 0.5, height: size * 0.36)
                    .offset(x: -size * 0.13, y: -size * 0.17)
                    .blur(radius: size * 0.015)
            )
            // Beveled rim: light at the top, dark at the bottom.
            .overlay(
                Circle().strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.55), .black.opacity(0.35)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: max(1, size * 0.035)
                )
            )
            // Drop shadow so the disc sits above the surface.
            .shadow(color: .black.opacity(0.45), radius: size * 0.05, x: 0, y: size * 0.045)
    }

    @ViewBuilder
    private var pattern: some View {
        switch symbol {
        case .verticalStripes(let bands):
            let total = bands.reduce(0) { $0 + $1.weight }
            HStack(spacing: 0) {
                ForEach(Array(bands.enumerated()), id: \.offset) { _, band in
                    Color(hex: band.hex)
                        .frame(width: size * band.weight / max(total, 1))
                }
            }
        case .horizontalStripes(let bands):
            let total = bands.reduce(0) { $0 + $1.weight }
            VStack(spacing: 0) {
                ForEach(Array(bands.enumerated()), id: \.offset) { _, band in
                    Color(hex: band.hex)
                        .frame(height: size * band.weight / max(total, 1))
                }
            }
        case .diagonalSash(let background, let stripe, let widthFraction):
            ZStack {
                Color(hex: background)
                Rectangle()
                    .fill(Color(hex: stripe))
                    .frame(width: size * widthFraction, height: size * 1.6)
                    .rotationEffect(.degrees(45))
            }
        case .concentric(let bands):
            let total = bands.reduce(0) { $0 + $1.weight }
            // Draw outer→inner so each smaller circle sits on top. A band's circle spans
            // the radius from the centre out to the sum of its own and all inner bands'
            // weights.
            ZStack {
                ForEach(Array(bands.enumerated()), id: \.offset) { index, band in
                    let innerWeight = bands[index...].reduce(0) { $0 + $1.weight }
                    Circle()
                        .fill(Color(hex: band.hex))
                        .frame(width: size * innerWeight / max(total, 1))
                }
            }
        }
    }
}
