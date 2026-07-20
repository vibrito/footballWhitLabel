# Marketing Website — Design Spec

## Goal

Replace the current bare-minimum `website/` (built only to satisfy App Store Connect's
privacy/support URL requirements) with a genuinely presentable marketing site for the whole
app family: a real hub page showcasing all 6 leagues, and a redesigned landing page per app
with feature highlights. No apps are live on the App Store yet, so every app's CTA stays a
"Coming soon" badge — no download links, no email-capture backend. Site stays a pure static
site (no build step, no framework), deployed to the existing Cloudflare Pages project
(`br26-80k.pages.dev`); a paid custom domain is explicitly deferred to a later, separate step.

## Background

`website/` today (see `docs/superpowers/specs/2026-07-11-privacy-policy-website-design.md`)
is flat hand-authored HTML sharing one `styles.css`. The root `index.html` is Brasileirão's
own placeholder page (title, tagline, "Coming soon" badge, privacy link) plus a nav listing
the other 3 apps. Premier League, Ligue 1, and Liga Portugal each have their own
`/{league}/` folder with the same placeholder structure, a `privacy/{locale}/` set (5
locales: en, en-gb, fr, pt-br, pt-pt) and a `support/` page. Scottish Premiership and La
Liga have no site presence at all yet. Every page shares one `--accent` CSS variable,
overridden per page via an inline `<style>` block, and one `.glass-card`/`.policy-card`
component vocabulary lifted directly from the app's own Liquid Glass design tokens
(`CLAUDE.md`'s Design System section — same fill/border/shadow values, same gradient/blob
background).

## Design

### Site structure

Stays flat and hand-authored, consistent with today's convention — no static site
generator, no per-page templating engine. New layout:

```
website/
├── index.html                     # NEW: family hub (hero + 6-card league grid)
├── styles.css                     # extended, nothing existing removed
├── _redirects                     # NEW: old Brasileirão root paths → /brasileirao/*
├── brasileirao/                   # NEW folder — moved from site root
│   ├── index.html
│   ├── privacy/{en,en-gb,fr,pt-br,pt-pt,es}/index.html
│   └── support/index.html
├── premier-league/                # index.html redesigned; privacy/support content untouched
├── ligue-1/
├── liga-portugal/
├── scottish-premiership/          # NEW: index.html + privacy (6 locales) + support
└── la-liga/                       # NEW: index.html + privacy (6 locales) + support
```

**Brasileirão moves off the site root into `/brasileirao/`**, matching its 5 siblings — the
root is becoming the family hub instead of one app's placeholder. This changes BR2026's live
App Store Connect fields:
- `marketing_url`: `https://br26-80k.pages.dev/` → `.../brasileirao/`
- `privacy_url`: `https://br26-80k.pages.dev/privacy/en/` → `.../brasileirao/privacy/en/`
- `support_url`: `https://br26-80k.pages.dev/support/` → `.../brasileirao/support/`

