# Roadmap

**Status pass: 2026-07-26.** Item statuses below were re-checked against the repo on that date.
Anything marked ✅ was verified in code or git history; anything about App Store Connect state
is marked as recorded-but-unverified, because it cannot be checked from here.

> ### ⏭️ Next up: #6, the where-to-watch page
> The broadcasts API exists and neither app consumes it. Read #6 before scoping — the data is
> **hand-curated through a separate front-end**, so its coverage is a function of manual effort,
> not an API gap that will fill in on its own.

**App Store state (as recorded 2026-07-22, not verifiable from this repo):**

- BR2026 was **rejected 2026-07-20** under Guideline 4.1 / 4.2.2. The metadata, disclaimer and
  URL scrub was done for BR2026 only — the other five apps carry the same exposure.
- IAP was re-enabled 2026-07-22 once Apple's Paid Apps Agreement cleared (`3867b49`), with a
  per-IAP allowlist gating which purchases are offered (`df156c3`). All 40 products were created
  in App Store Connect via the API, staged but not submitted.
- Earlier context: Ligue 1 2026 and Liga Portugal 2026 were rejected 2026-07-13 under Guideline
  4.3(a) for templated metadata across apps — see CLAUDE.md's Fastlane section, which treats
  this as a standing recurrence check rather than a style preference.

## 1. In-app-purchase team themes ✅ Shipped 2026-07-16

Purchasable per-team customization: alternate app icon, accent colors, and the purchased
team featured in the Matchday hero card, always where possible.

## 2. More championships ✅ Shipped 2026-07-16

Add Scottish Premiership and La Liga, on top of the four already shipped (Brasileirão,
Premier League, Ligue 1, Liga Portugal).

- ✅ **Scottish Premiership — shipped 2026-07-16.** 5th Xcode target
  (`ScottishPremiership2026`), mirrors the existing 4-target pattern exactly, no new
  locale needed. Real app icon/launch artwork wired in. Bundle ID
  (`com.vibrito.scottishpremiership2026`) registered, its own App Store Connect app record
  created, and its own dedicated Firebase project (`scottish-premiership-2026`) set up —
  no longer shares `BR2026`'s.
- ✅ **La Liga — shipped 2026-07-16.** 6th Xcode target (`LaLiga2026`), mirrors the
  existing target pattern. Real app icon and launch screen wired in, `CrossAppLink.laLiga`
  added, and Terms of Service's hardcoded Brasileirão reference fixed for all targets.
  Spanish (`es`) localization added for all 39 shared UI strings, satisfying the
  app-wide localization requirement below. Bundle ID (`com.vibrito.laliga2026`) registered,
  its own App Store Connect app record created, and its own dedicated Firebase project
  (`la-liga-2026`) set up — no longer shares `BR2026`'s.
- All 6 apps (Brasileirão, Premier League, Ligue 1, Liga Portugal, Scottish Premiership,
  La Liga) are on TestFlight as of 2026-07-16 at version 1.1, build 8 — same build number
  across all apps.

La Liga brought Spain into the supported-locale set, so **Spanish localization was needed
app-wide** as a direct consequence of this item — not a separate, optional task.

## 3. Accessibility ✅ Shipped — verified 2026-07-26

The original note ("nothing in the codebase was built with this in mind as of 2026-07-13") is
no longer true. What actually landed:

- **Dynamic Type** throughout, via `@ScaledMetric`, capped app-wide at `.accessibility1` —
  designed in `docs/superpowers/specs/2026-07-17-dynamic-type-design.md`.
- **VoiceOver** labels and hints across the match surfaces; `Match+Accessibility` and
  `MatchEvent.accessibilityLabel` carry purpose-built descriptions rather than read-outs.
- **Contrast**, via `BR2026/Models/WCAGContrast.swift` — AA-checked, with a real API case
  behind it (a team returning `fontColor: ffffff` on `mainColor: f7f7f7`).
