import Foundation

/// How a broadcaster carries a match. Ordered free-to-air first — a stable, predictable
/// sequence rather than a claim about which is better; nothing in the UI emphasises a tier.
enum BroadcastType: String, Codable, Comparable, Sendable {
    case freeTV = "FREE_TV"
    case payTV = "PAY_TV"
    case streaming = "STREAMING"
    case ppv = "PPV"

    private var rank: Int {
        switch self {
        case .freeTV: 0
        case .payTV: 1
        case .streaming: 2
        case .ppv: 3
        }
    }

    static func < (lhs: BroadcastType, rhs: BroadcastType) -> Bool { lhs.rank < rhs.rank }
}

/// One broadcaster showing a match in one country.
///
/// Deliberately **not** stored on the SwiftData `Match`. Listings are an enrichment on top of
/// the fixture, and adding a composite attribute to that model would mean a schema change to
/// the type every screen depends on — a model that has already crashed SwiftData's schema
/// reflection once (see `Team`). They are held in memory for the life of a launch instead, so
/// a cold start shows its cached cards immediately and the chips arrive with the refresh.
///
/// No logo: the API's field is null on every listing seen, so there is nothing to render.
struct Broadcast: Equatable, Sendable {
    let name: String
    let type: BroadcastType
    let country: String
    let url: URL?
}

/// The JSON shape. Separate from `Broadcast` so the model stays free of decoding concerns —
/// the same split `Team`/`TeamDTO` uses.
struct BroadcastDTO: Decodable {
    let name: String
    let type: String
    let country: String
    let url: String?
    /// Decoded but unused: null on every listing the API has returned. Kept so a future
    /// value is not silently dropped.
    let logo: String?

    /// nil for a type we do not recognise. Dropping the listing beats guessing a tier:
    /// sorting one wrongly would tell someone a pay-per-view match is free to air.
    var model: Broadcast? {
        guard let kind = BroadcastType(rawValue: type) else { return nil }
        return Broadcast(name: name, type: kind, country: country.uppercased(),
                         url: url.flatMap(URL.init(string:)))
    }
}

extension Collection where Element == Broadcast {
    /// This match's listings for one country, cheapest way to watch first.
    ///
    /// No cross-country fallback. If the reader has asked for Portugal and the match has no
    /// Portuguese listing, the honest answer is none — offering a Brazilian channel they
    /// cannot get is worse than saying nothing, and quietly overriding an explicit choice is
    /// a bug rather than a courtesy.
    func inCountry(_ country: String?) -> [Broadcast] {
        guard let country else { return [] }
        return filter { $0.country.caseInsensitiveCompare(country) == .orderedSame }
            .sorted { $0.type < $1.type }
    }
}
