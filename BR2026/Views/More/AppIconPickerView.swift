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
                        // Every free row gets a trailing divider unconditionally — the
                        // purchasable team list below always has at least one row (20 fixed
                        // cases, never empty), so a free row is never the last row overall.
                        ForEach(AppIconOption.allCases) { option in
                            freeRowView(option)
                            Rectangle()
                                .fill(Color.white.opacity(0.16))
                                .frame(height: 0.5)
                        }
                        ForEach(Array(viewModel.sortedTeamOptions.enumerated()), id: \.element.id) { index, option in
                            teamRowView(option)
                            if index < viewModel.sortedTeamOptions.count - 1 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.16))
                                    .frame(height: 0.5)
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
        .navigationTitle("App Icon")
        .navigationBarTitleDisplayMode(.inline)
        .trackScreen("AppIconPicker")
        .task { await viewModel.loadOnce() }
    }

    private func freeRowView(_ option: AppIconOption) -> some View {
        Button {
            Task { await viewModel.select(option) }
        } label: {
            HStack(spacing: 12) {
                Image(option.previewImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(option.displayName)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                if viewModel.isSelected(option) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .foregroundStyle(themeTokens.textColor)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                Text(option.displayName)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                teamTrailingSlot(option)
            }
            .foregroundStyle(themeTokens.textColor)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
