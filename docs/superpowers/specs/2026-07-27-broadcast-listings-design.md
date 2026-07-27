# Broadcast Listings on Match Cards — Design

**Date:** 2026-07-27
**Status:** Approved, pending implementation
**Repos:** `footballWhiteLabel` (BR2026 and its five sibling targets), `worldcup` (Fixture 2026)

## Goal

Show each match's broadcast listings as chips on the match card, and let the user
narrow them to a single country from Settings.

## Why this shape

The backend has exposed `?include=broadcasts` for a while and neither app consumes it.
Coverage measured on 2026-07-27:

| Competition | Matches | With listings | BR listings | PT listings |
|---|---|---|---|---|
| BSA | 380 | 45 | 77 | 8 |
| PPL | 306 | 0 | — | — |
| SPL | 198 | 0 | — | — |

Every design decision below follows from three facts in that table:

1. **Only Brasileirão has data.** Five of the six white-label targets, and two of
   Fixture 2026's three live competitions, would ship a feature that never appears.
2. **Coverage is 12% and hand-entered.** It grows when someone types it in, not when a
   feed fills. "No listings" is the normal state, not an error.
3. **A match carries several countries at once.** Brasileirão fixtures routinely list
   both Brazilian and Portuguese broadcasters; Canal 11 is noise in São Paulo and Globo
   is noise in Lisbon.

Listings per match top out at 4 (3 within a single country), so chips fit on a card
without an overflow affordance.

## Scope

**In:** the `Broadcast` model and its decoding, `?include=broadcasts` on the matches
request, chips on `FixtureMatchCard`/`HeroMatchCard` (BR2026) and
`MatchCard`/`HeroMatchCard` (Fixture 2026), the country setting and its picker screen,
and the VoiceOver treatment for all of it.

**Out:** listings in the match-detail sheet; `BracketMatchCard` (World Cup knockout, no
listings); any listing UI on the marketing site; automated capture of broadcast data.

## Model

A value type, defined separately in each app. Per the standing decision that cross-app
UI parity is a values copy rather than a synced file until the two `Match` models
unify, this is **not** added to `scripts/sync-crests.sh`.

```swift
struct Broadcast: Codable, Sendable, Hashable {
    let name: String
    let type: BroadcastType
    let country: String   // exactly two ASCII letters, uppercased
    let url: URL?
}

enum BroadcastType: String, Codable, Sendable, CaseIterable {
    case freeTV, payTV, streaming, ppv, other
}
```

**Decoding rules.**

- `type` maps `FREE_TV`/`PAY_TV`/`STREAMING`/`PPV`; any other value, including a
  missing one, decodes to `.other`. It never throws. The `MatchStatus` bug that broke
  live scores in every shipped app came from a decoder that recognised only the values
  known at the time — this one is written not to repeat it.
- `country` is validated against `^[A-Za-z]{2}$` and uppercased. A listing that fails
  is dropped, not defaulted. Same rule as `COUNTRY_CODE_RE` in `fixture-live/assets/data.js`.
- `logo` is not decoded. It is null on every listing the API has ever returned; a
  property that is always nil is a property that will be misread as "loading".
- `url` is optional and genuinely varies — present on the Portuguese listings, absent on
  most Brazilian ones. It is captured but not yet used; tappable chips are out of scope.

**Ordering.** Listings sort `freeTV → payTV → streaming → ppv → other`, then by name
for stability. This is the same order `BROADCAST_TYPE_ORDER` uses in
`fixture-live/assets/data.js`, so a given match reads identically in the app and on the
web. The cheapest way to watch reads first.

## Data flow

### BR2026

`MatchDTO` gains `let broadcasts: [BroadcastDTO]?`.

`Match` is a SwiftData `@Model`, so it gains `var broadcasts: [Broadcast] = []`.
SwiftData stores a Codable value type as an opaque blob; a property with a default
value is a lightweight migration, so existing installs open their store unchanged and
backfill on the next refresh. The array is never used in a `#Predicate` — it cannot be.

`Match.init(dto:)` and `Match.update(from:)` both assign it, so a match that gains
listings mid-season picks them up on the next upsert rather than only on first insert.