- **Reduced motion** handled in `LiveChip`, `RefreshPulseDot` and `FixturesView`.
- **An audit suite**, `BR2026UITests/AccessibilityAuditUITests.swift`.

Treat this as ongoing polish rather than a pending project — 2026-07-26 alone fixed an
unlocalized VoiceOver hint and added assist announcements to the timeline.

## 4. Push notifications — scaffolding only

Notify users about the teams they've purchased a theme for (via item #1).

Plumbing exists and is deliberately inert: `AppDelegate` calls `registerForRemoteNotifications()`
and mints an FCM token, `aps-environment` and the `remote-notification` background mode are set.
But **nothing calls `UNUserNotificationCenter.requestAuthorization`**, so no prompt and no
user-visible push exists. The remaining work is a permission flow, a reason to ask for it, and
something that consumes a push.

## 5. Apple Watch, CarPlay, and Widgets — partly built in the sibling app

Companion experiences across the platform.

Not started in this repo. Note the Fixture 2026 app **already has** a Watch app and a Watch
widget (`Fixture2026Watch Watch App`, `Fixture2026WatchWidget`), currently hidden from its iOS
submission (`9be964b`). Whatever is built here should look at those first rather than starting
from scratch.

## 6. Where-to-watch page — ⏭️ NEXT UP (agreed 2026-07-26)

Location-based broadcast channel listings per match — show which channels are airing a
given match based on the user's location.

**The API already exists and nothing in either app consumes it yet.**
`GET /v4/competitions/{code}/matches?include=broadcasts` adds a `broadcasts` array to each
match: `name`, `type`, `country`, `url`, `logo`.

**The data is entered by hand.** There is a separate front-end for populating these listings,
and as of 2026-07-26 no automated way to harvest them has been found. This is the single most
important design input, and it is easy to miss because "we have the API" sounds like "we have
the data":

- Coverage will not improve on its own. It tracks how much manual entry has happened, so the
  app must degrade gracefully and permanently, not just until some backfill lands.
- Whatever the UI promises should be honest about partial coverage. "Where to watch" implies
  completeness; something nearer "Broadcasters (where known)" does not over-promise.
- Adding a competition to the app does **not** add its listings — PPL returns zero today.
- **Automating capture is itself an open problem, and arguably the higher-value one.** If it is
  ever solved, the app side needs no change; if it is not, the feature stays a curated
  best-effort for the fixtures that matter most. Worth deciding which of those the UI is being
  designed for before building it.

Verified against the live API on 2026-07-26 — read these before scoping, several will shape
the design:

- **Coverage is thin and BSA-only.** 13 of 380 `BSA` matches carried broadcasts (the current
  round). `PPL` returned 306 matches and **zero**. Whatever the UI does must treat "no
  listings" as the normal case, not an error state.
- **Two countries so far**, and the set varies over time: 20 `BR` listings and 8 `PT` across
  28 total.
- **`type` is a useful axis**: `PPV` (12), `PAY_TV` (8), `STREAMING` (5), `FREE_TV` (3).
  Worth grouping or badging by it — "free to air" is the answer most people want.
- **`url` is populated for some listings** — 8 of 28, all `PT` (e.g. Canal 11, Betclic). So a
  listing can sometimes be tappable and sometimes not; the row has to handle both.
  (This is a change: CLAUDE.md previously recorded `url` as always-null. Corrected there.)
- **`logo` is still always null** across all 28. Don't design around broadcaster logos.
- **The endpoint is unvalidated.** `include=bogus` returns 200 with the `broadcasts` key
  simply absent rather than an error, so a typo fails silently.
- **`country=` filters correctly but has no fallback.** An uncovered country returns empty,
  and an invalid code is indistinguishable from a valid-but-uncovered one. A country picker
  must therefore omit `country=` and be built from whatever the response contains — filtering
  server-side would hide the very options the picker exists to offer.

Open questions for the design session: where it lives (match detail vs its own screen), how
country is chosen (device locale vs explicit picker vs both), and what to show for the ~97% of
matches with no listings at all.

