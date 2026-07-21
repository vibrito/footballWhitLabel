import SwiftUI
import UIKit

struct MoreView: View {
    @State private var viewModel: MoreViewModel
    let config: ChampionshipConfig
    let service: MatchService
    let themeStore: TeamThemeStore
    let themePurchaseStore: PurchaseStore<TeamThemeOption>
    let iconPurchaseStore: PurchaseStore<TeamIconOption>
    @Environment(\.themeTokens) private var themeTokens
    @ScaledMetric private var competitionNameFontSize: CGFloat = 16
    @ScaledMetric private var logoPlaceholderIconSize: CGFloat = 28
    @ScaledMetric private var sectionTitleFontSize: CGFloat = 13
    @ScaledMetric private var rowIconSize: CGFloat = 16
    @ScaledMetric private var rowTitleFontSize: CGFloat = 16
    @ScaledMetric private var chevronIconSize: CGFloat = 13

    init(config: ChampionshipConfig, service: MatchService, themeStore: TeamThemeStore, themePurchaseStore: PurchaseStore<TeamThemeOption>, iconPurchaseStore: PurchaseStore<TeamIconOption>) {
        _viewModel = State(initialValue: MoreViewModel(service: service))
        self.config = config
        self.service = service
        self.themeStore = themeStore
        self.themePurchaseStore = themePurchaseStore
        self.iconPurchaseStore = iconPurchaseStore
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    competitionHeader
                    ForEach(viewModel.sections) { section in
                        sectionView(section)
                    }
                }
                .padding(16)
            }
            .scrollContentBackground(.hidden)
            .background(StadiumBackground())
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: MoreDestination.self) { destination in
                switch destination {
                case .termsOfService:
                    TermsOfServiceView()
                case .appIconPicker:
                    AppIconPickerView(
                        viewModel: AppIconPickerViewModel(iconSetting: UIKitAppIconSetting(), purchaseStore: iconPurchaseStore, service: service)
                    )
                case .teamThemePicker:
                    TeamThemePickerView(
                        viewModel: TeamThemePickerViewModel(themeStore: themeStore, purchaseStore: themePurchaseStore, setting: UserDefaultsTeamThemeSetting(), service: service)
                    )
                }
            }
            .task { await viewModel.loadOnce() }
        }
        .trackScreen("More")
    }

    private var competitionHeader: some View {
        VStack(spacing: 8) {
            logoView
                .frame(width: 64, height: 64)
            // The API's competition name is the real league name (e.g. "Brasileirão") — a
            // third-party mark shown only for branding here, so it's hidden alongside the
            // logo under the same flag to keep this header generic. See FeatureFlags.
            if FeatureFlags.showsRemoteCrests, let name = viewModel.competitionName {
                Text(name)
                    .font(.system(size: competitionNameFontSize, weight: .semibold))
                    .foregroundStyle(themeTokens.textColor)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var logoView: some View {
        if FeatureFlags.showsRemoteCrests, let logoData = viewModel.competitionLogoData, let uiImage = UIImage(data: logoData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
        } else if FeatureFlags.showsRemoteCrests {
            AsyncImage(url: viewModel.competitionLogoURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                default:
                    logoPlaceholder
                }
            }
            .accessibilityHidden(true)
        } else {
            logoPlaceholder
                .accessibilityHidden(true)
        }
    }

    private var logoPlaceholder: some View {
        Circle()
            .fill(.white.opacity(0.07))
            .overlay(
                Image(systemName: "soccerball")
                    .font(.system(size: logoPlaceholderIconSize))
                    .foregroundStyle(themeTokens.textColor.opacity(0.55))
            )
    }

    private func sectionView(_ section: MoreSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.titleKey)
                .font(.system(size: sectionTitleFontSize, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(themeTokens.textColor.opacity(0.5))
                .textCase(.uppercase)
            GlassCard(cornerRadius: 18, style: .transparent) {
                VStack(spacing: 10) {
                    ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                        rowView(row)
                        if index < section.rows.count - 1 {
                            Rectangle()
                                .fill(Color.white.opacity(0.16))
                                .frame(height: 0.5)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func rowView(_ row: MoreRow) -> some View {
        if row.isEnabled, let destination = row.destination {
            NavigationLink(value: destination) {
                rowLabel(row, showsChevron: true)
            }
            .buttonStyle(.plain)
        } else {
            rowLabel(row, showsChevron: false)
                .opacity(0.3)
        }
    }

    @ViewBuilder
    private func rowLabel(_ row: MoreRow, showsChevron: Bool) -> some View {
        let base = HStack(spacing: 12) {
            Image(systemName: row.systemImage)
                .font(.system(size: rowIconSize, weight: .semibold))
                .frame(width: 24)
            Text(row.titleKey)
                .font(.system(size: rowTitleFontSize, weight: .semibold))
            Spacer()
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: chevronIconSize, weight: .semibold))
                    .foregroundStyle(themeTokens.textColor.opacity(0.3))
            }
        }
        .foregroundStyle(themeTokens.textColor)
        .padding(.vertical, 10)
        // Without this, the row's tappable area stops at the last piece of drawn
        // content (the icon/title on the left, or the chevron on the right) — the
        // `Spacer()` in between has nothing to hit-test against, so tapping the empty
        // middle of the row does nothing.
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: row.titleKey))

        if row.isEnabled {
            base
        } else {
            base.accessibilityHint(Text("Not available", comment: "VoiceOver hint appended to a More-screen row that is currently disabled/unavailable."))
        }
    }
}
