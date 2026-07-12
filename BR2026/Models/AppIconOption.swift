import Foundation

enum AppIconOption: String, CaseIterable, Identifiable {
    case light
    case brasil
    case stadium

    var id: String { rawValue }

    var displayName: LocalizedStringResource {
        switch self {
        case .light: "Light"
        case .brasil: "Brasil"
        case .stadium: "Stadium"
        }
    }

    /// The App Icon Set name for `UIApplication.setAlternateIconName(_:)`. `nil` means the
    /// primary icon — that's the API's own convention for "reset to default", not a gap here.
    var iconAssetName: String? {
        switch self {
        case .light: nil
        case .brasil: "AppIcon-Brasil"
        case .stadium: "AppIcon-Stadium"
        }
    }

    /// The plain Image Set used for this option's preview thumbnail in the picker (distinct
    /// from `iconAssetName`, which names an App Icon Set — App Icon Set assets aren't reliably
    /// loadable via plain SwiftUI `Image(_:)` across iOS versions).
    var previewImageName: String {
        switch self {
        case .light: "AppIconPreview-Light"
        case .brasil: "AppIconPreview-Brasil"
        case .stadium: "AppIconPreview-Stadium"
        }
    }
}