`LiveMatchService.fetchMatches()` appends `?include=broadcasts` to its URL. The
parameter is undocumented and unvalidated upstream — a typo returns 200 with the key
simply absent — so the decoding must treat a missing `broadcasts` key as `[]` and never
as a failure.

### Fixture 2026

`APIMatch` gains the same optional field, the `Match` struct gains
`let broadcasts: [Broadcast]`, and `MatchMapper+League` passes it through.
`LeagueMatchService` adds the query item to its three `competitions/{code}/matches`
calls.

`LiveMatchService` (the World Cup backend) does **not** send it. That backend has no
listings to return, so there is nothing to ignore, and its mapper supplies `[]`.

## Chips

A row appended below the team rows, inside the card, separated by the same
0.5pt `white @ 0.10` divider the team rows already use between themselves.

- Leading `tv` SF Symbol, 11pt, `white @ 0.40`. SF Symbols only — no emoji, per the
  Assets guideline.
- Chip: 11pt bold, 13pt corner radius, `white @ 0.08` fill, 0.5pt `white @ 0.14`
  border, `white @ 0.82` label.
- **Free-to-air chip:** teal `#2dd4bf` through the derived-accent recipe already in the
  design system — fill at 18%, border at 45%, label at full. Teal is the app's existing
  "good" semantic, and staying off the accent colour keeps a free-to-air chip from
  reading as a live indicator.
- **Country code** appears on the chip only when the filter is "All countries", as a
  9pt `white @ 0.55` suffix behind a hairline. Under a specific country it is redundant.
- All sizes go through `@ScaledMetric`, like every other font and icon size in the app.

**Empty state: the row is omitted entirely.** The approved mock showed a
"transmissão ainda não confirmada" line, which read well when 1 card in 3 was empty. In
the real data it is 7 in 8 — under "All countries" the line would appear on 335 of 380
matches and add roughly 26pt to nearly every card in the app. Absence is quieter and
more honest than a season-long apology. Revisit if coverage passes ~50%.

**Applied to:** `FixtureMatchCard` and `HeroMatchCard` (BR2026); `MatchCard` and
`HeroMatchCard` (Fixture 2026). `FixtureMatchCard` serves both the Fixtures list and
the Matchday rows, so one change covers both screens.

## Country setting

