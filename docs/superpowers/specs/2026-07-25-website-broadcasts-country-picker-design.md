# Website Broadcasts Row + Country Picker — Design Spec

## Goal

Add a live "today's matches" section to the Brasileirão marketing page
(`website/br2026/index.html`) showing real fixtures from the backend API, each with a
broadcasts row naming where the match can be watched, plus a country control letting the
visitor choose which country's listings they see. The API key must never reach the browser,
so the site gains its first Cloudflare Pages Function as a server-side proxy. Scope is the
`br2026` page only; the other five app pages are untouched.

## Background

### The website today

`website/` is a pure static site (no build step, no framework, **no JavaScript anywhere**)
deployed to Cloudflare Pages via `wrangler.toml` (`pages_build_output_dir = "website"`). Six
per-app landing pages each share one `styles.css` whose design tokens are lifted from the
app's Liquid Glass system — `--accent`, `--bg-top/mid/bottom`, `.glass-card`. See
`docs/superpowers/specs/2026-07-20-marketing-website-design.md`.

Each landing page has three `.feature-block` sections, each pairing marketing copy with a
**decorative mock** — `.mock-match-card` (`styles.css:353`) is a 280px glass card with
hardcoded `Home 2 – 1 Away` and a pulsing `LIVE 67'` chip. These illustrate the app; they are
not wired to any data source and this spec does not change them.

### The broadcasts data

`GET /v4/competitions/{code}/matches` accepts an **undocumented** `include=broadcasts`
parameter that adds a `broadcasts` array to every match object. Verified against the live API
on 2026-07-25:

```json
{ "name": "Prime Video", "type": "STREAMING", "country": "BR", "url": null, "logo": null }
```

Constraints measured on the same date, all of which shape the design below:

| Finding | Value | Consequence |
|---|---|---|
| Matches with non-empty `broadcasts` | 10 of 380 (BSA) | Current round only; the rest return `[]` |
| Competitions with any broadcast data | BSA only (PL, FL1, PPL, SPL, PD all zero) | Feature is Brasileirão-only in practice |
| Distinct `country` values | `["BR"]` | Country control has exactly one entry today |
| `url` / `logo` populated | 0 of 20 entries | Text-only rendering; nothing to link or show |
| `type` values seen | `PPV` (12), `STREAMING` (3), `FREE_TV` (3), `PAY_TV` (2) | Enables free-to-air-first ordering |
| Full payload size | 207 KB raw / **8.3 KB gzipped** | Cheap enough to send whole and filter client-side |
| Days with ≥1 scheduled BSA match | **12 of the next 30**, longest gap 7 days | A strict "today" section would be empty most days |

Two API behaviours worth recording because they cost time to discover:

- The `country=` query parameter **filters but never falls back**. `country=BR` returns the
  same 20 entries as omitting it; `US`, `PT`, `GB` and even the nonsense `XX` all return
  empty. A naive `country=<visitor locale>` would silently show nothing to everyone outside
  Brazil. This spec therefore **never sends `country=`** — it fetches unfiltered and buckets
  client-side.
- `include` is **not validated**. `include=bogus`, `include=BROADCASTS` and
  `include=broadcasts,lineups` all return `200` and simply add no key. Exact-match and
  case-sensitive; a typo fails silently rather than erroring, which is why the initial probe
  of the bare endpoints missed the feature entirely.

## Design

### Files

```
functions/api/matches.js      NEW   repo root — NOT inside website/
website/matchday.js           NEW   ES module; pure functions exported for test
website/matchday.test.js      NEW   node --test, zero dependencies
website/br2026/index.html      EDIT  new <section> + <script defer>
website/styles.css             EDIT  new .live-* rules, nothing removed
.dev.vars                      NEW   gitignored — local API key for wrangler pages dev
.gitignore                     EDIT  add .dev.vars
```

Cloudflare Pages requires the `functions/` directory at the **project root**, a sibling of
the `website/` output directory rather than inside it. File-based routing maps
`functions/api/matches.js` to the `/api/matches` route. Functions take precedence over
static assets and `_redirects` for matching paths, so the existing redirect rules are
unaffected.

### Data flow

```
browser  →  GET /api/matches?code=BSA              same-origin, no CORS
              ↓  Pages Function attaches X-Auth-Token from context.env
            railway  /v4/competitions/BSA/matches?include=broadcasts
              ↓  8.3 KB gzipped, edge-cached 60s
         matchday.js  →  bucket by LOCAL date  →  render  →  wire country control
```

