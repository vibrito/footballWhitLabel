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
                    VStack(spacing: 0) {
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
    }

    private func rowView(_ option: TeamThemeOption?) -> some View {
        Button {
            Task { await viewModel.select(option) }
        } label: {
            HStack(spacing: 12) {
                if let option {
                    Circle()
                        .fill(Color(hex: option.previewColorHex))
                        .frame(width: 28, height: 28)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
                    Text(option.displayName)
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.07))
                        .frame(width: 28, height: 28)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
                    Text("Default")
                }
                Spacer()
                trailingSlot(option)
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(themeTokens.textColor)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
