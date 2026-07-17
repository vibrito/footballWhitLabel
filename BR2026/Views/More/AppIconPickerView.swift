import SwiftUI

struct AppIconPickerView: View {
    @State private var viewModel: AppIconPickerViewModel
    @Environment(\.themeTokens) private var themeTokens

    init(viewModel: AppIconPickerViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                GlassCard(cornerRadius: 18, style: .transparent) {
                    VStack(spacing: 10) {
                        ForEach(Array(AppIconOption.allCases.enumerated()), id: \.element.id) { index, option in
                            freeRowView(option)
                            if index < AppIconOption.allCases.count - 1 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.16))
                                    .frame(height: 0.5)
                            }
                        }
                        // Team icons are Brasileirão-specific purchasable content — gated the
                        // same way Team Theme's row is gated in MoreViewModel, so the other
                        // championship targets show only the free Default/Stadium rows above.
                        #if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA || TARGET_SCOTTISH_PREMIERSHIP || TARGET_LA_LIGA)
                        Rectangle()
                            .fill(Color.white.opacity(0.16))
                            .frame(height: 0.5)
                        ForEach(Array(viewModel.sortedTeamOptions.enumerated()), id: \.element.id) { index, option in
                            teamRowView(option)
                            if index < viewModel.sortedTeamOptions.count - 1 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.16))
                                    .frame(height: 0.5)
                            }
                        }
                        #endif
                    }
                }
                #if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA || TARGET_SCOTTISH_PREMIERSHIP || TARGET_LA_LIGA)
                Button {
                    Task { await viewModel.restorePurchases() }
                } label: {
                    Text("Restore Purchases")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(themeTokens.textColor.opacity(0.55))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.plain)
                #endif
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(themeTokens.textColor.opacity(0.55))
                }
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
        .background(StadiumBackground())
        .navigationTitle("App Icon")
        .navigationBarTitleDisplayMode(.inline)
        .trackScreen("AppIconPicker")
        #if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA || TARGET_SCOTTISH_PREMIERSHIP || TARGET_LA_LIGA)
        .task { await viewModel.loadOnce() }
        #endif
    }

    private func freeRowView(_ option: AppIconOption) -> some View {
        let isSelected = viewModel.isSelected(option)
        return Button {
            Task { await viewModel.select(option) }
        } label: {
            HStack(spacing: 12) {
                Image(option.previewImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
                Text(option.displayName)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(themeTokens.textColor)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isSelected ? String(localized: "\(option.displayName), selected", comment: "VoiceOver label for the currently-selected app icon option. Argument: the icon's display name.") : String(localized: option.displayName))
    }

    private func teamRowView(_ option: TeamIconOption) -> some View {
        Button {
            Task { await viewModel.select(option) }
        } label: {
            HStack(spacing: 12) {
                Image(option.previewImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
                Text(option.displayName)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                teamTrailingSlot(option)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(themeTokens.textColor)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(teamRowAccessibilityLabel(option))
    }

    private func teamRowAccessibilityLabel(_ option: TeamIconOption) -> String {
        if !viewModel.isPurchased(option) {
            let price = viewModel.price(for: option) ?? ""
            return String(
                localized: "\(option.displayName), locked, \(price)",
                comment: "VoiceOver label for a locked, purchasable team icon option. Arguments: the option's display name, its price."
            )
        }
        if viewModel.isSelected(option) {
            return String(
                localized: "\(option.displayName), selected",
                comment: "VoiceOver label for the currently-selected team icon option. Argument: the option's display name."
            )
        }
        return String(localized: option.displayName)
    }

    @ViewBuilder
    private func teamTrailingSlot(_ option: TeamIconOption) -> some View {
        if !viewModel.isPurchased(option) {
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                if let price = viewModel.price(for: option) {
                    Text(price)
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .foregroundStyle(themeTokens.textColor.opacity(0.55))
        } else if viewModel.isSelected(option) {
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(themeTokens.textColor)
        }
    }
}
