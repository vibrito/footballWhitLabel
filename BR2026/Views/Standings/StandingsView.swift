import SwiftUI

struct StandingsView: View {
    @State private var viewModel: StandingsViewModel
    let themeStore: TeamThemeStore
    @Environment(\.themeTokens) private var themeTokens
    @ScaledMetric private var columnHeaderFontSize: CGFloat = 11
    @ScaledMetric private var rowFontSize: CGFloat = 14
    @ScaledMetric private var legendFontSize: CGFloat = 11

    init(service: MatchService, themeStore: TeamThemeStore) {
        _viewModel = State(initialValue: StandingsViewModel(service: service))
        self.themeStore = themeStore
    }

    // Deliberately fixed, not `@ScaledMetric`: these columns were tried as `@ScaledMetric`
    // first (to stop the stat digits' own boxes from clipping), but that made things worse —
    // scaling all 7 of them up in lockstep with the row font consumed *more* total row width
    // as Dynamic Type grew, squeezing the team name column even harder than fixed columns did
    // (empirically: Standings' "Text clipped" count went from 6 to 17). The stat digits
    // themselves were never actually the problem — every "Dynamic Type font sizes are
    // partially unsupported" finding on this screen was the separately-documented app-wide
    // cap false positive in AccessibilityAuditUITests.swift, not a real clipping bug on these
    // cells. Only the team name column (below) has a confirmed, screenshot-verified clipping
    // bug, fixed there directly via `.minimumScaleFactor` instead.
    private static let columnWidth: CGFloat = 24
    private static let goalDifferenceWidth: CGFloat = 34
    private static let positionWidth: CGFloat = 24
    // The position column plus a small gap before the team name (the team crest badge that
    // used to sit beside it was removed — too small at this size to render its kit-color ball
    // meaningfully). Shared by the header spacer so the stat columns stay aligned between
    // header and rows.
    private static let leadingWidth: CGFloat = positionWidth + 8

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        GlassCard(cornerRadius: 24, style: .transparent) {
                            VStack(spacing: 0) {
                                Color.clear.frame(height: 0).id(Self.topAnchor)
                                header
                                ForEach(viewModel.standings, id: \.id) { standing in
                                    row(for: standing)
                                }
                            }
                        }
                        if viewModel.standings.contains(where: { $0.zone != .none }) {
                            legend
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

    private func columnHeader(_ text: String, width: CGFloat? = nil) -> some View {
        Text(text)
            .lineLimit(1)
            .frame(width: width ?? Self.columnWidth)
            .font(.system(size: columnHeaderFontSize, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(themeTokens.textColor.opacity(0.5))
            // Same fixed-width-box problem the row's own `statCell`/team name already solved
            // via `.minimumScaleFactor` — the abbreviated headers ("P", "W", "Pts", etc.) sit
            // in the same non-scaling `columnWidth`/`goalDifferenceWidth` boxes, so the
            // (correctly scaling) header font can outgrow them at larger Dynamic Type sizes.
            // Caught by AccessibilityAuditUITests' `.textClipped` audit on "Pts" — this
            // function was missed when that fix was applied to the row cells.
            .minimumScaleFactor(0.7)
    }

    private func row(for standing: Standing) -> some View {
        HStack(spacing: 0) {
            Text("\(standing.position)")
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: Self.positionWidth, height: Self.positionWidth)
                .background {
                    if let ballColor = zoneBallColor(for: standing.zone) {
                        Circle().fill(ballColor)
                    }
                }
                // The ball's fixed teal/red fill is opaque regardless of the active team
                // theme or app accent, so the inherited `themeTokens.textColor` (which can
                // itself be a light color, e.g. when a light-kit team theme is active)
                // isn't guaranteed to read against it — black gives >5:1 contrast against
                // both zone colors (verified: teal 11.3:1, red 5.6:1), well past the
                // WCAG AA threshold this app already holds itself to elsewhere.
                .foregroundStyle(standing.zone == .none ? themeTokens.textColor : .black)
                .frame(width: Self.leadingWidth, alignment: .leading)
            Text(standing.team.displayName)
                .lineLimit(1)
                .truncationMode(.tail)
                // A longer name (e.g. "Internacional", "At. Paranaense") truncated with "…"
                // at larger Dynamic Type sizes even though this column has `maxWidth:
                // .infinity` — the fixed-width stat columns to its right don't grow, but the
                // name's own font does, so at some point it simply needs more horizontal
                // space than is left in the row. `.minimumScaleFactor` lets the name shrink
                // itself down (as HeroMatchCard's team name and score already do) before
                // falling back to `.truncationMode(.tail)`'s "…". Caught by
                // AccessibilityAuditUITests' `.textClipped` audit.
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
            statCell("\(standing.playedGames)")
            statCell("\(standing.won)")
            statCell("\(standing.draw)")
            statCell("\(standing.lost)")
            statCell(signed(standing.goalDifference), width: Self.goalDifferenceWidth)
            statCell("\(standing.points)", emphasized: true)
        }
        .font(.system(size: rowFontSize, weight: .semibold))
        .monospacedDigit()
        .foregroundStyle(themeTokens.textColor)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(standing.accessibilityLabel)
    }

    private func zoneBallColor(for zone: StandingZone) -> Color? {
        switch zone {
        case .libertadores:
            if let overrideHex = themeStore.selectedOption?.libertadoresBallColorOverrideHex {
                return Color(hex: overrideHex)
            }
            return Color(hex: "2dd4bf")
        case .championsLeague: return Color(hex: "2dd4bf")
        case .relegation: return Color(hex: "ef4444")
        case .none: return nil
        }
    }

    // Only shows a legend item for a zone actually present in the current standings — a
    // Brasileirão table never shows a "Champions League" item, and vice versa, since exactly
    // one of the two qualification competitions can appear per competition's own data.
    private var legend: some View {
        HStack(spacing: 16) {
            if viewModel.standings.contains(where: { $0.zone == .libertadores }) {
                legendItem(color: zoneBallColor(for: .libertadores) ?? Color(hex: "2dd4bf"), label: String(localized: "Libertadores", comment: "VoiceOver/legend label for a standings row in a Copa Libertadores qualification position."))
            }
            if viewModel.standings.contains(where: { $0.zone == .championsLeague }) {
                legendItem(color: zoneBallColor(for: .championsLeague) ?? Color(hex: "2dd4bf"), label: String(localized: "Champions League", comment: "VoiceOver/legend label for a standings row in a UEFA Champions League qualification position."))
            }
            if viewModel.standings.contains(where: { $0.zone == .relegation }) {
                legendItem(color: zoneBallColor(for: .relegation) ?? Color(hex: "ef4444"), label: String(localized: "Relegation zone", comment: "VoiceOver/legend label for a standings row in a relegation position."))
            }
            Spacer()
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: legendFontSize, weight: .semibold))
                .foregroundStyle(themeTokens.textColor.opacity(0.7))
        }
        .accessibilityElement(children: .combine)
    }

    private func statCell(_ text: String, width: CGFloat? = nil, emphasized: Bool = false) -> some View {
        Text(text)
            .lineLimit(1)
            .frame(width: width ?? Self.columnWidth)
            // The goal-difference column needs up to 3 characters ("+17", "-16") in a fixed
            // 34pt box — at larger Dynamic Type sizes the (correctly scaling) font no longer
            // fits, so it truncated with "…" even though the digits themselves were never
            // wrong. Every other stat column only ever holds 1-2 digits and stayed within its
            // fixed 24pt box in testing, but `.minimumScaleFactor` is applied to all stat
            // cells uniformly rather than singled out to goal difference, since any of them
            // could in principle need a 3rd digit (e.g. a 100+ point season). Caught by
            // AccessibilityAuditUITests' `.textClipped` audit.
            .minimumScaleFactor(0.7)
            .fontWeight(emphasized ? .heavy : .regular)
            .foregroundStyle(emphasized ? themeTokens.textColor : themeTokens.textColor.opacity(0.85))
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }
}
