import Foundation

/// Purchasable alternate app icons, one per Brasileirão team — a structural twin of
/// `TeamThemeOption`, but a fully independent purchase: owning a team's Theme grants
/// nothing toward its Icon, and vice versa. Always declared for every championship target
/// (same reasoning as `TeamThemeOption` — a zero-case `enum ...: String` fails to compile,
/// and per-target case gating would leave other targets with none at all); visibility is
/// gated at the UI layer instead, mirroring `MoreViewModel`'s `#if` around the "Team Theme"
/// row.
enum TeamIconOption: String, CaseIterable, Identifiable, PurchasableCatalogOption {
    case palmeiras
    case flamengo
    case fluminense
    case athleticoParanaense
    case bahia
    case redBullBragantino
    case coritiba
    case saoPaulo
    case atleticoMineiro
    case corinthians
    case cruzeiro
    case internacional
    case remo
    case botafogo
    case vitoria
    case mirassol
    case chapecoense
    case santos
    case gremio
    case vascoDaGama

    var id: String { rawValue }

    /// Same live-API team IDs `TeamThemeOption.teamID` uses — both catalogs describe the
    /// same 20 real-world teams, so the App Icon picker can sort by the same standings data
    /// without a second ID mapping to maintain.
    var teamID: Int {
        switch self {
        case .palmeiras: 121
        case .flamengo: 127
        case .fluminense: 124
        case .athleticoParanaense: 134
        case .bahia: 118
        case .redBullBragantino: 794
        case .coritiba: 147
        case .saoPaulo: 126
        case .atleticoMineiro: 1062
        case .corinthians: 131
        case .cruzeiro: 135
        case .internacional: 119
        case .remo: 1198
        case .botafogo: 120
        case .vitoria: 136
        case .mirassol: 7848
        case .chapecoense: 132
        case .santos: 128
        case .gremio: 130
        case .vascoDaGama: 133
        }
    }

    /// Matches `TeamThemeOption.displayName` exactly (both already dropped the "(Home)"
    /// suffix) so the same team reads identically in both pickers.
    var displayName: LocalizedStringResource {
        switch self {
        case .palmeiras: "Palmeiras"
        case .flamengo: "Flamengo"
        case .fluminense: "Fluminense"
        case .athleticoParanaense: "Athletico Paranaense"
        case .bahia: "Bahia"
        case .redBullBragantino: "Red Bull Bragantino"
        case .coritiba: "Coritiba"
        case .saoPaulo: "São Paulo"
        case .atleticoMineiro: "Atlético Mineiro"
        case .corinthians: "Corinthians"
        case .cruzeiro: "Cruzeiro"
        case .internacional: "Internacional"
        case .remo: "Remo"
        case .botafogo: "Botafogo"
        case .vitoria: "Vitória"
        case .mirassol: "Mirassol"
        case .chapecoense: "Chapecoense"
        case .santos: "Santos"
        case .gremio: "Grêmio"
        case .vascoDaGama: "Vasco da Gama"
        }
    }

    /// The App Icon Set name for `UIApplication.setAlternateIconName(_:)` — derived by
    /// capitalizing the raw value's first letter rather than a 20-way switch, since every
    /// raw value above is already a valid capitalized-identifier-minus-first-letter (verified
    /// by `TeamIconOptionTests.assetNames()` for the three cases whose asset-catalog token
    /// doesn't match its `design/BR2026/` source filename: `athleticoParanaense`,
    /// `redBullBragantino`, `vascoDaGama` — see Task 3's source→destination mapping table).
    var iconAssetName: String { "AppIcon-\(rawValue.prefix(1).uppercased() + rawValue.dropFirst())" }

    /// The plain Image Set used for this option's preview thumbnail — same
    /// App-Icon-Set-vs-plain-Image-Set distinction `AppIconOption.previewImageName` documents.
    var previewImageName: String { "AppIconPreview-\(rawValue.prefix(1).uppercased() + rawValue.dropFirst())" }

    var productID: String { "com.vibrito.br2026.icon.\(rawValue)" }

    static func rawValue(fromProductID productID: String) -> String? {
        let prefix = "com.vibrito.br2026.icon."
        guard productID.hasPrefix(prefix) else { return nil }
        return String(productID.dropFirst(prefix.count))
    }
}
