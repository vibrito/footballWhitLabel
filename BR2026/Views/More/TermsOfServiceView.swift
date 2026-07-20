import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.themeTokens) private var themeTokens
    @ScaledMetric private var bodyFontSize: CGFloat = 14

    var body: some View {
        ScrollView {
            Text(String(localized: "terms_of_service_body"))
                .font(.system(size: bodyFontSize))
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
