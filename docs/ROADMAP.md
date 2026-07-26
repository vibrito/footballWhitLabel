# Roadmap

Status as of 2026-07-16: Premier League 2026, Ligue 1 2026, and Liga Portugal 2026 are
submitted to App Store review (alongside the already-live Brasileirão/BR2026). Scottish
Premiership and La Liga are not yet submitted for review but all 6 apps are on TestFlight
(version 1.1, build 8). Items #1 and #2 below have shipped. The agreed next steps are, in
order:

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

## 3. Accessibility

Make all apps as accessible as possible: VoiceOver support, Dynamic Type, sufficient
contrast, reduced-motion handling. Nothing in the codebase was built with this in mind as
of 2026-07-13 — a real gap, not polish.

## 4. Push notifications

Notify users about the teams they've purchased a theme for (via item #1).

## 5. Apple Watch, CarPlay, and Widgets

Companion experiences across the platform.

## 6. Where-to-watch page

Location-based broadcast channel listings per match — show which channels are airing a
given match based on the user's location. Not strictly sequenced; can be fit in anytime
relative to the other items.

## 6b. Relegation and Libertadores zones in Standings

Visually mark the relevant position ranges in the Standings table — relegation zone,
Copa Libertadores qualification, and (where applicable) Copa Sudamericana/other continental
slots — the way most football standings tables do (colored row accents or a side marker
per zone). Not strictly sequenced, same as the where-to-watch page; can be fit in anytime.

## 6c. Standings table redesign/polish

A general visual/UX pass on the Standings screen itself (layout, columns, readability) —
distinct from the zone-marker item above, which is about marking qualification/relegation
ranges rather than the table's overall design. Not yet scoped beyond "general polish." Not
strictly sequenced; can be fit in anytime.

## 7. Cross-app linking

Link between all the family's apps so users can discover sibling apps. The `CrossAppLink`
model and resolver already exist in the codebase but are deliberately not wired into any
View yet — this stays hidden until the 3 newly submitted apps are actually approved and
live, not just submitted.

## 8. A proper marketing website

The existing site (deployed to Netlify from this repo's `website/` directory) is a
bare-minimum support/privacy-policy site built to satisfy App Store Connect requirements —
plain per-app landing pages with a "Coming soon" badge. This item is about building
something genuinely presentable to advertise the whole app family together, not just
extending the existing minimal site's structure further. Last in the sequence.

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
