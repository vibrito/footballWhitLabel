import SwiftUI

/// A single timeline entry, laid out on whichever side (home/away) the event
/// belongs to, with a time badge centered between the two columns.
struct MatchTimelineRow: View {
    let event: MatchEvent
    @ScaledMetric private var timeBadgeFontSize: CGFloat = 13
    @ScaledMetric private var playerNameFontSize: CGFloat = 15
    @ScaledMetric private var subtitleFontSize: CGFloat = 12
    @ScaledMetric private var goalIconSize: CGFloat = 13
    @ScaledMetric private var substitutionIconSize: CGFloat = 11

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if event.team == .home { content } else { Color.clear }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            timeBadge

            Group {
                if event.team == .away { content } else { Color.clear }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(event.accessibilityLabel)
    }

    private var timeBadge: some View {
        Text(minuteLabel)
            .font(.system(size: timeBadgeFontSize, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08), in: Capsule())
    }

    private var minuteLabel: String {
        if let extraMinute = event.extraMinute {
            return "\(event.minute)+\(extraMinute)'"
        }
        return "\(event.minute)'"
    }

    @ViewBuilder
    private var content: some View {
        let alignment: HorizontalAlignment = event.team == .home ? .trailing : .leading
        HStack(spacing: 6) {
            if event.team == .away { icon }
            VStack(alignment: alignment, spacing: 2) {
                Text(event.player)
                    .font(.system(size: playerNameFontSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let subtitleText {
                    subtitleText
                        .font(.system(size: subtitleFontSize))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
            if event.team == .home { icon }
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch event.type {
        case .goal:
            Image(systemName: "soccerball")
                .font(.system(size: goalIconSize))
                .foregroundStyle(.white.opacity(0.8))
        case .yellowCard:
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.yellow)
                .frame(width: 10, height: 14)
        case .redCard:
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.red)
                .frame(width: 10, height: 14)
        case .substitution:
            HStack(spacing: 2) {
                Image(systemName: "arrow.down")
                    .foregroundStyle(Color.red)
                Image(systemName: "arrow.up")
                    .foregroundStyle(Color.green)
            }
            .font(.system(size: substitutionIconSize, weight: .bold))
        case .unknown:
            EmptyView()
        }
    }

    private var subtitleText: Text? {
        switch event.type {
        case .substitution:
            guard let playerOut = event.playerOut else { return nil }
            return Text("For \(playerOut)")
        case .goal:
            switch event.detail {
            case "Normal Goal": return nil
            case "Penalty": return Text("Penalty")
            case "Own Goal": return Text("Own Goal")
            default: return Text(event.detail)
            }
        default:
            return nil
        }
    }
}