**Persistence.** `BroadcastCountrySetting` protocol plus
`UserDefaultsBroadcastCountrySetting`, mirroring `TeamThemeSetting` in BR2026 and
`ThemeSetting` in Fixture 2026 (each app follows its own existing house style for the
protocol's shape). Key `selectedBroadcastCountry`. `nil` means All countries, and that
is the default — the user opts into filtering rather than out of it.

**Availability is discovered, never hardcoded.** `BroadcastCountryStore` (`@Observable`,
`@MainActor`) holds the selection and a set of country codes seen in the data. Every
ViewModel that loads matches hands its results to `noteAvailability(in:)`, which unions
the codes into a second UserDefaults key (`knownBroadcastCountries`).

Call sites: `MatchdayViewModel.load()` and `FixturesViewModel.load()` in BR2026;
`LeagueTodayViewModel.load(service:)` and `FixturesViewModel.load(service:)` in
Fixture 2026 — at both the cached-read and fresh-fetch points, so a cold launch on
cached data still populates the picker.

The union only grows within an install. A country that vanishes from the feed lingers
in the picker, which is the right failure: a selection the user made stays selectable.

This is deliberately not "read `service.cachedMatches()` from the settings screen" —
that works in BR2026, which has SwiftData, and not in Fixture 2026, which has no local
store to read back. One mechanism across both apps is worth the extra UserDefaults key.

**Row visibility.** The settings row renders only when the known-country set is
non-empty. In the five leagues with no data there is no row, no chips, and nothing to
explain; the row appears on its own the first time a refresh returns a listing, with no
code change and no release. The empty set is the launch state for those targets, so this
is the common path and must be tested as such.

**Row name: "TV & Streaming."** Not "Where to Watch" — that promises completeness 12%
coverage cannot back.

**Picker screen.** Follows `AppIconPickerView`/`ThemePickerView` in each app: a
single-selection list with a checkmark. "All countries" first, then each known country
rendered as its flag and `Locale.current.localizedString(forRegionCode:)`, sorted by
that localized name. A country's own display name is system-provided, so it needs no
entry in the string catalog.

## Filtering

`Match.broadcasts(for: String?)` returns, sorted:

- `nil` (All countries) → every listing on the match.
- a country code → only listings whose `country` matches, exactly. Strict: a match with
  no listing in the selected country shows no row. It does not fall back.

## Accessibility

Both cards are already `.accessibilityElement(children: .combine)` with an explicit
`accessibilityLabel`, so chips must not become separate elements. Listings append to
the existing label with the **type spoken**, not merely tinted:

> "Bahia 1, Corinthians 1, final score. Available on Globo, free to air; Premiere, pay
> per view; GE TV, streaming."

Colour alone never carries the free-to-air distinction — it is redundant with sort
position and with this label. Type names are localized; the broadcaster name is
server-driven content and is spoken as-is, like team and venue names.

When no listings show, nothing is appended and the label is byte-identical to today's.

## Localization

New keys, in both apps' catalogs, across `pt-BR`, `pt-PT`, `fr`, `en-US`, `en-GB`:

| Purpose | BR2026 style | Fixture 2026 style |
|---|---|---|
| Settings row + picker title | `TV & Streaming` | `settings.broadcast` |
| "All countries" option | `All countries` | `broadcast.all` |
| VoiceOver lead-in | `Available on %@` | `accessibility.broadcast %@` |
| Free-to-air | `free to air` | `broadcast.type.free` |
| Pay TV | `pay TV` | `broadcast.type.paytv` |
| Streaming | `streaming` | `broadcast.type.streaming` |
| Pay per view | `pay per view` | `broadcast.type.ppv` |

BR2026 uses `String(localized:)` with the English string as key; Fixture 2026 uses
short dotted keys. Each app keeps its own convention.

`.other` has no user-facing name: an unrecognised type renders as a plain chip and is
spoken as the broadcaster name alone. There is no honest label for a value we do not
recognise.

Interpolated keys must use `%@` for strings. The catalog has silently broken before on
`%lld` versus `%@` mismatches, so the lead-in key takes a single pre-joined string
rather than a count.

## Testing

Swift Testing, `MockMatchService`, no SwiftData container, no View tests.

**Decoding** — unknown `type` decodes to `.other`; absent `type` decodes to `.other`;
a three-letter or one-letter `country` drops the listing; a lowercase `country`
uppercases; an absent `broadcasts` key yields `[]` rather than throwing; a null `logo`
is ignored; an absent `url` yields nil.

**Ordering** — a match with one of each type returns them free-to-air first and PPV
last; two listings of the same type order by name.

**Filtering** — `nil` returns all; `"BR"` returns only Brazilian listings; a country
with no listing on that match returns empty; a country absent from the whole dataset
returns empty.

**Store** — a fresh store reports no known countries and hides the row; after
`noteAvailability(in:)` with mixed BR/PT matches it reports both, sorted; a second call
with only BR still reports both (union, not replace); the selection round-trips through
a stubbed setting; selecting a country and then clearing it returns to All countries.

**ViewModels** — `MatchdayViewModel`/`FixturesViewModel` (BR2026) and
`LeagueTodayViewModel`/`FixturesViewModel` (Fixture 2026) populate the store's known
countries from both the cached and freshly-fetched paths.

**Fixtures.** `MockDataProvider.matchesJSON` gains `broadcasts` on a few matches,
covering: a match with a free-to-air listing, a match with BR and PT listings together,
a match with an unrecognised type, and — the common case — matches with the key absent
entirely. Fixture 2026's mock gains the equivalent.

## Risks

**A schema migration on a shipped app.** Adding a defaulted property to a SwiftData
`@Model` is a lightweight migration, but BR2026 is live in the App Store with real
installs. The upgrade path — install the previous build, then run this one against the
same store — must be exercised on a device before release, not assumed.

**A dead feature in five targets.** If the discovery mechanism is wrong, the row either
never appears in Brasileirão or appears empty in the other five. Both failure modes are
invisible in a build that runs only against BSA mock data, which is why the empty-set
case is called out as a required test above.

**Card height changes with data.** A card gains ~26pt the moment its match acquires a
listing. On Matchday and Fixtures this can shift content during a background refresh —
the same class of jump that made `loadOnce()` fire only once. Chips must be part of the
card's normal layout, not an overlay or an animated insertion.