## 6b. Relegation and Libertadores zones in Standings ✅ Shipped — verified 2026-07-26

Zone markers exist: `Standing.zoneDescription` classifies each position from the raw API
description, and `StandingsView` renders the markers. Confirmed by `c37e580`, which *hides*
them for the Scottish Premiership — a competition-specific exception only meaningful if the
feature ships everywhere else.

## 6c. Standings table redesign/polish — partly done, not scoped

A general visual/UX pass on the Standings screen itself (layout, columns, readability) —
distinct from the zone-marker item above.

Some polish has landed opportunistically rather than as a planned pass: `a9b802f` removed the
team crest ball from Standings rows (and `acec959` did the same for Fixtures rows) after they
proved illegible at that size. The broader redesign is still unscoped.

## 7. Cross-app linking

Link between all the family's apps so users can discover sibling apps. The `CrossAppLink`
model and resolver already exist in the codebase but are deliberately not wired into any
View yet — this stays hidden until the 3 newly submitted apps are actually approved and
live, not just submitted.

## 8. A proper marketing website — compliance site shipped, the "presentable" one is not

**Correction:** the site is on **Cloudflare Pages** (project `br26`, `br26-80k.pages.dev`), not
Netlify as this item previously said.

What exists: `website/` serves an index plus six per-app pages (`br2026`, `premier-league`,
`ligue-1`, `liga-portugal`, `la-liga`, `sp2026`). It is fully static — no Pages Functions, no
build step, no API key — after the live matchday section was removed on 2026-07-26 for showing
matches bucketed by the *visitor's* calendar day.

**It is load-bearing for the App Store**: every app's `privacy_url`, `support_url` and
`marketing_url` points at it, so a 404 there puts all six listings out of compliance at once.
Do not rename paths or delete the project without migrating those URLs and pushing metadata
first.

Still open: the original ambition — something genuinely presentable that advertises the family
together, rather than the minimum needed to satisfy review.

## 9. Matchday and Fixtures have converged — decide whether they should merge

**Noted 2026-07-26.** These two screens started out distinct and have quietly grown into
near-neighbours. Both now render the same `FixtureMatchCard`, both group by match status under
the same `SectionHeader`, and as of today both order those groups the same way: live first,
then still-to-come, then finished.

What actually differs is smaller than what is shared:

| | Matchday | Fixtures |
|---|---|---|
| Scope | one matchday | one round, chosen from a picker |
| Hero card | yes — the featured match | no |
| Grouping | Also Today / Finished | Live now / Upcoming-or-Later today / Finished |
| Section source | two `MatchdayViewModel` properties | `FixturesViewModel.sections` |

Matchday is roughly "Fixtures for the current round, with a hero on top and no round picker."
The same convergence happened in the Fixture 2026 app, where `LeagueTodayContent` and its
Fixtures screen have the same relationship.

Worth deciding deliberately rather than letting it drift further. Options, unranked:

- Keep both, and extract the shared grouping so section order and labels cannot diverge again.
  Today they are kept in step by hand, which is how the ordering got inconsistent in the first
  place.
- Fold Matchday into Fixtures as a "current round" default, with the hero as a Fixtures
  affordance rather than a separate screen. Removes a tab.
- Leave as-is and accept the duplication, on the grounds that Matchday's job (one glance,
  today) is genuinely different from Fixtures' (browse the season).

Related: the two apps' `Match` models are also slated for unification, which would make any
shared component genuinely shareable across repos instead of hand-copied. Worth sequencing
these together — see the cross-app parity spec,
`docs/superpowers/specs/2026-07-26-cross-app-match-ui-parity-design.md`.

## 10. Serve the *futebol de botão* discs from the backend (requested 2026-07-27)

`CrestDisc` draws a club as a glossy button-football disc — the club's colours in its
pattern, no lettering. What it draws comes from `TeamCrestSymbols.byTeamID`, a **hardcoded
Swift dictionary**, and `TeamBadge` deliberately never falls back to the remote crest for a
club: a team with no entry gets initials on muted glass instead.

