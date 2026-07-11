import SwiftUI

struct MoreView: View {
    @State private var viewModel = MoreViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
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
            GlassCard(cornerRadius: 18) {
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
    }
}