### The proxy — `functions/api/matches.js`

```js
export async function onRequest(context) { /* ... */ }
```

Responsibilities, in order:

1. Reject non-`GET` with `405`.
2. Read `code` from the query string and validate it against a hardcoded allowlist —
   `["BSA", "PL", "FL1", "PPL", "SPL", "PD"]`. Anything else returns `400`. **This
   allowlist is the security boundary**: without it, the endpoint is an open relay that
   anyone can point at arbitrary upstream paths using your paid API key.
3. Fetch `https://football-api-production-16d9.up.railway.app/v4/competitions/{code}/matches?include=broadcasts`
   with `X-Auth-Token: context.env.FOOTBALL_API_KEY`, passing
   `cf: { cacheTtl: 60, cacheEverything: true }` so repeat requests are served from the edge
   rather than the origin.
4. On a non-2xx upstream response, return `502` with a small JSON body. Never forward the
   upstream body or status detail — it could echo key-related errors.
5. On success, return the JSON with `Cache-Control: public, max-age=60`.

The key is set as a Cloudflare Pages environment secret (dashboard → Settings → Environment
variables, encrypted) and locally via a gitignored `.dev.vars`. It is never committed, and
never appears in any file served to a browser.

### Day selection — `selectMatchday(matches, now)`

The only non-trivial logic, and the reason it lives in the browser rather than the edge
function: **"today" is a local-timezone concept**. Tonight's 21:30 UTC kickoff is 18:30 in
São Paulo, while a visitor in Lisbon at 23:00 local is already on the next calendar day. An
edge function deciding "today" in UTC would disagree with the visitor's own calendar for part
of every day, and kickoff times must be localized in the browser regardless. Bucketing where
the timezone lives removes the whole class of off-by-one bug.

Pure function, exported for test:

1. Drop `POSTPONED` matches.
2. Bucket the rest by **local** calendar date, derived from the parsed `utcDate`.
3. If today's bucket is non-empty, select it — **even when every match in it has finished**,
   because final scores on the current day are correct and useful information.
4. Otherwise select the earliest bucket after today.
5. If no bucket qualifies (season over), return `null` and the section stays hidden.

Given BSA plays only 12 days a month with a 7-day August gap, step 4 is what keeps the
section populated year-round instead of vanishing on ~18 days of every 30.

### Header

Eyebrow above the section title, mirroring `MatchdayView`'s own split exactly — the eyebrow
carries the date, the title carries the human label, and the two never repeat each other.
Eyebrow reuses the app's type treatment (11px, weight 700, tracking 1.4, uppercase,
`white @ 0.5`); title is 32px weight 800, tracking −0.5.

| Selected bucket | Eyebrow | Title |
|---|---|---|
| Today | `SAT · 25 JUL` | `Today` |
| Tomorrow | `SUN · 26 JUL` | `Tomorrow` |
| Later | `FRI · 7 AUG` | `Friday` |

### Card list

A flat list of cards for the selected day, ordered by kickoff time — **no hero treatment**.
The app's hero-plus-"Also Today" split exists to give the Matchday tab a focal point for
navigation; on a marketing page a uniform list reads more like a schedule and avoids
arbitrarily promoting one of tonight's three fixtures over the others.

Each card carries, reusing `.mock-match-card`'s glass vocabulary at 22px radius:

- both teams' crests as `<img>` straight from the API's `crest` URL
  (`media.api-sports.io`), with a team-initials fallback on a muted glass fill matching the
  app's `TeamCrestBadge` placeholder behaviour, plus `loading="lazy"` and explicit
  width/height to avoid layout shift
- both team names (`shortName`, falling back to `name`)
- the score when the match is `IN_PLAY`, `PAUSED` or `FINISHED`; otherwise the kickoff time
  in the visitor's own timezone via `toLocaleTimeString`
- a `LIVE 67'` accent chip for `IN_PLAY`, `HT` for `PAUSED`, `FT` for `FINISHED`, nothing for
  `SCHEDULED` — note the backend sends `IN_PLAY`/`PAUSED`, never the literal `LIVE`, the same
  gotcha `MatchStatus` handles on the app side
- the broadcasts row described below

### Country control

The available countries are the distinct `country` values across **the selected day's**
broadcasts — not across the whole season — so the control always reflects exactly what is on
screen. `Intl.DisplayNames` resolves `BR` to "Brazil", avoiding a hardcoded country-name
table that would need translating; it falls back to the raw code if unavailable.

