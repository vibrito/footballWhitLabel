import SwiftUI

struct TermsOfServiceView: View {
    let config: ChampionshipConfig
    @Environment(\.themeTokens) private var themeTokens

    var body: some View {
        ScrollView {
            Text(String(format: String(localized: "terms_of_service_body"), config.displayName))
                .font(.system(size: 14))
                .foregroundStyle(themeTokens.textColor.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
        .scrollContentBackground(.hidden)
        .background(StadiumBackground())
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
        .trackScreen("TermsOfService")
    }
}
