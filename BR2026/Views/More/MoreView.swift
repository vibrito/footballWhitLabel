import SwiftUI
import UIKit

struct MoreView: View {
    @State private var viewModel: MoreViewModel
    let tabSelectionColorHex: String

    init(service: MatchService, tabSelectionColorHex: String) {
        _viewModel = State(initialValue: MoreViewModel(service: service))
        self.tabSelectionColorHex = tabSelectionColorHex
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
                        viewModel: AppIconPickerViewModel(iconSetting: UIKitAppIconSetting()),
                        selectionColorHex: tabSelectionColorHex
                    )
                }
            }
            .task { await viewModel.loadOnce() }
        }
    }

    private var competitionHeader: some View {
        VStack(spacing: 8) {
            logoView
                .frame(width: 64, height: 64)
            if let name = viewModel.competitionName {
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var logoView: some View {
        if let logoData = viewModel.competitionLogoData, let uiImage = UIImage(data: logoData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
        } else {
            AsyncImage(url: viewModel.competitionLogoURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                default:
                    Circle()
                        .fill(.white.opacity(0.07))
                        .overlay(
                            Image(systemName: "soccerball")
                                .font(.system(size: 28))
                                .foregroundStyle(.white.opacity(0.55))
                        )
                }
            }
        }
    }

    private func sectionView(_ section: MoreSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.titleKey)
                .font(.system(size: 13, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
            GlassCard(cornerRadius: 18, style: .transparent) {
                VStack(spacing: 0) {
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

    private func rowLabel(_ row: MoreRow, showsChevron: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: row.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 24)
            Text(row.titleKey)
                .font(.system(size: 16, weight: .semibold))
            Spacer()
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .foregroundStyle(.white)
        .padding(.vertical, 10)
        // Without this, the row's tappable area stops at the last piece of drawn
        // content (the icon/title on the left, or the chevron on the right) — the
        // `Spacer()` in between has nothing to hit-test against, so tapping the empty
        // middle of the row does nothing.
        .contentShape(Rectangle())
    }
}
