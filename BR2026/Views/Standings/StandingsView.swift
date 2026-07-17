import SwiftUI

struct StandingsView: View {
    @State private var viewModel: StandingsViewModel
    @Environment(\.themeTokens) private var themeTokens

    init(service: MatchService) {
        _viewModel = State(initialValue: StandingsViewModel(service: service))
    }

    private static let columnWidth: CGFloat = 24
    private static let goalDifferenceWidth: CGFloat = 34
    private static let positionWidth: CGFloat = 24
    private static let leadingWidth: CGFloat = 58

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    GlassCard(cornerRadius: 24, style: .transparent) {
                        VStack(spacing: 0) {
                            Color.clear.frame(height: 0).id(Self.topAnchor)
                            header
                            ForEach(viewModel.standings, id: \.id) { standing in
                                row(for: standing)
                            }
                        }
                    }
                    .padding(16)
                }
                .scrollContentBackground(.hidden)
                // See MatchdayView's `.refreshable` for why: `.refreshable`'s
                // content-inset negotiation can leave the scroll position settled away
                // from where it started once `load()` reassigns `standings` mid-gesture.
                // Forcing it back to the top anchor is safe since pull-to-refresh only
                // triggers from at/near the top already.
                .refreshable {
                    await viewModel.load()
                    proxy.scrollTo(Self.topAnchor, anchor: .top)
                }
                .background(StadiumBackground())
                .navigationTitle("Standings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        if viewModel.isRefreshing {
                            RefreshPulseDot()
                        }
                    }
                }
                .task { await viewModel.loadOnce() }
            }
        }
        .trackScreen("Standings")
    }

    private static let topAnchor = "standingsTop"

    private var header: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: Self.leadingWidth)
            Color.clear.frame(maxWidth: .infinity)
            columnHeader(String(localized: "P", comment: "Standings table column header: abbreviation for \"Played\" (games played). Keep as short as the other column headers in this table."))
            columnHeader(String(localized: "W", comment: "Standings table column header: abbreviation for \"Won\" (games won). Keep as short as the other column headers in this table."))
            columnHeader(String(localized: "D", comment: "Standings table column header: abbreviation for \"Drawn\" (games drawn). Keep as short as the other column headers in this table."))
            columnHeader(String(localized: "L", comment: "Standings table column header: abbreviation for \"Lost\" (games lost). Keep as short as the other column headers in this table."))
            columnHeader(String(localized: "GD", comment: "Standings table column header: abbreviation for \"Goal Difference\". Keep as short as the other column headers in this table."), width: Self.goalDifferenceWidth)
            columnHeader(String(localized: "Pts", comment: "Standings table column header: abbreviation for \"Points\". Keep as short as the other column headers in this table."))
        }
        .padding(.bottom, 8)
        // Fully hiding this row (as opposed to giving it a meaningful combined label) left
        // visually-rendered column-header text with zero VoiceOver representation at all —
        // caught by AccessibilityAuditUITests' `.elementDetection` audit as "Potentially
        // inaccessible text". Each row's own accessibilityLabel (see Standing.swift) already
        // speaks every stat in full words, so the abbreviated header is redundant for VoiceOver
        // users rather than essential, but it still needs *some* accessible representation
        // instead of none — this exposes it as a single header-trait swipe stop.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel(
            String(
                localized: "Table columns: Played, Won, Drawn, Lost, Goal Difference, Points",
                comment: "VoiceOver label for the Standings table's column header row (spoken as one swipe stop) — summarizes what the abbreviated column headers (localized short forms like \"P W D L GD Pts\") mean, since the abbreviations themselves aren't announced. Each row separately speaks these same stats in full words."
            )
        )
    }

    private func columnHeader(_ text: String, width: CGFloat = columnWidth) -> some View {
        Text(text)
            .lineLimit(1)
            .frame(width: width)
            .font(.system(size: 11, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(themeTokens.textColor.opacity(0.5))
    }

    private func row(for standing: Standing) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("\(standing.position)")
                    .lineLimit(1)
                    .frame(width: Self.positionWidth, alignment: .leading)
                TeamCrestBadge(team: standing.team, size: 20)
            }
            .frame(width: Self.leadingWidth, alignment: .leading)
            Text(standing.team.displayName)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            statCell("\(standing.playedGames)")
            statCell("\(standing.won)")
            statCell("\(standing.draw)")
            statCell("\(standing.lost)")
            statCell(signed(standing.goalDifference), width: Self.goalDifferenceWidth)
            statCell("\(standing.points)", emphasized: true)
        }
        .font(.system(size: 14, weight: .semibold))
        .monospacedDigit()
        .foregroundStyle(themeTokens.textColor)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(standing.accessibilityLabel)
    }

    private func statCell(_ text: String, width: CGFloat = columnWidth, emphasized: Bool = false) -> some View {
        Text(text)
            .lineLimit(1)
            .frame(width: width)
            .fontWeight(emphasized ? .heavy : .regular)
            .foregroundStyle(emphasized ? themeTokens.textColor : themeTokens.textColor.opacity(0.85))
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }
}
