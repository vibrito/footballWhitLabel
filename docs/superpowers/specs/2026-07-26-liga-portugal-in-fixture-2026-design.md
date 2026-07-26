# Liga Portugal in Fixture 2026 — Design

**Date:** 2026-07-26
**Status:** approved (design agreed in conversation; blocked on one asset)

## Goal

Make Liga Portugal a selectable competition in the Fixture 2026 app, and give it a matching
alternate app icon so it is presented the way Brasileirão and the Scottish Premiership already
are.

Today the competition appears in the hub but is locked: dimmed to 40% opacity behind a
`lock.fill` + "coming soon" badge, with no `NavigationLink`.

## Why this is almost entirely already built

`CompetitionCatalog.swift` was authored anticipating this. The `PPL` entry is complete —
code, `leagueBaseURL`, `.league` format, `.live` data source, accents `#00235A` (brand navy)
and `#19FF91` (tab selection), `flagAssetName: "pt"` — and differs from the enabled
Brasileirão and Scottish entries in exactly one respect: `isEnabled: false`.

Everything it depends on is present:

| Dependency | State |
|---|---|
| `competition.ppl` → "Liga Portugal" | present, all 5 locales |
| `pt.imageset` in `Flags.xcassets` | present |
| The 18 Liga Portugal crest symbols | present — synced from the crest work |
| Live API coverage for `PPL` | verified: 18 teams returned from `/competitions/PPL/standings` |
| League ordering with PPL third | already asserted by a passing test |

## Scope

**In:**

1. Enable the competition (one flag).
2. Update the two tests that assert the current lock state.
3. Add a Portuguese alternate app icon.

**Out:** any change to how league screens work. Liga Portugal uses the same
`LeagueMatchService`, `LeagueTodayContent`, Fixtures, Standings and match-detail code paths
that Brasileirão and the Scottish Premiership already use — nothing is competition-specific.

## Deliverable 1 — Enable the competition

In `Fixture2026App/Models/CompetitionCatalog.swift:28`, drop `isEnabled: false` from the `PPL`
entry so it takes the struct's default of `true`.

`isEnabled` is consumed only by `CompetitionHubView`, in three places: whether the tile is
wrapped in a `NavigationLink` (line 62), whether the lock badge renders (line 101), and the
tile's opacity (line 115). Flipping it makes the tile tappable at full opacity, removes the
badge, and gives it the `tile-PPL` accessibility identifier that UI and snapshot tests use to
navigate.

## Deliverable 2 — Update the two tests that encode the lock state

Both live in `Fixture2026AppTests/Models/CompetitionCatalogTests.swift` and will fail once the
flag flips. They should fail — they assert today's lock state by name, and both the names and
the expectations need to move:

- `onlyWorldCupBrasileiraoAndScottishAreEnabled` — rename to include Liga Portugal; enabled set
  becomes `["2026", "BSA", "SPL", "PPL"]`, locked set becomes `["PL", "FL1", "PD"]`.
- `enabledReturnsThreeCompetitionsInCatalogOrder` — rename ("Three" → "Four"); expectation
  becomes `["2026", "BSA", "SPL", "PPL"]`.

`leaguesAreOrderedBrasileiraoScottishLigaPortugalFirst` already expects PPL third in league
order and must keep passing untouched. If it breaks, the catalog order was changed by mistake.

## Deliverable 3 — Portuguese alternate app icon

The app icon is **independent of the competition catalog**: `AppIconOption` is a Settings
picker switched via `UIApplication.setAlternateIconName(_:)`, and nothing in it reads
`CompetitionCatalog`. Liga Portugal works fully without an icon. It is included here because
Brasileirão and the Scottish Premiership each ship one, and leaving Liga Portugal without one
would make it the odd league out.

Following the existing pattern exactly:

| Piece | Existing example | To add |
|---|---|---|
| Icon set | `AppIcon-Scottish.appiconset/AppIcon-Scottish-1024.png` | `AppIcon-Portuguese.appiconset/AppIcon-Portuguese-1024.png` |
| Picker thumbnail | `AppIconPreview-Scottish.imageset/AppIconPreview-Scottish.png` | `AppIconPreview-Portuguese.imageset/AppIconPreview-Portuguese.png` |
| Enum case | `case scottish` | `case portuguese` |
| `alternateIconName` | `"AppIcon-Scottish"` | `"AppIcon-Portuguese"` |
| Preview asset name | `"AppIconPreview-Scottish"` | `"AppIconPreview-Portuguese"` |
| Settings label key | `settings.appicon.scottish` | `settings.appicon.portuguese` |

Both existing assets are a single **1024×1024 PNG** with `"idiom": "universal"`,
`"platform": "ios"` — no multi-size set. The same image serves as both the icon and the
thumbnail.

The new `settings.appicon.portuguese` string needs real translations for all five locales the
app covers (en, en-GB, fr, pt-BR, pt-PT — this app has no `es`). Model it on
`settings.appicon.scottish`.

**Blocked on:** one 1024×1024 PNG supplied by the user. Nothing else in this spec depends on
it, but the agreed sequencing is to ship all three deliverables together rather than enabling
the competition first.

## A note on target membership

`Fixture2026App` and `Fixture2026AppTests` are **not** `fileSystemSynchronizedGroups` — only
the Watch targets are. Asset catalogs are already members, so adding image sets inside
`Assets.xcassets` needs no project change. This note exists because two earlier tasks in this
repo assumed auto-inclusion and were wrong for new *source* files; it does not apply here
unless a new `.swift` file is added.

## Testing

`CompetitionCatalog` is a model, so it is unit-tested — Deliverable 2 is that test work, and it
is the real verification for Deliverable 1.

`AppIconOption` is also a model, and `Fixture2026AppTests/Models/AppIconOptionTests.swift`
already covers it. A new case does **not** break those tests — they name each case explicitly,
and the distinctness check at line 24 (`Set(names).count == names.count`) keeps holding — but it
would leave `portuguese` silently uncovered. Extend two of them:

- "Alternate options map to their App Icon Set names" (lines 12-15) — add
  `#expect(AppIconOption.portuguese.iconAssetName == "AppIcon-Portuguese")`.
- "Every option has a distinct preview image set" (lines 18-22) — add
  `#expect(AppIconOption.portuguese.previewImageName == "AppIconPreview-Portuguese")`.

`AppIconPickerViewModelTests` needs no change — it exercises selection behaviour through
specific cases and is unaffected by adding one.

Views are not unit-tested per this project's CLAUDE.md. The visual check is: Liga Portugal's
tile is tappable in the hub and opens to real data, and the new icon appears and applies from
the Settings picker.

## Risks

- **The icon must be genuinely distinct from the other three.** They sit side by side in the
  picker; a Portuguese icon that reads like the Brazilian one at thumbnail size defeats it.
  Judge on device, not in the asset catalog.
- **Enabling a competition is user-visible immediately.** Liga Portugal's season data comes from
  the live API; if the current round is empty or between seasons, the screens will show their
  empty states rather than looking broken — worth a look on device before release.