Behaviour scales with the count, which matters because today the count is always 1:

| Countries | UI |
|---|---|
| 0 | No control, no broadcasts rows |
| 1 | Static glass pill, e.g. `📺 Brazil` — a dropdown holding one option is a dead control |
| 2+ | Native `<select>`, `appearance: none`, glass-styled to match `.glass-card` tokens |

A native `<select>` rather than a custom menu: correct keyboard and screen-reader behaviour
comes for free, and the iOS wheel picker is the right mobile affordance. Initial selection is
the visitor's own region via `new Intl.Locale(navigator.language).region` when it appears in
the list, otherwise the first entry; the choice persists in `localStorage` under
`br26.broadcastCountry`.

### Broadcasts row

One row per match card: a `📺` glyph followed by the broadcaster names for the selected
country, ordered `FREE_TV → PAY_TV → STREAMING → PPV` so free-to-air options read first.
Names only — `url` and `logo` are null in every entry, so there is nothing to link to and no
logo to render; a broadcaster-logo treatment would require bundling assets keyed on strings
like `"Premiere 4"` and `"CazéTV"` and is out of scope.

A match with no listings for the selected country renders a muted `No listings` rather than
omitting the row, so cards keep a uniform height when the visitor switches country.

### States

The `<section>` ships with the `hidden` attribute and is revealed only after a successful
render. Every failure mode — API down, missing key, malformed payload, JavaScript disabled,
no qualifying matchday — therefore degrades to **exactly the page that exists today**.
Failures are `console.warn`ed, never surfaced as user-facing error text on a marketing page.

This is the main reason the design adds a new section above the feature blocks instead of
converting the existing `.mock-match-card`: there is no state in which it can make the live
page look broken. The three decorative mocks keep working as illustrations regardless of API
health.

### Styling

New `.live-*` rules appended to `styles.css`, reusing the existing token vocabulary — glass
fill `rgba(255,255,255,0.07)`, border `0.5px rgba(255,255,255,0.16)`, shadow
`0 8px 22px rgba(0,0,0,0.22)`, 22px radius for match cards, `var(--accent)` for live chips.
Kickoff times and scores use `font-variant-numeric: tabular-nums`, matching the app's
`.monospacedDigit()` convention. Nothing existing is modified or removed.

## Testing

The repo has no JavaScript test infrastructure. Rather than introduce a runner and its
dependency tree, `matchday.js` exports its pure functions and `website/matchday.test.js` uses
**Node's built-in test runner** (`node --test website/`) — zero dependencies, no
`package.json` required.

Cases:

- today's bucket has matches → selects today
- today's bucket empty → selects the earliest future bucket
- today's matches all `FINISHED` → still selects today
- every match `POSTPONED` → returns `null`
- **timezone boundary**: a 23:30 UTC kickoff buckets to the following local day in a
  UTC+2 timezone, and to the same day in UTC−3
- country extraction dedupes and sorts by display name
- broadcaster ordering puts `FREE_TV` ahead of `PPV`
- a match with an empty `broadcasts` array yields the `No listings` state
- status chip mapping: `IN_PLAY` → live chip with minute, `PAUSED` → `HT`, `FINISHED` → `FT`,
  `SCHEDULED` → no chip and a localized kickoff time instead of a score

Manual verification via `npx wrangler pages dev` with `.dev.vars` populated, checking: the
section renders tonight's three BSA fixtures with Prime Video / SporTV / Premiere listings; a
forced 502 from the function leaves the page identical to production; and the single-country
case renders the static pill rather than a `<select>`.

## Out of scope

- **The other five landing pages.** The proxy's allowlist already accepts their competition
  codes, so rolling out is adding the section markup and a `?code=` value per page — but none
  of them have broadcast data today, so there is nothing to show.
- **The iOS app.** BR2026 has no broadcasts row and no country picker. After this ships the
  website displays something the app does not; if the app should match, that needs its own
  spec (the API work is already done — `include=broadcasts` on the existing
  `LiveMatchService.fetchMatches()` call plus a `broadcasts` field on `MatchDTO`).
- **Broadcaster logos and deep links**, until the backend populates `url` and `logo`.
- **Countries beyond BR**, until the backend has upstream coverage. The design picks these up
  automatically — the control is built from whatever the API returns.
- **Live score polling.** The section renders once on page load. The 60s edge cache means a
  reload reflects reasonably fresh scores; a `setInterval` refresh is a later addition.
