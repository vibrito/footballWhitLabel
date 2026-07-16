import Foundation

enum AppIconOption: String, CaseIterable, Identifiable {
    case light
    // Stadium is a Brasileirão-specific alternate icon. Other championship
    // targets share this file but must not offer it — see `ChampionshipConfig`'s
    // per-target #if selection in `Championship.swift` for the same pattern.
    #if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA || TARGET_SCOTTISH_PREMIERSHIP || TARGET_LA_LIGA)
    case stadium
    #endif

    var id: String { rawValue }

    var displayName: LocalizedStringResource {
        switch self {
        case .light: "Default"
        #if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA || TARGET_SCOTTISH_PREMIERSHIP || TARGET_LA_LIGA)
        case .stadium: "Stadium"
        #endif
        }
    }

    /// The App Icon Set name for `UIApplication.setAlternateIconName(_:)`. `nil` means the
    /// primary icon — that's the API's own convention for "reset to default", not a gap here.
    var iconAssetName: String? {
        switch self {
        case .light: nil
        #if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA || TARGET_SCOTTISH_PREMIERSHIP || TARGET_LA_LIGA)
        case .stadium: "AppIcon-Stadium"
        #endif
        }
    }

    /// The plain Image Set used for this option's preview thumbnail in the picker (distinct
    /// from `iconAssetName`, which names an App Icon Set — App Icon Set assets aren't reliably
    /// loadable via plain SwiftUI `Image(_:)` across iOS versions).
    var previewImageName: String {
        switch self {
        case .light:
            #if TARGET_PREMIER_LEAGUE
            "AppIconPreview-PremierLeague"
            #elseif TARGET_LIGUE_1
            "AppIconPreview-Ligue1"
            #elseif TARGET_PRIMEIRA_LIGA
            "AppIconPreview-PrimeiraLiga"
            #elseif TARGET_SCOTTISH_PREMIERSHIP
            "AppIconPreview-ScottishPremiership"
            #elseif TARGET_LA_LIGA
            "AppIconPreview-LaLiga"
            #else
            "AppIconPreview-Light"
            #endif
        #if !(TARGET_PREMIER_LEAGUE || TARGET_LIGUE_1 || TARGET_PRIMEIRA_LIGA || TARGET_SCOTTISH_PREMIERSHIP || TARGET_LA_LIGA)
        case .stadium: "AppIconPreview-Stadium"
        #endif
        }
    }
}