A `_redirects` file (Cloudflare Pages' native redirect mechanism) maps the old root-level
paths to the new ones with 301s, so any stale cached link (including Apple's own crawl of
the old ASC URLs before they're updated) still resolves:

```
/privacy/*   /brasileirao/privacy/:splat   301
/support/*   /brasileirao/support/:splat   301
```

The 3 ASC fields are updated via `fastlane deliver` (same mechanism used for the Netlify→
Cloudflare URL swap) as part of implementation — this is a live-metadata push, so it happens
as its own confirmed step, not bundled silently into a deploy.

**Every other app's existing `privacy/`/`support/` content is untouched** — only each
`index.html` is redesigned.

### Hub page (`/`)

**Hero** — same stadium-night radial-gradient + accent/teal blob background as every other
page (no per-page accent override here; hub uses the default `--accent`). Centered content
column, no company/studio brand called out (apps are shown on their own):

```html
<h1 class="title">Live football, everywhere you follow it.</h1>
<p class="tagline">Real-time scores, fixtures, and standings — one focused app per league,
six leagues and counting.</p>
```

No CTA button in the hero (nothing is clickable yet) — the grid is the primary content.

**League grid** — 6 equal-weight cards, CSS grid: 3 columns ≥900px, 2 columns ≥600px, 1
column below that. Each card is a single `<a class="league-card">` wrapping its content
(entire card clickable, not just a title), tinted via an inline per-card `style="--accent:
#hex"` so `styles.css` needs no per-league selectors:

```html
<a class="league-card" href="/brasileirao/" style="--accent: #ff4d5e;">
  <h2>Brasileirão</h2>
  <p>Brazil's top flight</p>
  <span class="glass-card badge">Coming soon</span>
</a>
```

Card fill is the existing `.glass-card` background tinted toward `--accent` at low alpha
(reusing the same `rgba(255,255,255,0.07)` base, layering a `color-mix(in srgb, var(--accent)
12%, transparent)` wash on top) — border, shadow, corner radius (22px, matching the app's
"match card" radius from `CLAUDE.md`) stay the shared glass values, not accent-colored, so
the grid reads as one coherent set rather than 6 clashing colors.

One card per league, all 6 present with real taglines:

| League | Tagline |
|---|---|
| Brasileirão | Brazil's top flight |
| Premier League | England's top flight |
| Ligue 1 | France's top flight |
| Liga Portugal | Portugal's top flight |
| Scottish Premiership | Scotland's top flight |
| La Liga | Spain's top flight |

**Footer** — single line, contact email only (`vibritoapps@gmail.com`, matching the existing
support pages' contact), no per-app links (those live on each app's own page).

### Per-app page (`/{league}/`)

**Hero** — unchanged from today's pattern: league name as `<h1>`, one-line tagline, `Coming
soon` badge, `← Back to all apps` link (every page gets this now, including Brasileirão once
it moves off root — today only the 5 non-root pages have it).

**Feature showcase — 3 alternating blocks**, each pairing a short pitch with a static
HTML/CSS mockup built from the app's real design tokens (no screenshots, no simulator
dependency, always in sync since it's driven by the same `--accent` variable each page
already sets):

1. **Matchday** — "Every score, the moment it happens." Mockup: one `.mock-match-card`
   showing two team-name placeholders, a live score, minute counter, and a pulsing
   `.mock-live-chip` in the league's accent (CSS `@keyframes` opacity/scale pulse, mirroring
   `CLAUDE.md`'s documented live-pulse animation — respects `prefers-reduced-motion`).
2. **Fixtures** — "Never miss a matchday." Mockup: 2 stacked `.mock-fixture-row`s — one
   showing a final score (muted fill), one showing a scheduled kickoff time (active fill) —
   same finished/upcoming visual distinction the real Fixtures tab uses.
3. **Standings** — "The full table, always current." Mockup: `.mock-standings-row` × 5,
   including 2 `.mock-zone-ball` markers (teal + red, from `StandingsView`'s real zone-marker
   design) so the table's most distinctive real feature is visible here too.

Layout alternates image-left/text-right, then flipped, then back, on desktop; stacks
image-above-text on mobile. Each block's copy is written per-league where it's natural (e.g.
Brasileirão's Fixtures copy can reference "38 rounds"), otherwise shares the same 3 English
strings above translated to nothing — **site copy stays English-only**, matching today's
site (the app itself is localized; the marketing site never has been, and this doesn't
change that).

**Below the showcase**: unchanged from today — `Coming soon` badge (already in the hero,
not repeated), privacy link, back-link.

### Shared CSS additions (`styles.css`)

All additive; nothing existing is removed or restructured.

```css
.league-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; }
@media (max-width: 900px) { .league-grid { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 600px) { .league-grid { grid-template-columns: 1fr; } }

.league-card {
  display: flex; flex-direction: column; gap: 8px;
  background: linear-gradient(rgba(255,255,255,0.07), rgba(255,255,255,0.07)),
              linear-gradient(color-mix(in srgb, var(--accent) 12%, transparent),
                               color-mix(in srgb, var(--accent) 12%, transparent));
  border: 0.5px solid rgba(255,255,255,0.16);
  border-radius: 22px;
  box-shadow: 0 8px 22px rgba(0,0,0,0.22);
  padding: 20px;
  text-decoration: none;
  color: #fff;
  transition: transform 0.2s ease;
}
.league-card:hover { transform: translateY(-2px); }
.league-card h2 { margin: 0; font-size: 19px; font-weight: 800; }
.league-card p { margin: 0; font-size: 14px; color: rgba(255,255,255,0.7); }

.feature-block { display: flex; align-items: center; gap: 32px; margin: 48px 0; }
.feature-block.reverse { flex-direction: row-reverse; }
.feature-block .copy { flex: 1; }
.feature-block .mock { flex: 1; display: flex; justify-content: center; }
@media (max-width: 700px) { .feature-block, .feature-block.reverse { flex-direction: column; } }

.mock-match-card { /* glass-card look, team rows, score, live chip — sized ~280px wide */ }
.mock-live-chip { /* accent @ 18% fill, accent text/border, pulse animation */ }
.mock-fixture-row { /* team names + score/time, muted vs active fill per CLAUDE.md's
                        "Muted/finished fill: white @ 0.05" vs "Active card fill: white @ 0.07" */ }
.mock-standings-row { /* position + zone ball + team name + points, tabular-nums */ }
.mock-zone-ball { /* teal #2dd4bf / red #ef4444 filled circle behind position number,
                      matching StandingsView.swift's zoneBallColor(for:) */ }
```

(Exact declarations filled out during implementation — the block above fixes the class names,
the data each component needs, and which literal color/spacing values from `CLAUDE.md` each
one must match, so the plan has no ambiguity about what "matching the app" means.)

Pulse animation respects motion preference:

```css
@media (prefers-reduced-motion: reduce) {
  .mock-live-chip { animation: none; }
}
```

### New leagues: Scottish Premiership & La Liga

Both get the full existing per-app treatment: redesigned `index.html` (feature showcase
included, tinted `#005EB8` and `#AA151B` respectively — La Liga's page uses the primary
`#AA151B` red rather than its secondary gold, matching how `ChampionshipConfig` already
treats `accentColorHex` as the one representative brand color), plus `privacy/` (6 locales,
see below) and `support/` pages adapted from the existing template — same legal boilerplate,
same FAQ content, just the league name substituted in (`"the Scottish Premiership app"` /
`"the La Liga app"`), same contact email.

### `es` privacy locale — added for all 6 apps

The app's own UI localization went app-wide when La Liga shipped Spanish support (per
`CLAUDE.md`/prior work), rather than staying La-Liga-only — the privacy site locale set
follows the same precedent. Every app's `privacy/` folder gains an `es/index.html`
(Spanish translation of the same 7-section policy content already in `en/`), and every
`privacy/*/index.html`'s `lang-switcher` nav gains a 6th entry:

