import SwiftUI

struct AppIconPickerView: View {
    @State private var viewModel: AppIconPickerViewModel

    init(viewModel: AppIconPickerViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                GlassCard(cornerRadius: 18, style: .transparent) {
                    VStack(spacing: 0) {
                        ForEach(Array(AppIconOption.allCases.enumerated()), id: \.element.id) { index, option in
                            rowView(option)
                            if index < AppIconOption.allCases.count - 1 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.16))
                                    .frame(height: 0.5)
                            }
                        }
                    }
                }
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
        .background(StadiumBackground())
        .navigationTitle("App Icon")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func rowView(_ option: AppIconOption) -> some View {
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
                if viewModel.selectedIcon == option {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .foregroundStyle(.white)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
