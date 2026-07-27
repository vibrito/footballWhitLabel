import Foundation

/// Persistence for the reader's broadcast-market choice, abstracted so the store can be
/// unit-tested without touching real `UserDefaults` — mirrors `TeamThemeSetting`.
protocol BroadcastCountrySetting {
    var storedCountry: String? { get set }
    /// Countries the app has actually seen listings for. Persisted so the picker can be
    /// offered before any fetch has landed, rather than showing a list of one.
    var knownCountries: [String] { get set }
}

struct UserDefaultsBroadcastCountrySetting: BroadcastCountrySetting {
    private let countryKey = "selectedBroadcastCountry"
    private let knownKey = "knownBroadcastCountries"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var storedCountry: String? {
        get { defaults.string(forKey: countryKey) }
        nonmutating set {
            if let newValue {
                defaults.set(newValue, forKey: countryKey)
            } else {
                defaults.removeObject(forKey: countryKey)
            }
        }
    }

    var knownCountries: [String] {
        get { defaults.stringArray(forKey: knownKey) ?? [] }
        nonmutating set { defaults.set(newValue, forKey: knownKey) }
    }
}

/// Which country's channels the app shows.
///
/// Two states, and the order between them is the design: an explicit choice always wins, and
/// the device's region is only the default for someone who has never chosen. A stored value
/// is only ever written by the picker, so its presence means the reader decided deliberately
/// and nothing may quietly override it.
///
/// There is no fallback to another country. A match with no listing in the resolved region
/// shows none — offering a channel the reader demonstrably cannot get is worse than saying
/// nothing.
@MainActor
@Observable final class BroadcastCountryStore {
    private var setting: BroadcastCountrySetting

    /// The reader's explicit pick, or nil when following the device.
    private(set) var selected: String?

    /// Every country the app has seen a listing for — what the picker offers. Built from the
    /// data rather than a world list: coverage is hand-entered and reaches two countries so
    /// far, so a fixed list would offer choices that can only produce an empty row.
    private(set) var knownCountries: [String]

    init(setting: BroadcastCountrySetting = UserDefaultsBroadcastCountrySetting()) {
        self.setting = setting
        self.selected = setting.storedCountry
        self.knownCountries = setting.knownCountries
    }

    /// nil means "follow the device", the default and the common case.
    func choose(_ country: String?) {
        let normalized = country?.uppercased()
        selected = normalized
        setting.storedCountry = normalized
    }

    /// Record the countries a fetch turned up. Idempotent; writes only on something new.
    func observe(countries: [String]) {
        let merged = Set(knownCountries).union(countries.map { $0.uppercased() })
        guard merged.count != knownCountries.count else { return }
        knownCountries = merged.sorted()
        setting.knownCountries = knownCountries
    }

    /// The country whose listings to show. Explicit pick first, then the device's region.
    var resolved: String? { selected ?? Self.deviceRegion }

    /// The device's region, e.g. "BR". Nil on a device with none set, in which case nothing
    /// is shown until the reader picks — honest, since we would otherwise be guessing whose
    /// television they own.
    static var deviceRegion: String? {
        Locale.current.region?.identifier.uppercased()
    }
}