```html
<a href="/{league}/privacy/es/">Español</a>
```

Concretely: the 4 apps with existing privacy folders (Brasileirão, Premier League, Ligue 1,
Liga Portugal) each gain one new `es/index.html` (4 files) plus a 6th `lang-switcher` link
added to their existing 20 pages (4 apps × 5 locales). Scottish Premiership and La Liga each
get all 6 locales built fresh (12 files total). 36 privacy pages exist across the site once
this is done.

### Out of scope

- Custom domain purchase — deferred, explicitly agreed to keep using `br26-80k.pages.dev`
  for now.
- Any download CTA / App Store link / email-capture "notify me" — every app is "Coming soon"
  today; revisit page content once any app actually ships.
- A studio/company brand identity — apps are shown on their own, no unifying brand name.
- Marketing site localization beyond the privacy-policy pages (site UI copy stays
  English-only, matching today).
- Real device/simulator screenshots — feature showcases use CSS/HTML mockups instead.

## Testing

No test framework applies to a static site. Verification is manual, browser-based, done
before deploy:
- Open the hub page and all 6 per-app pages at 3 viewport widths (mobile ~375px, tablet
  ~768px, desktop ~1200px) — check the league grid's column count switches correctly and no
  `.feature-block` content overflows or clips.
- Click every link: hub → each league card → each league's privacy/support/back-link →
  each privacy page's 6-locale language switcher → back to hub.
- Confirm the moved Brasileirão paths (`/privacy/en/`, `/support/`) redirect correctly via
  `_redirects` after deploy (Cloudflare Pages redirects only take effect once deployed, not
  locally — verify against the live `br26-80k.pages.dev` URL post-deploy).
- Confirm `prefers-reduced-motion: reduce` (via browser dev tools emulation) stops the
  `.mock-live-chip` pulse.
- Verify the 3 App Store Connect field updates for BR2026 (`marketing_url`, `privacy_url`,
  `support_url`) actually saved, via a fresh `fastlane deliver download_metadata` pull.
