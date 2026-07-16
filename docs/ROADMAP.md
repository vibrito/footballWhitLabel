# Roadmap

Status as of 2026-07-16: Premier League 2026, Ligue 1 2026, and Liga Portugal 2026 are
submitted to App Store review (alongside the already-live Brasileirão/BR2026). Item #1
below has shipped. The agreed next steps are, in order:

## 1. In-app-purchase team themes ✅ Shipped 2026-07-16

Purchasable per-team customization: alternate app icon, accent colors, and the purchased
team featured in the Matchday hero card, always where possible.

## 2. More championships

Add Scottish Premiership and La Liga, on top of the four already shipped (Brasileirão,
Premier League, Ligue 1, Liga Portugal).

La Liga brings Spain into the supported-locale set, so **Spanish localization is needed
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
