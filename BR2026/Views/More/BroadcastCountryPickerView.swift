import SwiftUI

/// Which country's TV listings match cards show, pushed from More.
///
/// The options are **Automatic plus the countries the data actually carries** — never a world
/// list. Coverage is entered by hand and reaches two countries so far, so offering Japan would
/// be offering a choice that can only ever produce an empty row.
///
/// Automatic follows the device's region and is the default. Picking a country explicitly
/// overrides that permanently, including when the device travels: a deliberate choice is not
/// something the app may quietly revise.
struct BroadcastCountryPickerView: View {
    @Environment(BroadcastCountryStore.self) private var store
    @Environment(\.themeTokens) private var themeTokens

    @ScaledMetric private var rowFontSize: CGFloat = 16
    @ScaledMetric private var footnoteFontSize: CGFloat = 13
    @ScaledMetric private var checkmarkSize: CGFloat = 16

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                GlassCard(cornerRadius: 18, style: .transparent) {
                    VStack(spacing: 0) {
                        row(country: nil)
                        ForEach(store.knownCountries, id: \.self) { code in
                            Divider().overlay(themeTokens.textColor.opacity(0.12))
                            row(country: code)
                        }
                    }
                }
                Text("Only countries with listings are shown. Coverage is partial, so many matches have none.",
                     comment: "Footnote under the broadcast-country picker, explaining why the list is short and why most matches show no channels.")
                    .font(.system(size: footnoteFontSize))
                    .foregroundStyle(themeTokens.textColor.opacity(0.5))
                    .padding(.horizontal, 4)
            }
            .padding(20)
        }
        .scrollContentBackground(.hidden)
        .background(StadiumBackground())
        .navigationTitle(Text("Broadcast Country", comment: "Title of the screen for choosing which country's TV listings to show."))
        .navigationBarTitleDisplayMode(.inline)
        .trackScreen("BroadcastCountry")
    }

    /// `nil` is the Automatic row.
    private func row(country: String?) -> some View {
        let isSelected = store.selected == country
        return Button {
            store.choose(country)
        } label: {
            HStack(spacing: 12) {
                Text(label(for: country))
                    .font(.system(size: rowFontSize, weight: .semibold))
                    .foregroundStyle(themeTokens.textColor)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: checkmarkSize, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Country names come from the system rather than a table of our own: the OS already
    /// translates every region into all five of our languages and keeps up when they change.
    private func label(for country: String?) -> String {
        let automatic = String(localized: "Automatic",
                               comment: "Broadcast-country option meaning: follow the device's own region.")
        guard let country else {
            guard let region = BroadcastCountryStore.deviceRegion,
                  let name = Locale.current.localizedString(forRegionCode: region) else { return automatic }
            return "\(automatic) · \(name)"
        }
        return Locale.current.localizedString(forRegionCode: country) ?? country
    }
}
