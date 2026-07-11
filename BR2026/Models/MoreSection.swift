import Foundation

struct MoreSection: Identifiable {
    let id: String
    let titleKey: LocalizedStringResource
    let rows: [MoreRow]
}
