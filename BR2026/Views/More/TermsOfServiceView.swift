import SwiftUI

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            Text("terms_of_service_body")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
        .scrollContentBackground(.hidden)
        .background(StadiumBackground())
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }
}
