import Foundation

struct MoreRow: Identifiable {
    let id: String
    let titleKey: LocalizedStringResource
    let systemImage: String
    let destination: MoreDestination?
    let isEnabled: Bool
}
