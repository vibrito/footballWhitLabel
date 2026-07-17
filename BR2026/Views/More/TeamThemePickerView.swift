import SwiftUI

struct TeamThemePickerView: View {
    @State private var viewModel: TeamThemePickerViewModel
    @Environment(\.themeTokens) private var themeTokens

    init(viewModel: TeamThemePickerViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                GlassCard(cornerRadius: 18, style: .transparent) {
                    VStack(spacing: 10) {
                        rowView(nil)
                        Rectangle().fill(Color.white.opacity(0.16)).frame(height: 0.5)
                        ForEach(Array(viewModel.sortedOptions.enumerated()), id: \.element.id) { index, option in
                            rowView(option)
                            if index < viewModel.sortedOptions.count - 1 {
                                Rectangle().fill(Color.white.opacity(0.16)).frame(height: 0.5)
                            }
                        }
                    }
                }
                Button {
                    Task { await viewModel.restorePurchases() }
                } label: {
                    Text("Restore Purchases")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(themeTokens.textColor.opacity(0.55))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.plain)
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
        .navigationTitle("Team Theme")
        .navigationBarTitleDisplayMode(.inline)
        .trackScreen("TeamThemePicker")
        .task { await viewModel.loadOnce() }
    }

    private func rowView(_ option: TeamThemeOption?) -> some View {
        Button {
            Task { await viewModel.select(option) }
        } label: {
            HStack(spacing: 12) {
                if let option {
                    Text(option.displayName)
                } else {
                    Text("Default")
                }
                Spacer()
                trailingSlot(option)
                    .accessibilityHidden(true)
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(themeTokens.textColor)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel(option))
    }

    private func rowAccessibilityLabel(_ option: TeamThemeOption?) -> String {
        let name = option.map { String(localized: $0.displayName) } ?? String(localized: "Default", comment: "VoiceOver label for the Team Theme picker's non-team default row.")
        if let option, !viewModel.isPurchased(option) {
            let price = viewModel.price(for: option) ?? ""
            return String(
                localized: "\(name), locked, \(price)",
                comment: "VoiceOver label for a locked, purchasable team theme option. Arguments: the option's display name, its price."
            )
        }
        if viewModel.selectedOption == option {
            return String(
                localized: "\(name), selected",
                comment: "VoiceOver label for the currently-selected team theme option (or Default). Argument: the option's display name."
            )
        }
        return name
    }

    @ViewBuilder
    private func trailingSlot(_ option: TeamThemeOption?) -> some View {
        if let option, !viewModel.isPurchased(option) {
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                if let price = viewModel.price(for: option) {
                    Text(price)
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .foregroundStyle(themeTokens.textColor.opacity(0.55))
        } else if viewModel.selectedOption == option {
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(themeTokens.textColor)
        }
    }
}