That was fine while the apps only ever showed their own league. It stops being fine now that
a board can carry another competition's fixtures.

**Measured 2026-07-27, against live data:**

| Competition | teams with a disc |
|---|---|
| Brasileirão (BSA) | 20 / 20 |
| CONMEBOL Sudamericana (CSA) | **7 / 56** |

The seven are exactly the Brazilian clubs that also play in the Brasileirão. The other 49 —
River Plate, Boca Juniors, Sporting Cristal, every Argentine, Peruvian, Colombian and
Venezuelan side — render as initials. Libertadores will be the same or worse.

The existing kit-colours endpoint is **not** a fallback: `GET /v4/competitions/CSA/teams/{id}/colors`
answers 200 with `home`, `away` and `third` all `null` for every uncurated team checked
(435, 451, 1128, 2546, 2840). There is no colour data to derive a plain disc from either.

**Why it needs to be server-side.** The catalog is 50 entries of Swift that must stay
byte-identical across two repos — `scripts/sync-crests.sh` copies it into `../worldcup` and
`CrestSyncTests` fails if the copy drifts. So adding one club today means editing Swift,
running the sync, and **shipping both apps**. Enabling a competition should not require an
App Store release to draw its badges.

### What the endpoint has to serve

One disc is a tagged union — five patterns, all colours as hex **without** a leading `#`, to
match the kit-colours endpoint:

```json
{ "teamId": 124, "pattern": "verticalStripes",
  "bands": [ { "hex": "9F1239", "weight": 1 }, { "hex": "0F5132", "weight": 1 } ] }

{ "teamId": 131, "pattern": "horizontalStripes", "bands": [ … ] }

{ "teamId": 121, "pattern": "concentric",       "bands": [ … ] }   // outer → inner

{ "teamId": 133, "pattern": "diagonalSash",
  "background": "FFFFFF", "stripe": "000000", "widthFraction": 0.28 }

{ "teamId": 435, "pattern": "checkerboard",
  "light": "FFFFFF", "dark": "000000", "squares": 4 }
```

`weight` is a band's relative size, so a pinstripe is a small weight beside wider ones — the
renderer normalises against the sum, it does not require them to total 1. `widthFraction` is
the sash's width as a fraction of the disc. `squares` is the checkerboard's count per side.
These names and semantics are `TeamCrestSymbol`'s; keeping them identical means the client
decoder is a straight map onto the existing enum.

**Shape: one cacheable catalog, not one request per team.** A single matchday board holds up
to 28 teams, so per-team requests are the wrong trade. Prefer:

```
GET /v4/crest-symbols            → { "symbols": [ … ] }
```

with a long `Cache-Control` and an `ETag`, so clients fetch it once and revalidate cheaply.
50 entries today is a few KB; even ten leagues' worth stays small. A team with no disc is
simply absent from the list — the client keeps its initials fallback for those, unchanged.

**Client side, when it lands:** decode into `TeamCrestSymbol`, cache it the way
`TeamThemeColorCache` caches kit colours (SwiftData, no TTL — a club's colours do not change
like scores do), and keep the bundled catalog as the offline/first-launch default rather than
deleting it. That also means the endpoint can ship before either app consumes it.

### Open, for whoever picks this up

- **Where the data is authored.** The broadcast overrides already have an admin front-end
  and an `editorial` source; crest symbols are the same kind of hand-curated data and would
  fit that pattern rather than inventing a second one.
- **Whether to serve a derived disc for uncurated teams.** The kit-colours table is empty for
  them today, but if it were filled, a plain two-tone disc would beat initials. Decide whether
  the endpoint returns only curated discs or also derived ones, because it changes whether the
  client's initials fallback is a rare case or a dead one.
- **Whether the World Cup app's national teams stay on bundled flag roundels.** They do not use
  `CrestDisc` at all, and nothing here should change that.
