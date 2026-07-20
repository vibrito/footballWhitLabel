# Marketing Website Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `website/`'s bare-minimum placeholder pages with a real marketing site: a
family hub page (`/`) showcasing all 6 leagues, plus a redesigned per-app landing page for
each, per `docs/superpowers/specs/2026-07-20-marketing-website-design.md`.

**Architecture:** Pure static HTML/CSS, no build step, no framework — same hand-authored
convention the site already uses. One shared `website/styles.css` gains a new set of
component classes (league grid/cards, feature blocks, CSS-only "mock" UI components that
mirror the real app's Liquid Glass tokens); every page consumes them via inline
`--accent` overrides, exactly like today's `<style>:root{--accent:#hex}</style>` pattern.

**Tech Stack:** HTML5, CSS (`color-mix()`, CSS Grid, Flexbox — all supported in current
Safari/Chrome/Firefox), deployed via Cloudflare Pages (`wrangler pages deploy website`).

## Global Constraints

- No build step, no framework, no JS beyond what already exists (none) — flat hand-authored
  HTML files, one shared `styles.css`.
- Every app's call-to-action stays a "Coming soon" badge — no download links, no App Store
  URLs, no email-capture forms. All 6 apps are pre-launch.
- Site UI copy (hero text, feature-block copy, nav) stays English-only. Only the existing
  privacy-policy pages are multilingual, and this plan adds exactly one new locale (`es`) to
  that existing set — no other localization work.
- No bundled raster images or custom icons — mock UI components are pure CSS/HTML;
  team-crest placeholders are single-letter badges (mirrors the real app's own
  crest-loading-placeholder convention: "team initials on a muted glass fill").
- Mock component colors/spacing must reuse these exact literal values from `CLAUDE.md`'s
  Design System section, not new ad hoc values: active glass fill `rgba(255,255,255,0.07)`,
  muted fill `rgba(255,255,255,0.05)`, border `0.5px solid rgba(255,255,255,0.16)`, shadow
  `0 8px 22px rgba(0,0,0,0.22)`, match-card radius `22px`, live-chip fill = accent @ 18%,
  text = accent, border = accent @ 45%, zone-ball colors teal `#2dd4bf` / red `#ef4444` with
  black (`#000000`) number text (WCAG-verified pairing, already used by the real
  `StandingsView`).
- Contact email everywhere is `vibritoapps@gmail.com` (existing convention, not a new value).
- Custom domain purchase is out of scope — every link stays relative (`/path/`), so the site
  works unchanged on `br26-80k.pages.dev` today and any future custom domain later.
- Premier League, Ligue 1, and Liga Portugal's existing `privacy/`/`support/` content is
  **not** rewritten — only each app's `index.html` is redesigned, plus (Task 7) one new
  `es/` locale file added alongside the existing 5.
- Brasileirão moves from the site root to `/brasileirao/`. Old root-level `/privacy/*` and
  `/support/*` paths must keep resolving (301 redirect) after the move.

---

### Task 1: Shared CSS component library

**Files:**
- Modify: `website/styles.css` (append only — nothing existing is changed or removed)

**Interfaces:**
- Produces (consumed by every later task):
  - `.hub-page .content` — widens the hub's content column to fit a 3-column grid.
  - `.league-grid`, `.league-card` — the hub's per-league card grid. `.league-card` reads
    `var(--accent)` from an inline `style="--accent:#hex"` on the `<a>` element itself.
  - `.hub-footer` — hub page footer link styling.
  - `.app-page .content`, `.app-page .hero`, `.app-footer` — per-app page layout: hero stays
    centered, feature blocks stretch full width, footer links re-center at the bottom.
  - `.feature-block`, `.feature-block.reverse`, `.feature-block .copy`,
    `.feature-block .mock` — the alternating feature-showcase layout.
  - `.mock-match-card`, `.mock-team`, `.mock-crest`, `.mock-team-name`, `.mock-score`,
    `.mock-live-chip` — Matchday mockup.
  - `.mock-fixtures`, `.mock-fixture-row`, `.mock-fixture-row--finished`,
    `.mock-fixture-meta` — Fixtures mockup.
  - `.mock-standings`, `.mock-standings-row`, `.mock-position`, `.mock-zone-ball`,
    `.mock-zone-ball--teal`, `.mock-zone-ball--red`, `.mock-points` — Standings mockup
    (`.mock-standings-row .mock-team-name` reuses the Matchday mockup's `.mock-team-name`
    class for the team label, sized down via a nested selector).
  - `@keyframes mock-pulse` — the live-chip pulse animation, disabled under
    `prefers-reduced-motion: reduce`.

- [ ] **Step 1: Append the new CSS to `website/styles.css`**

Add this exact block at the end of the file (after the existing `.back-link:hover` rule):

```css

/* Marketing site: hub + per-app feature showcase (2026-07-20) */

.hub-page .content {
  max-width: 960px;
  align-items: center;
}

.league-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 20px;
  width: 100%;
}

@media (max-width: 900px) {
  .league-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

@media (max-width: 600px) {
  .league-grid {
    grid-template-columns: 1fr;
  }
}

.league-card {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 8px;
  background:
    linear-gradient(color-mix(in srgb, var(--accent) 12%, transparent),
                     color-mix(in srgb, var(--accent) 12%, transparent)),
    rgba(255, 255, 255, 0.07);
  border: 0.5px solid rgba(255, 255, 255, 0.16);
  border-radius: 22px;
  box-shadow: 0 8px 22px rgba(0, 0, 0, 0.22);
  padding: 20px;
  text-decoration: none;
  color: #ffffff;
  transition: transform 0.2s ease;
}

.league-card:hover,
.league-card:focus-visible {
  transform: translateY(-2px);
}

.league-card h2 {
  margin: 0;
  font-size: 19px;
  font-weight: 800;
  letter-spacing: -0.3px;
}

.league-card p {
  margin: 0;
  font-size: 14px;
  color: rgba(255, 255, 255, 0.7);
}

.hub-footer {
  margin-top: 32px;
  font-size: 13px;
  font-weight: 600;
}

.hub-footer a {
  color: rgba(255, 255, 255, 0.55);
  text-decoration: none;
}

.hub-footer a:hover {
  color: #ffffff;
}

/* Per-app feature showcase */

.app-page .content {
  max-width: 720px;
  align-items: stretch;
  text-align: left;
}

.app-page .hero {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 20px;
  text-align: center;
  margin-bottom: 16px;
}

.app-footer {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  margin-top: 16px;
}

.feature-block {
  display: flex;
  align-items: center;
  gap: 32px;
  margin: 48px 0;
}

.feature-block.reverse {
  flex-direction: row-reverse;
}

.feature-block .copy {
  flex: 1;
}

.feature-block .copy h3 {
  margin: 0 0 8px 0;
  font-size: 22px;
  font-weight: 800;
  letter-spacing: -0.3px;
}

.feature-block .copy p {
  margin: 0;
  font-size: 15px;
  line-height: 1.6;
  color: rgba(255, 255, 255, 0.7);
}

.feature-block .mock {
  flex: 1;
  display: flex;
  justify-content: center;
}

@media (max-width: 700px) {
  .feature-block,
  .feature-block.reverse {
    flex-direction: column;
  }
}

/* Mock UI components — mirror the real app's Liquid Glass tokens (CLAUDE.md Design System) */

.mock-match-card {
  width: 280px;
  max-width: 100%;
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 12px;
  background: rgba(255, 255, 255, 0.07);
  border: 0.5px solid rgba(255, 255, 255, 0.16);
  border-radius: 22px;
  box-shadow: 0 8px 22px rgba(0, 0, 0, 0.22);
  padding: 20px;
}

.mock-team {
  display: flex;
  align-items: center;
  gap: 8px;
  flex: 1;
  min-width: 90px;
}

.mock-crest {
  width: 28px;
  height: 28px;
  flex-shrink: 0;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.05);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
  font-weight: 700;
  color: rgba(255, 255, 255, 0.7);
}

.mock-team-name {
  font-size: 16px;
  font-weight: 600;
  color: #ffffff;
}

.mock-score {
  font-size: 19px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  color: #ffffff;
}

.mock-live-chip {
  width: 100%;
  text-align: center;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.3px;
  text-transform: uppercase;
  color: var(--accent);
  background: color-mix(in srgb, var(--accent) 18%, transparent);
  border: 1px solid color-mix(in srgb, var(--accent) 45%, transparent);
  border-radius: 13px;
  padding: 4px 10px;
  animation: mock-pulse 1.4s ease-in-out infinite;
}

@keyframes mock-pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.35; }
}

@media (prefers-reduced-motion: reduce) {
  .mock-live-chip {
    animation: none;
  }
}

.mock-fixtures {
  width: 280px;
  max-width: 100%;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.mock-fixture-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: rgba(255, 255, 255, 0.07);
  border: 0.5px solid rgba(255, 255, 255, 0.16);
  border-radius: 18px;
  padding: 12px 16px;
  font-size: 14px;
  font-weight: 600;
  color: #ffffff;
}

.mock-fixture-row--finished {
  background: rgba(255, 255, 255, 0.05);
  color: rgba(255, 255, 255, 0.7);
}

.mock-fixture-meta {
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.3px;
  text-transform: uppercase;
  color: rgba(255, 255, 255, 0.5);
}

.mock-standings {
  width: 280px;
  max-width: 100%;
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.mock-standings-row {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 6px 4px;
  font-size: 14px;
  font-weight: 600;
  color: #ffffff;
}

.mock-standings-row .mock-team-name {
  flex: 1;
  font-size: 14px;
}

.mock-position {
  width: 24px;
  height: 24px;
  flex-shrink: 0;
  border-radius: 7px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 14px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  color: rgba(255, 255, 255, 0.7);
}

.mock-zone-ball {
  width: 24px;
  height: 24px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 14px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  color: #000000;
}

.mock-zone-ball--teal {
  background: #2dd4bf;
}

.mock-zone-ball--red {
  background: #ef4444;
}

.mock-standings-row .mock-points {
  font-variant-numeric: tabular-nums;
  color: rgba(255, 255, 255, 0.7);
}
```

- [ ] **Step 2: Verify every produced selector exists**

Run: `grep -c "^\." website/styles.css` before and after — count should increase by the
number of new top-level rules added (30). More important: grep each class name listed in
"Produces" above and confirm exactly one definition exists:

```bash
for cls in hub-page league-grid league-card hub-footer app-page feature-block \
  mock-match-card mock-team mock-crest mock-team-name mock-score mock-live-chip \
  mock-fixtures mock-fixture-row mock-fixture-meta mock-standings mock-standings-row \
  mock-position mock-zone-ball mock-points; do
  echo -n "$cls: "; grep -c "\.$cls" website/styles.css
done
```

Expected: every count ≥ 1 (some appear multiple times, e.g. `mock-team-name` in both the
match-card and standings-row contexts — that's expected, not a duplicate-definition bug,
since the second is a compound selector `.mock-standings-row .mock-team-name`).

- [ ] **Step 3: Commit**

```bash
git add website/styles.css
git commit -m "Add shared CSS for marketing site hub + feature showcase"
```

---

### Task 2: Hub page (`/`)

**Files:**
- Modify: `website/index.html` (full rewrite — this file currently holds Brasileirão's old
  placeholder content, which Task 3 recreates at its new home; this task's rewrite doesn't
  need to preserve anything from the current file)

**Interfaces:**
- Consumes: `.hub-page`, `.league-grid`, `.league-card`, `.hub-footer` from Task 1.
- Produces: nothing consumed by later tasks (leaf page).

- [ ] **Step 1: Replace the full contents of `website/index.html`**

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Live Football Scores — Brasileirão, Premier League, La Liga &amp; More</title>
  <link rel="icon" type="image/png" href="/favicon.png">
  <link rel="stylesheet" href="/styles.css">
</head>
<body>
  <div class="stadium-background"></div>
  <div class="blob blob-accent"></div>
  <div class="blob blob-teal"></div>
  <main class="page hub-page">
    <div class="content">
      <h1 class="title">Live football, everywhere you follow it.</h1>
      <p class="tagline">Real-time scores, fixtures, and standings — one focused app per league, six leagues and counting.</p>
      <div class="league-grid">
        <a class="league-card" href="/brasileirao/" style="--accent: #ff4d5e;">
          <h2>Brasileirão</h2>
          <p>Brazil's top flight</p>
          <span class="glass-card badge">Coming soon</span>
        </a>
        <a class="league-card" href="/premier-league/" style="--accent: #3D195B;">
          <h2>Premier League</h2>
          <p>England's top flight</p>
          <span class="glass-card badge">Coming soon</span>
        </a>
        <a class="league-card" href="/ligue-1/" style="--accent: #FACC15;">
          <h2>Ligue 1</h2>
          <p>France's top flight</p>
          <span class="glass-card badge">Coming soon</span>
        </a>
        <a class="league-card" href="/liga-portugal/" style="--accent: #00235A;">
          <h2>Liga Portugal</h2>
          <p>Portugal's top flight</p>
          <span class="glass-card badge">Coming soon</span>
        </a>
        <a class="league-card" href="/scottish-premiership/" style="--accent: #005EB8;">
          <h2>Scottish Premiership</h2>
          <p>Scotland's top flight</p>
          <span class="glass-card badge">Coming soon</span>
        </a>
        <a class="league-card" href="/la-liga/" style="--accent: #AA151B;">
          <h2>La Liga</h2>
          <p>Spain's top flight</p>
          <span class="glass-card badge">Coming soon</span>
        </a>
      </div>
      <div class="hub-footer">
        <a href="mailto:vibritoapps@gmail.com">vibritoapps@gmail.com</a>
      </div>
    </div>
  </main>
</body>
</html>
```

- [ ] **Step 2: Verify**

```bash
grep -c "league-card" website/index.html   # expect 6
grep -c "Coming soon"  website/index.html  # expect 6
python3 -c "import html.parser; html.parser.HTMLParser().feed(open('website/index.html').read())"  # no exception = well-formed
```

- [ ] **Step 3: Commit**

```bash
git add website/index.html
git commit -m "Redesign site root as the app-family hub page"
```

---

### Task 3: Brasileirão — move to `/brasileirao/` and redesign

**Files:**
- Create: `website/brasileirao/index.html`
- Create: `website/_redirects`
- Move (`git mv`): `website/privacy/{en,en-gb,fr,pt-br,pt-pt}/index.html` →
  `website/brasileirao/privacy/{same locale}/index.html`
- Move (`git mv`): `website/support/index.html` → `website/brasileirao/support/index.html`
- Modify: all 6 moved files (fix internal links — see Step 2)

**Interfaces:**
- Consumes: `.app-page`, `.feature-block`, `.mock-*` classes from Task 1.
- Produces: `/brasileirao/`, `/brasileirao/privacy/{locale}/`, `/brasileirao/support/` as the
  new canonical Brasileirão URLs — Task 9 needs these exact paths for the App Store Connect
  metadata update.

- [ ] **Step 1: Move the existing privacy and support content**

```bash
git mv website/privacy website/brasileirao/privacy
git mv website/support website/brasileirao/support
```

- [ ] **Step 2: Fix internal links in the 6 moved files**

Every moved file currently links back to the old root-level paths. Run:

```bash
for f in website/brasileirao/privacy/*/index.html website/brasileirao/support/index.html; do
  sed -i '' \
    -e 's#href="/privacy/#href="/brasileirao/privacy/#g' \
    -e 's#href="/"#href="/brasileirao/"#g' \
    "$f"
done
```

Then verify no moved file still points at the old root-relative privacy path or plain `/`:

```bash
grep -rn 'href="/privacy/' website/brasileirao/   # expect no output
grep -rn 'href="/"'        website/brasileirao/   # expect no output
```

(`sed -i ''` is the BSD/macOS form used here since this repo is developed on macOS; if run on
GNU sed, drop the empty string argument after `-i`.)

- [ ] **Step 3: Create `website/brasileirao/index.html`**

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Brasileirão — Live Scores, Fixtures &amp; Standings</title>
  <link rel="icon" type="image/png" href="/favicon.png">
  <link rel="stylesheet" href="/styles.css">
</head>
<body>
  <div class="stadium-background"></div>
  <div class="blob blob-accent"></div>
  <div class="blob blob-teal"></div>
  <main class="page app-page">
    <div class="content">
      <div class="hero">
        <h1 class="title">Brasileirão</h1>
        <p class="tagline">Live scores, fixtures, and the Brasileirão table — all in one place.</p>
        <div class="glass-card badge">Coming soon to the App Store</div>
      </div>

      <div class="feature-block">
        <div class="copy">
          <h3>Every score, the moment it happens.</h3>
          <p>Live scores update in real time, with goals, cards, and substitutions as they happen.</p>
        </div>
        <div class="mock">
          <div class="mock-match-card">
            <div class="mock-team">
              <span class="mock-crest">H</span>
              <span class="mock-team-name">Home</span>
            </div>
            <span class="mock-score">2 – 1</span>
            <div class="mock-team">
              <span class="mock-crest">A</span>
              <span class="mock-team-name">Away</span>
            </div>
            <span class="mock-live-chip">LIVE 67&rsquo;</span>
          </div>
        </div>
      </div>

      <div class="feature-block reverse">
        <div class="copy">
          <h3>Never miss a matchday.</h3>
          <p>Follow every round of the Brasileirão's 38-round season, from kickoff to final whistle.</p>
        </div>
        <div class="mock">
          <div class="mock-fixtures">
            <div class="mock-fixture-row mock-fixture-row--finished">
              <span>Home 3 – 0 Away</span>
              <span class="mock-fixture-meta">FT</span>
            </div>
            <div class="mock-fixture-row">
              <span>Home vs Away</span>
              <span class="mock-fixture-meta">Sat 16:00</span>
            </div>
          </div>
        </div>
      </div>

      <div class="feature-block">
        <div class="copy">
          <h3>The full table, always current.</h3>
          <p>The complete Brasileirão table, updated after every match — with qualification and relegation zones marked clearly.</p>
        </div>
        <div class="mock">
          <div class="mock-standings">
            <div class="mock-standings-row">
              <span class="mock-position"><span class="mock-zone-ball mock-zone-ball--teal">1</span></span>
              <span class="mock-team-name">Team A</span>
              <span class="mock-points">42</span>
            </div>
            <div class="mock-standings-row">
              <span class="mock-position"><span class="mock-zone-ball mock-zone-ball--teal">2</span></span>
              <span class="mock-team-name">Team B</span>
              <span class="mock-points">39</span>
            </div>
            <div class="mock-standings-row">
              <span class="mock-position">3</span>
              <span class="mock-team-name">Team C</span>
              <span class="mock-points">35</span>
            </div>
            <div class="mock-standings-row">
              <span class="mock-position">4</span>
              <span class="mock-team-name">Team D</span>
              <span class="mock-points">33</span>
            </div>
            <div class="mock-standings-row">
              <span class="mock-position"><span class="mock-zone-ball mock-zone-ball--red">18</span></span>
              <span class="mock-team-name">Team R</span>
              <span class="mock-points">19</span>
            </div>
          </div>
        </div>
      </div>

      <div class="app-footer">
        <a class="glass-card privacy-link" href="/brasileirao/privacy/en/">Privacy Policy</a>
        <a class="back-link" href="/">← Back to all apps</a>
      </div>
    </div>
  </main>
</body>
</html>
```

- [ ] **Step 4: Create `website/_redirects`**

```
/privacy/*  /brasileirao/privacy/:splat  301
/support/*  /brasileirao/support/:splat  301
```

(This does **not** redirect `/` itself — the root now serves the hub page from Task 2, not a
redirect to Brasileirão.)

- [ ] **Step 5: Verify**

```bash
ls website/brasileirao/privacy/     # expect: en en-gb fr pt-br pt-pt
ls website/brasileirao/support/     # expect: index.html
ls website/privacy website/support 2>&1  # expect: both "No such file or directory"
grep -c "feature-block" website/brasileirao/index.html  # expect 3
```

- [ ] **Step 6: Commit**

```bash
git add website/brasileirao website/_redirects
git commit -m "Move Brasileirão to /brasileirao/ and redesign its landing page"
```

---

### Task 4: Redesign Premier League, Ligue 1, and Liga Portugal pages

**Files:**
- Modify: `website/premier-league/index.html` (full rewrite)
- Modify: `website/ligue-1/index.html` (full rewrite)
- Modify: `website/liga-portugal/index.html` (full rewrite)

**Interfaces:**
- Consumes: `.app-page`, `.feature-block`, `.mock-*` classes from Task 1.
- These 3 apps' `privacy/`/`support/` folders are **not touched** by this task (Task 7 adds
  their `es/` locale separately).

- [ ] **Step 1: Replace `website/premier-league/index.html`**

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Premier League 2026 — Live Scores, Fixtures &amp; Standings</title>
  <link rel="icon" type="image/png" href="/favicon.png">
  <link rel="stylesheet" href="/styles.css">
  <style>:root { --accent: #3D195B; }</style>
</head>
<body>
  <div class="stadium-background"></div>
  <div class="blob blob-accent"></div>
  <div class="blob blob-teal"></div>
  <main class="page app-page">
    <div class="content">
      <div class="hero">
        <h1 class="title">Premier League 2026</h1>
        <p class="tagline">Live scores, fixtures, and the Premier League table — all in one place.</p>
        <div class="glass-card badge">Coming soon to the App Store</div>
      </div>

      <div class="feature-block">
        <div class="copy">
          <h3>Every score, the moment it happens.</h3>
          <p>Live scores update in real time, with goals, cards, and substitutions as they happen.</p>
        </div>
        <div class="mock">
          <div class="mock-match-card">
            <div class="mock-team">
              <span class="mock-crest">H</span>
              <span class="mock-team-name">Home</span>
            </div>
            <span class="mock-score">2 – 1</span>
            <div class="mock-team">
              <span class="mock-crest">A</span>
              <span class="mock-team-name">Away</span>
            </div>
            <span class="mock-live-chip">LIVE 67&rsquo;</span>
          </div>
        </div>
      </div>

      <div class="feature-block reverse">
        <div class="copy">
          <h3>Never miss a matchday.</h3>
          <p>See what's next and what just finished, round by round, all season long.</p>
        </div>
        <div class="mock">
          <div class="mock-fixtures">
            <div class="mock-fixture-row mock-fixture-row--finished">
              <span>Home 3 – 0 Away</span>
              <span class="mock-fixture-meta">FT</span>
            </div>
            <div class="mock-fixture-row">
              <span>Home vs Away</span>
              <span class="mock-fixture-meta">Sat 16:00</span>
            </div>
          </div>
        </div>
      </div>

      <div class="feature-block">
        <div class="copy">
          <h3>The full table, always current.</h3>
          <p>The complete Premier League table, updated after every match — with qualification and relegation zones marked clearly.</p>
        </div>
        <div class="mock">
          <div class="mock-standings">
            <div class="mock-standings-row">
              <span class="mock-position"><span class="mock-zone-ball mock-zone-ball--teal">1</span></span>
              <span class="mock-team-name">Team A</span>
              <span class="mock-points">42</span>
            </div>
            <div class="mock-standings-row">
              <span class="mock-position"><span class="mock-zone-ball mock-zone-ball--teal">2</span></span>
              <span class="mock-team-name">Team B</span>
              <span class="mock-points">39</span>
            </div>
            <div class="mock-standings-row">
              <span class="mock-position">3</span>
              <span class="mock-team-name">Team C</span>
              <span class="mock-points">35</span>
            </div>
            <div class="mock-standings-row">
              <span class="mock-position">4</span>
              <span class="mock-team-name">Team D</span>
              <span class="mock-points">33</span>
            </div>
            <div class="mock-standings-row">
              <span class="mock-position"><span class="mock-zone-ball mock-zone-ball--red">18</span></span>
              <span class="mock-team-name">Team R</span>
              <span class="mock-points">19</span>
            </div>
          </div>
        </div>
      </div>

      <div class="app-footer">
        <a class="glass-card privacy-link" href="/premier-league/privacy/en/">Privacy Policy</a>
        <a class="back-link" href="/">← Back to all apps</a>
      </div>
    </div>
  </main>
</body>
</html>
```

- [ ] **Step 2: Replace `website/ligue-1/index.html`**

Read the file you just wrote in Step 1 (`website/premier-league/index.html`) and copy it
verbatim to `website/ligue-1/index.html`, then apply exactly these substitutions and no
others: `Premier League 2026` → `Ligue 1 2026` (title tag and `<h1>`); tagline → `Live
scores, fixtures, and the Ligue 1 table — all in one place.`; `--accent: #3D195B;` →
`--accent: #FACC15;`; standings paragraph → `The complete Ligue 1 table, updated after every
match — with qualification and relegation zones marked clearly.`; `/premier-league/` → `/ligue-1/`
in the privacy-link `href`. The Matchday and Fixtures blocks' copy and markup are unchanged
(league-agnostic).

- [ ] **Step 3: Replace `website/liga-portugal/index.html`**

Read `website/premier-league/index.html` again and copy it to
`website/liga-portugal/index.html`, applying: `Premier League 2026` → `Liga Portugal 2026`;
tagline → `Live scores, fixtures, and the Liga Portugal table — all in one place.`;
`--accent: #3D195B;` → `--accent: #00235A;`; standings paragraph → `The complete Liga
Portugal table, updated after every match — with qualification and relegation zones marked
clearly.`; `/premier-league/` → `/liga-portugal/` in the privacy-link `href`.

- [ ] **Step 4: Verify**

```bash
for d in premier-league ligue-1 liga-portugal; do
  echo "== $d =="
  grep -c "feature-block" "website/$d/index.html"   # expect 3 each
  grep -c "Coming soon"   "website/$d/index.html"   # expect 1 each
  python3 -c "import html.parser; html.parser.HTMLParser().feed(open('website/$d/index.html').read())"
done
```

- [ ] **Step 5: Commit**

```bash
git add website/premier-league/index.html website/ligue-1/index.html website/liga-portugal/index.html
git commit -m "Redesign Premier League, Ligue 1, and Liga Portugal landing pages"
```

---

### Task 5: Scottish Premiership — new pages

**Files:**
- Create: `website/scottish-premiership/index.html`
- Create: `website/scottish-premiership/privacy/en/index.html`
- Create: `website/scottish-premiership/privacy/en-gb/index.html`
- Create: `website/scottish-premiership/privacy/fr/index.html`
- Create: `website/scottish-premiership/privacy/pt-br/index.html`
- Create: `website/scottish-premiership/privacy/pt-pt/index.html`
- Create: `website/scottish-premiership/privacy/es/index.html`
- Create: `website/scottish-premiership/support/index.html`

**Interfaces:**
- Consumes: `.app-page`, `.feature-block`, `.mock-*` classes from Task 1; the
  `.privacy-page`/`.policy-card`/`.lang-switcher` classes already in `styles.css` (unchanged,
  pre-existing).

- [ ] **Step 1: Create `website/scottish-premiership/index.html`**

Read `website/premier-league/index.html` (created in Task 4, already committed on this
branch) and copy it to `website/scottish-premiership/index.html`, applying exactly:
`Premier League 2026` → `Scottish Premiership 2026` (title tag and `<h1>`); tagline → `Live
scores, fixtures, and the Scottish Premiership table — all in one place.`; `--accent:
#3D195B;` → `--accent: #005EB8;`; standings paragraph → `The complete Scottish Premiership
table, updated after every match — with qualification and relegation zones marked clearly.`;
`/premier-league/` → `/scottish-premiership/` in the privacy-link `href`. The Matchday and
Fixtures blocks' copy and markup are unchanged (league-agnostic).

- [ ] **Step 2: Create `website/scottish-premiership/privacy/en/index.html`**

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Scottish Premiership 2026 — Privacy Policy</title>
  <link rel="icon" type="image/png" href="/favicon.png">
  <link rel="stylesheet" href="/styles.css">
  <style>:root { --accent: #005EB8; }</style>
</head>
<body>
  <div class="stadium-background"></div>
  <div class="blob blob-accent"></div>
  <div class="blob blob-teal"></div>
  <main class="page privacy-page">
    <div class="content">
      <nav class="lang-switcher" aria-label="Language">
        <a href="/scottish-premiership/privacy/en/" aria-current="true">English</a>
        <a href="/scottish-premiership/privacy/en-gb/">English (UK)</a>
        <a href="/scottish-premiership/privacy/fr/">Français</a>
        <a href="/scottish-premiership/privacy/pt-br/">Português (Brasil)</a>
        <a href="/scottish-premiership/privacy/pt-pt/">Português (Portugal)</a>
        <a href="/scottish-premiership/privacy/es/">Español</a>
      </nav>
      <article class="policy-card">
        <h1>Privacy Policy</h1>
        <p>This Privacy Policy explains how the Scottish Premiership 2026 app ("the app") handles information when you use it.</p>

        <h2>1. Information We Collect</h2>
        <p>This app does not collect, store, or share any personal information. It does not require account creation, sign-in, or any personal details. The app fetches public sports data — match scores, fixtures, and standings for the Scottish Premiership — from a third-party sports data API. This data is cached locally on your device to improve performance and is not transmitted anywhere else.</p>

        <h2>2. Analytics and Tracking</h2>
        <p>This app uses Firebase Analytics and Firebase Crashlytics (both provided by Google) to understand how the app is used and to diagnose crashes. Firebase Analytics collects general usage data such as which screens are viewed and how often the app is opened; Firebase Crashlytics collects crash reports, which may include device model, OS version, and app state at the time of the crash. Neither service is used for advertising, and neither collects your name, email, or other personally identifying information.</p>

        <h2>3. Third-Party Services</h2>
        <p>Match, team, and competition data (including team crest images) is loaded from a third-party sports data API. This app also uses Firebase (Google) for analytics and crash reporting, as described above. Loading data from these services may expose your device's IP address to them, as is standard for any network request. We do not control and are not responsible for these services' own data practices.</p>

        <h2>4. Data Stored on Your Device</h2>
        <p>The app uses on-device storage to cache match data for faster loading. This data stays on your device and is not sent to us.</p>

        <h2>5. Children's Privacy</h2>
        <p>This app is not directed at children and does not knowingly collect information from children.</p>

        <h2>6. Changes to This Policy</h2>
        <p>We may update this Privacy Policy from time to time. Continued use of the app after changes constitutes acceptance of the updated policy.</p>

        <h2>7. Contact</h2>
        <p>Questions about this Privacy Policy can be directed to the app's support contact listed on its App Store page.</p>

        <a class="back-link" href="/scottish-premiership/">← Back to home</a>
      </article>
    </div>
  </main>
</body>
</html>
```

- [ ] **Step 3: Create `website/scottish-premiership/privacy/en-gb/index.html`**

Read the file you just wrote in Step 2 and copy it to
`website/scottish-premiership/privacy/en-gb/index.html`, applying exactly: `<html
lang="en">` → `<html lang="en-GB">`; move `aria-current="true"` from the English link to the
English (UK) link; everything else — title, nav `aria-label`, all 7 body paragraphs, all 6
nav hrefs, the back-link — is unchanged.

- [ ] **Step 4: Create `website/scottish-premiership/privacy/fr/index.html`**

```html
<!doctype html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Scottish Premiership 2026 — Politique de confidentialité</title>
  <link rel="icon" type="image/png" href="/favicon.png">
  <link rel="stylesheet" href="/styles.css">
  <style>:root { --accent: #005EB8; }</style>
</head>
<body>
  <div class="stadium-background"></div>
  <div class="blob blob-accent"></div>
  <div class="blob blob-teal"></div>
  <main class="page privacy-page">
    <div class="content">
      <nav class="lang-switcher" aria-label="Langue">
        <a href="/scottish-premiership/privacy/en/">English</a>
        <a href="/scottish-premiership/privacy/en-gb/">English (UK)</a>
        <a href="/scottish-premiership/privacy/fr/" aria-current="true">Français</a>
        <a href="/scottish-premiership/privacy/pt-br/">Português (Brasil)</a>
        <a href="/scottish-premiership/privacy/pt-pt/">Português (Portugal)</a>
        <a href="/scottish-premiership/privacy/es/">Español</a>
      </nav>
      <article class="policy-card">
        <h1>Politique de confidentialité</h1>
        <p>Cette politique de confidentialité explique comment l'application Scottish Premiership 2026 (« l'application ») traite les informations lorsque vous l'utilisez.</p>

        <h2>1. Informations que nous collectons</h2>
        <p>Cette application ne collecte, ne stocke et ne partage aucune information personnelle. Elle ne nécessite ni création de compte, ni connexion, ni aucune donnée personnelle. L'application récupère des données sportives publiques — scores, calendrier et classement du Scottish Premiership — auprès d'une API sportive tierce. Ces données sont mises en cache localement sur votre appareil afin d'améliorer les performances et ne sont transmises nulle part ailleurs.</p>

        <h2>2. Analyse et suivi</h2>
        <p>Cette application utilise Firebase Analytics et Firebase Crashlytics (tous deux fournis par Google) pour comprendre l'utilisation de l'application et diagnostiquer les plantages. Firebase Analytics collecte des données d'utilisation générales, comme les écrans consultés et la fréquence d'ouverture de l'application ; Firebase Crashlytics collecte des rapports de plantage, qui peuvent inclure le modèle de l'appareil, la version du système d'exploitation et l'état de l'application au moment du plantage. Aucun de ces services n'est utilisé à des fins publicitaires, et aucun ne collecte votre nom, votre adresse e-mail ou d'autres informations personnelles identifiables.</p>

        <h2>3. Services tiers</h2>
        <p>Les données de matchs, d'équipes et de compétition (y compris les images des écussons d'équipe) sont chargées depuis une API sportive tierce. Cette application utilise également Firebase (Google) pour l'analyse et le diagnostic des plantages, comme décrit ci-dessus. Le chargement de ces données peut exposer l'adresse IP de votre appareil à ces services, comme c'est le cas pour toute requête réseau standard. Nous ne contrôlons pas et ne sommes pas responsables des pratiques de données de ces services.</p>

        <h2>4. Données stockées sur votre appareil</h2>
        <p>L'application utilise un stockage local pour mettre en cache les données de match afin d'accélérer leur chargement. Ces données restent sur votre appareil et ne nous sont jamais transmises.</p>

        <h2>5. Confidentialité des enfants</h2>
        <p>Cette application ne s'adresse pas aux enfants et ne collecte sciemment aucune information les concernant.</p>

        <h2>6. Modifications de cette politique</h2>
        <p>Nous pouvons mettre à jour cette politique de confidentialité de temps à autre. La poursuite de l'utilisation de l'application après ces modifications vaut acceptation de la politique mise à jour.</p>

        <h2>7. Contact</h2>
        <p>Les questions relatives à cette politique de confidentialité peuvent être adressées au contact d'assistance indiqué sur la page App Store de l'application.</p>

        <a class="back-link" href="/scottish-premiership/">← Retour à l'accueil</a>
      </article>
    </div>
  </main>
</body>
</html>
```

- [ ] **Step 5: Create `website/scottish-premiership/privacy/pt-br/index.html`**

```html
<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Scottish Premiership 2026 — Política de Privacidade</title>
  <link rel="icon" type="image/png" href="/favicon.png">
  <link rel="stylesheet" href="/styles.css">
  <style>:root { --accent: #005EB8; }</style>
</head>
<body>
  <div class="stadium-background"></div>
  <div class="blob blob-accent"></div>
  <div class="blob blob-teal"></div>
  <main class="page privacy-page">
    <div class="content">
      <nav class="lang-switcher" aria-label="Idioma">
        <a href="/scottish-premiership/privacy/en/">English</a>
        <a href="/scottish-premiership/privacy/en-gb/">English (UK)</a>
        <a href="/scottish-premiership/privacy/fr/">Français</a>
        <a href="/scottish-premiership/privacy/pt-br/" aria-current="true">Português (Brasil)</a>
        <a href="/scottish-premiership/privacy/pt-pt/">Português (Portugal)</a>
        <a href="/scottish-premiership/privacy/es/">Español</a>
      </nav>
      <article class="policy-card">
        <h1>Política de Privacidade</h1>
        <p>Esta Política de Privacidade explica como o aplicativo Scottish Premiership 2026 ("o aplicativo") trata as informações quando você o utiliza.</p>

        <h2>1. Informações que coletamos</h2>
        <p>Este aplicativo não coleta, armazena nem compartilha nenhuma informação pessoal. Ele não exige criação de conta, login ou qualquer dado pessoal. O aplicativo busca dados esportivos públicos — placares, jogos e classificação do Scottish Premiership — em uma API esportiva de terceiros. Esses dados são armazenados em cache localmente no seu dispositivo para melhorar o desempenho e não são transmitidos para nenhum outro lugar.</p>

        <h2>2. Análise e rastreamento</h2>
        <p>Este aplicativo utiliza o Firebase Analytics e o Firebase Crashlytics (ambos fornecidos pelo Google) para entender como o aplicativo é usado e diagnosticar falhas. O Firebase Analytics coleta dados de uso gerais, como quais telas são visualizadas e com que frequência o aplicativo é aberto; o Firebase Crashlytics coleta relatórios de falhas, que podem incluir o modelo do dispositivo, a versão do sistema operacional e o estado do aplicativo no momento da falha. Nenhum dos serviços é usado para publicidade, e nenhum coleta seu nome, e-mail ou outras informações de identificação pessoal.</p>

        <h2>3. Serviços de terceiros</h2>
        <p>Os dados de partidas, times e competição (incluindo as imagens dos escudos dos times) são carregados de uma API esportiva de terceiros. Este aplicativo também utiliza o Firebase (Google) para análise e relatórios de falhas, conforme descrito acima. O carregamento de dados desses serviços pode expor o endereço IP do seu dispositivo a eles, como é padrão em qualquer solicitação de rede. Não controlamos nem somos responsáveis pelas práticas de dados desses serviços.</p>

        <h2>4. Dados armazenados no seu dispositivo</h2>
        <p>O aplicativo utiliza armazenamento local para colocar em cache os dados das partidas e acelerar o carregamento. Esses dados permanecem no seu dispositivo e não são enviados para nós.</p>

        <h2>5. Privacidade infantil</h2>
        <p>Este aplicativo não é direcionado a crianças e não coleta intencionalmente informações de crianças.</p>

        <h2>6. Alterações a esta política</h2>
        <p>Podemos atualizar esta Política de Privacidade periodicamente. O uso continuado do aplicativo após as alterações constitui aceitação da política atualizada.</p>

        <h2>7. Contato</h2>
        <p>Dúvidas sobre esta Política de Privacidade podem ser enviadas para o contato de suporte listado na página do aplicativo na App Store.</p>

        <a class="back-link" href="/scottish-premiership/">← Voltar ao início</a>
      </article>
    </div>
  </main>
</body>
</html>
```

- [ ] **Step 6: Create `website/scottish-premiership/privacy/pt-pt/index.html`**

```html
<!doctype html>
<html lang="pt-PT">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Scottish Premiership 2026 — Política de Privacidade</title>
  <link rel="icon" type="image/png" href="/favicon.png">
  <link rel="stylesheet" href="/styles.css">
  <style>:root { --accent: #005EB8; }</style>
</head>
<body>
  <div class="stadium-background"></div>
  <div class="blob blob-accent"></div>
  <div class="blob blob-teal"></div>
  <main class="page privacy-page">
    <div class="content">
      <nav class="lang-switcher" aria-label="Idioma">
        <a href="/scottish-premiership/privacy/en/">English</a>
        <a href="/scottish-premiership/privacy/en-gb/">English (UK)</a>
        <a href="/scottish-premiership/privacy/fr/">Français</a>
        <a href="/scottish-premiership/privacy/pt-br/">Português (Brasil)</a>
        <a href="/scottish-premiership/privacy/pt-pt/" aria-current="true">Português (Portugal)</a>
        <a href="/scottish-premiership/privacy/es/">Español</a>
      </nav>
      <article class="policy-card">
        <h1>Política de Privacidade</h1>
        <p>Esta Política de Privacidade explica como a aplicação Scottish Premiership 2026 ("a aplicação") trata as informações quando a utiliza.</p>

        <h2>1. Informações que recolhemos</h2>
        <p>Esta aplicação não recolhe, armazena nem partilha qualquer informação pessoal. Não exige criação de conta, sessão iniciada nem quaisquer dados pessoais. A aplicação obtém dados desportivos públicos — resultados, jogos e classificação do Scottish Premiership — a partir de uma API desportiva de terceiros. Estes dados são armazenados em cache localmente no seu dispositivo para melhorar o desempenho e não são transmitidos para mais nenhum lugar.</p>

        <h2>2. Análise e monitorização</h2>
        <p>Esta aplicação utiliza o Firebase Analytics e o Firebase Crashlytics (ambos fornecidos pela Google) para compreender a utilização da aplicação e diagnosticar falhas. O Firebase Analytics recolhe dados de utilização gerais, como os ecrãs visualizados e a frequência com que a aplicação é aberta; o Firebase Crashlytics recolhe relatórios de falhas, que podem incluir o modelo do dispositivo, a versão do sistema operativo e o estado da aplicação no momento da falha. Nenhum dos serviços é utilizado para publicidade, e nenhum recolhe o seu nome, e-mail ou outras informações de identificação pessoal.</p>

        <h2>3. Serviços de terceiros</h2>
        <p>Os dados de jogos, equipas e competição (incluindo as imagens dos emblemas das equipas) são carregados a partir de uma API desportiva de terceiros. Esta aplicação utiliza também o Firebase (Google) para análise e relatórios de falhas, conforme descrito acima. O carregamento de dados destes serviços pode expor o endereço IP do seu dispositivo aos mesmos, tal como é habitual em qualquer pedido de rede. Não controlamos nem somos responsáveis pelas práticas de dados destes serviços.</p>

        <h2>4. Dados armazenados no seu dispositivo</h2>
        <p>A aplicação utiliza armazenamento local para colocar em cache os dados dos jogos e acelerar o respetivo carregamento. Estes dados permanecem no seu dispositivo e não nos são enviados.</p>

        <h2>5. Privacidade das crianças</h2>
        <p>Esta aplicação não se destina a crianças e não recolhe intencionalmente informações sobre crianças.</p>

        <h2>6. Alterações a esta política</h2>
        <p>Podemos atualizar esta Política de Privacidade periodicamente. A utilização continuada da aplicação após alterações constitui aceitação da política atualizada.</p>

        <h2>7. Contacto</h2>
        <p>Questões sobre esta Política de Privacidade podem ser enviadas para o contacto de suporte indicado na página da aplicação na App Store.</p>

        <a class="back-link" href="/scottish-premiership/">← Voltar ao início</a>
      </article>
    </div>
  </main>
</body>
</html>
```

- [ ] **Step 7: Create `website/scottish-premiership/privacy/es/index.html`**

```html
<!doctype html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Scottish Premiership 2026 — Política de Privacidad</title>
  <link rel="icon" type="image/png" href="/favicon.png">
  <link rel="stylesheet" href="/styles.css">
  <style>:root { --accent: #005EB8; }</style>
</head>
<body>
  <div class="stadium-background"></div>
  <div class="blob blob-accent"></div>
  <div class="blob blob-teal"></div>
  <main class="page privacy-page">
    <div class="content">
      <nav class="lang-switcher" aria-label="Idioma">
        <a href="/scottish-premiership/privacy/en/">English</a>
        <a href="/scottish-premiership/privacy/en-gb/">English (UK)</a>
        <a href="/scottish-premiership/privacy/fr/">Français</a>
        <a href="/scottish-premiership/privacy/pt-br/">Português (Brasil)</a>
        <a href="/scottish-premiership/privacy/pt-pt/">Português (Portugal)</a>
        <a href="/scottish-premiership/privacy/es/" aria-current="true">Español</a>
      </nav>
      <article class="policy-card">
        <h1>Política de Privacidad</h1>
        <p>Esta Política de Privacidad explica cómo la app Scottish Premiership 2026 ("la app") gestiona la información cuando la utilizas.</p>

        <h2>1. Información que recopilamos</h2>
        <p>Esta app no recopila, almacena ni comparte ningún dato personal. No requiere creación de cuenta, inicio de sesión ni datos personales. La app obtiene datos deportivos públicos — resultados, calendarios y clasificación del Scottish Premiership — de una API deportiva de terceros. Estos datos se almacenan en caché localmente en tu dispositivo para mejorar el rendimiento y no se transmiten a ningún otro lugar.</p>

        <h2>2. Análisis y seguimiento</h2>
        <p>Esta app utiliza Firebase Analytics y Firebase Crashlytics (ambos de Google) para entender cómo se usa la app y diagnosticar fallos. Firebase Analytics recopila datos de uso generales, como qué pantallas se visualizan y con qué frecuencia se abre la app; Firebase Crashlytics recopila informes de fallos, que pueden incluir el modelo del dispositivo, la versión del sistema operativo y el estado de la app en el momento del fallo. Ninguno de estos servicios se utiliza con fines publicitarios, ni recopila tu nombre, correo electrónico u otra información de identificación personal.</p>

        <h2>3. Servicios de terceros</h2>
        <p>Los datos de partidos, equipos y competición (incluidas las imágenes de los escudos de los equipos) se obtienen de una API deportiva de terceros. Esta app también utiliza Firebase (Google) para análisis e informes de fallos, como se describe anteriormente. Cargar datos desde estos servicios puede exponer la dirección IP de tu dispositivo, como es habitual en cualquier solicitud de red. No controlamos ni somos responsables de las prácticas de datos propias de estos servicios.</p>

        <h2>4. Datos almacenados en tu dispositivo</h2>
        <p>La app utiliza almacenamiento local para guardar en caché los datos de los partidos y así cargar más rápido. Estos datos permanecen en tu dispositivo y no se nos envían.</p>

        <h2>5. Privacidad de los menores</h2>
        <p>Esta app no está dirigida a menores y no recopila conscientemente información de menores.</p>

        <h2>6. Cambios en esta política</h2>
        <p>Podemos actualizar esta Política de Privacidad periódicamente. El uso continuado de la app después de los cambios constituye la aceptación de la política actualizada.</p>

        <h2>7. Contacto</h2>
        <p>Las preguntas sobre esta Política de Privacidad pueden dirigirse al contacto de soporte de la app que figura en su página de la App Store.</p>

        <a class="back-link" href="/scottish-premiership/">← Volver al inicio</a>
      </article>
    </div>
  </main>
</body>
</html>
```

- [ ] **Step 8: Create `website/scottish-premiership/support/index.html`**

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Scottish Premiership 2026 — Support</title>
  <link rel="icon" type="image/png" href="/favicon.png">
  <link rel="stylesheet" href="/styles.css">
  <style>:root { --accent: #005EB8; }</style>
</head>
<body>
  <div class="stadium-background"></div>
  <div class="blob blob-accent"></div>
  <div class="blob blob-teal"></div>
  <main class="page privacy-page">
    <div class="content">
      <article class="policy-card">
        <h1>Support</h1>
        <p>Need help with the Scottish Premiership 2026 app, or have feedback or a bug to report? Get in touch and we'll get back to you.</p>

        <h2>Contact</h2>
        <p><a href="mailto:vibritoapps@gmail.com">vibritoapps@gmail.com</a></p>

        <h2>Frequently Asked</h2>
        <p><strong>Scores aren't updating.</strong> Matchday, Fixtures, and Standings refresh automatically in the background. Pull down on the Fixtures or Standings screen to force a refresh.</p>
        <p><strong>The app requires no sign-in or account</strong> — there's nothing to set up. If something looks wrong, it's most likely a data issue upstream; let us know via the email above and we'll take a look.</p>

        <a class="back-link" href="/scottish-premiership/">← Back to home</a>
      </article>
    </div>
  </main>
</body>
</html>
```

- [ ] **Step 9: Verify**

```bash
ls website/scottish-premiership/privacy/   # expect: en en-gb fr pt-br pt-pt es
for f in website/scottish-premiership/index.html website/scottish-premiership/support/index.html website/scottish-premiership/privacy/*/index.html; do
  python3 -c "import html.parser; html.parser.HTMLParser().feed(open('$f').read())" || echo "MALFORMED: $f"
done
grep -c "feature-block" website/scottish-premiership/index.html  # expect 3
```

- [ ] **Step 10: Commit**

```bash
git add website/scottish-premiership
git commit -m "Add Scottish Premiership's website section (landing page, privacy, support)"
```

---

### Task 6: La Liga — new pages

**Files:**
- Create: `website/la-liga/index.html`
- Create: `website/la-liga/privacy/en/index.html`
- Create: `website/la-liga/privacy/en-gb/index.html`
- Create: `website/la-liga/privacy/fr/index.html`
- Create: `website/la-liga/privacy/pt-br/index.html`
- Create: `website/la-liga/privacy/pt-pt/index.html`
- Create: `website/la-liga/privacy/es/index.html`
- Create: `website/la-liga/support/index.html`

**Interfaces:**
- Consumes: the 8 files Task 5 created (`website/scottish-premiership/index.html`, its 6
  privacy locales, and its `support/index.html`) — Task 5 runs before this task and its
  files are already committed on this branch, so read them directly from the working tree
  rather than needing them pasted here.
- Every file in this task is built by reading its Task-5 counterpart and applying the exact
  substitution table below — no other wording changes.

**Substitution table (apply to every file in this task):**

| Find | Replace with |
|---|---|
| `Scottish Premiership 2026` | `La Liga 2026` |
| `#005EB8` | `#AA151B` (La Liga's primary accent per `ChampionshipConfig.laLiga`; the secondary gold `#F1BF00` is not used — matches how the app treats `accentColorHex` as the one representative brand color) |
| `/scottish-premiership/` (every occurrence, in every href/path) | `/la-liga/` |
| "the Scottish Premiership" / "del Scottish Premiership" / "du Scottish Premiership" / "do Scottish Premiership" (league-name references inside body paragraphs, in whichever locale's grammar applies) | "La Liga" / "de La Liga" (La Liga's own name doesn't take an article change across these languages — just swap the league name in place, keeping the surrounding sentence structure identical) |

- [ ] **Step 1: Create `website/la-liga/index.html`**

Read `website/scottish-premiership/index.html` and apply the substitution table. Additionally
replace the tagline and standings paragraph's league name exactly as: tagline → `Live scores,
fixtures, and the La Liga table — all in one place.`; standings paragraph → `The complete La
Liga table, updated after every match — with qualification and relegation zones marked
clearly.`

- [ ] **Step 2: Create `website/la-liga/privacy/en/index.html`**

Read `website/scottish-premiership/privacy/en/index.html` and apply the substitution table.

- [ ] **Step 3: Create `website/la-liga/privacy/en-gb/index.html`**

Read `website/scottish-premiership/privacy/en-gb/index.html` and apply the substitution table.

- [ ] **Step 4: Create `website/la-liga/privacy/fr/index.html`**

Read `website/scottish-premiership/privacy/fr/index.html` and apply the substitution table.

- [ ] **Step 5: Create `website/la-liga/privacy/pt-br/index.html`**

Read `website/scottish-premiership/privacy/pt-br/index.html` and apply the substitution table.

- [ ] **Step 6: Create `website/la-liga/privacy/pt-pt/index.html`**

Read `website/scottish-premiership/privacy/pt-pt/index.html` and apply the substitution table.

- [ ] **Step 7: Create `website/la-liga/privacy/es/index.html`**

Read `website/scottish-premiership/privacy/es/index.html` and apply the substitution table.

- [ ] **Step 8: Create `website/la-liga/support/index.html`**

Read `website/scottish-premiership/support/index.html` and apply the substitution table.

- [ ] **Step 9: Verify**

```bash
ls website/la-liga/privacy/   # expect: en en-gb fr pt-br pt-pt es
for f in website/la-liga/index.html website/la-liga/support/index.html website/la-liga/privacy/*/index.html; do
  python3 -c "import html.parser; html.parser.HTMLParser().feed(open('$f').read())" || echo "MALFORMED: $f"
done
grep -c "feature-block" website/la-liga/index.html  # expect 3
grep -rn "Scottish Premiership" website/la-liga/  # expect NO output — catches leftover copy-paste text
```

- [ ] **Step 10: Commit**

```bash
git add website/la-liga
git commit -m "Add La Liga's website section (landing page, privacy, support)"
```

---

### Task 7: Add the `es` privacy locale to the 4 existing apps

**Files:**
- Create: `website/brasileirao/privacy/es/index.html`
- Create: `website/premier-league/privacy/es/index.html`
- Create: `website/ligue-1/privacy/es/index.html`
- Create: `website/liga-portugal/privacy/es/index.html`
- Modify: all 20 existing privacy pages across these 4 apps (`en`, `en-gb`, `fr`, `pt-br`,
  `pt-pt` × 4 apps) — add one new `lang-switcher` link each.

**Interfaces:**
- Consumes: nothing new — this only touches the pre-existing `.privacy-page`/`.policy-card`/
  `.lang-switcher` classes, unchanged since before this plan.
- Depends on Task 3 having already moved Brasileirão's privacy folder to
  `website/brasileirao/privacy/` — run this task after Task 3.

- [ ] **Step 1: Create the 4 new `es/index.html` files**

Use Task 5 Step 7's Spanish template (`website/scottish-premiership/privacy/es/index.html`)
as the pattern. For each of the 4 apps below, create `website/{app}/privacy/es/index.html`
with: `<title>{App Name} — Política de Privacidad</title>`, `--accent: {app's accent hex}`,
all 6 `lang-switcher` hrefs pointed at `/{app}/privacy/...` with `aria-current="true"` on the
`es` link, body text `"la app {App Name}"` / `"clasificación de {competition}"`, back-link
`href="/{app}/"`.

| App folder | App Name (title/body) | Accent hex | Competition phrase |
|---|---|---|---|
| `brasileirao` | Brasileirão | `#ff4d5e` | "del Brasileirão" |
| `premier-league` | Premier League 2026 | `#3D195B` | "de la Premier League" |
| `ligue-1` | Ligue 1 2026 | `#FACC15` | "de la Ligue 1" |
| `liga-portugal` | Liga Portugal 2026 | `#00235A` | "de la Liga Portugal" |

Full text for `website/brasileirao/privacy/es/index.html` (the other 3 follow the identical
pattern with the table's substitutions applied):

```html
<!doctype html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Brasileirão — Política de Privacidad</title>
  <link rel="icon" type="image/png" href="/favicon.png">
  <link rel="stylesheet" href="/styles.css">
</head>
<body>
  <div class="stadium-background"></div>
  <div class="blob blob-accent"></div>
  <div class="blob blob-teal"></div>
  <main class="page privacy-page">
    <div class="content">
      <nav class="lang-switcher" aria-label="Idioma">
        <a href="/brasileirao/privacy/en/">English</a>
        <a href="/brasileirao/privacy/en-gb/">English (UK)</a>
        <a href="/brasileirao/privacy/fr/">Français</a>
        <a href="/brasileirao/privacy/pt-br/">Português (Brasil)</a>
        <a href="/brasileirao/privacy/pt-pt/">Português (Portugal)</a>
        <a href="/brasileirao/privacy/es/" aria-current="true">Español</a>
      </nav>
      <article class="policy-card">
        <h1>Política de Privacidad</h1>
        <p>Esta Política de Privacidad explica cómo la app Brasileirão ("la app") gestiona la información cuando la utilizas.</p>

        <h2>1. Información que recopilamos</h2>
        <p>Esta app no recopila, almacena ni comparte ningún dato personal. No requiere creación de cuenta, inicio de sesión ni datos personales. La app obtiene datos deportivos públicos — resultados, calendarios y clasificación del Brasileirão — de una API deportiva de terceros. Estos datos se almacenan en caché localmente en tu dispositivo para mejorar el rendimiento y no se transmiten a ningún otro lugar.</p>

        <h2>2. Análisis y seguimiento</h2>
        <p>Esta app utiliza Firebase Analytics y Firebase Crashlytics (ambos de Google) para entender cómo se usa la app y diagnosticar fallos. Firebase Analytics recopila datos de uso generales, como qué pantallas se visualizan y con qué frecuencia se abre la app; Firebase Crashlytics recopila informes de fallos, que pueden incluir el modelo del dispositivo, la versión del sistema operativo y el estado de la app en el momento del fallo. Ninguno de estos servicios se utiliza con fines publicitarios, ni recopila tu nombre, correo electrónico u otra información de identificación personal.</p>

        <h2>3. Servicios de terceros</h2>
        <p>Los datos de partidos, equipos y competición (incluidas las imágenes de los escudos de los equipos) se obtienen de una API deportiva de terceros. Esta app también utiliza Firebase (Google) para análisis e informes de fallos, como se describe anteriormente. Cargar datos desde estos servicios puede exponer la dirección IP de tu dispositivo, como es habitual en cualquier solicitud de red. No controlamos ni somos responsables de las prácticas de datos propias de estos servicios.</p>

        <h2>4. Datos almacenados en tu dispositivo</h2>
        <p>La app utiliza almacenamiento local para guardar en caché los datos de los partidos y así cargar más rápido. Estos datos permanecen en tu dispositivo y no se nos envían.</p>

        <h2>5. Privacidad de los menores</h2>
        <p>Esta app no está dirigida a menores y no recopila conscientemente información de menores.</p>

        <h2>6. Cambios en esta política</h2>
        <p>Podemos actualizar esta Política de Privacidad periódicamente. El uso continuado de la app después de los cambios constituye la aceptación de la política actualizada.</p>

        <h2>7. Contacto</h2>
        <p>Las preguntas sobre esta Política de Privacidad pueden dirigirse al contacto de soporte de la app que figura en su página de la App Store.</p>

        <a class="back-link" href="/brasileirao/">← Volver al inicio</a>
      </article>
    </div>
  </main>
</body>
</html>
```

For `premier-league`, `ligue-1`, and `liga-portugal`, read the
`website/brasileirao/privacy/es/index.html` file you just created above and write each of
the other 3 apps' `es/index.html` by applying exactly: the table's App Name/accent/
competition-phrase substitutions for that row, and every `/brasileirao/` path segment (all 7
occurrences: 6 nav hrefs + 1 back-link) replaced with the target app's own folder name
(`/premier-league/`, `/ligue-1/`, or `/liga-portugal/`). No other wording changes.

- [ ] **Step 2: Add the `es` link to the 20 existing privacy pages' `lang-switcher`**

Every existing privacy page's nav currently ends with the Portuguese (Portugal) link. Append
one line after it, site-wide, with this script:

```bash
for f in website/brasileirao/privacy/{en,en-gb,fr,pt-br,pt-pt}/index.html \
         website/premier-league/privacy/{en,en-gb,fr,pt-br,pt-pt}/index.html \
         website/ligue-1/privacy/{en,en-gb,fr,pt-br,pt-pt}/index.html \
         website/liga-portugal/privacy/{en,en-gb,fr,pt-br,pt-pt}/index.html; do
  app=$(echo "$f" | cut -d/ -f2)
  sed -i '' "s#\(<a href=\"/${app}/privacy/pt-pt/\"[^<]*</a>\)#\1\n        <a href=\"/${app}/privacy/es/\">Español</a>#" "$f"
done
```

- [ ] **Step 3: Verify**

```bash
ls website/brasileirao/privacy/ website/premier-league/privacy/ website/ligue-1/privacy/ website/liga-portugal/privacy/
# expect each to list: en en-gb fr pt-br pt-pt es

for f in website/{brasileirao,premier-league,ligue-1,liga-portugal}/privacy/*/index.html; do
  grep -q '"/.*\/privacy/es/"' "$f" || echo "MISSING es link: $f"
done
# expect no output — every one of the 24 files (20 existing + 4 new) must reference the es page

python3 -c "
import glob, html.parser
for f in glob.glob('website/**/privacy/**/index.html', recursive=True):
    html.parser.HTMLParser().feed(open(f).read())
"
```

- [ ] **Step 4: Commit**

```bash
git add website/brasileirao/privacy website/premier-league/privacy website/ligue-1/privacy website/liga-portugal/privacy
git commit -m "Add Spanish (es) privacy locale across all 4 existing apps"
```

---

### Task 8: Deploy and manual verification (controller-executed, not a subagent task)

This task is performed directly by the session controller after Tasks 1-7 are all reviewed
and merged — it involves a real deploy to the live `br26-80k.pages.dev` site, which the
controller should announce and get a final go-ahead for before running, consistent with how
this project's deploys have always been confirmed with the user first.

- [ ] **Step 1:** Deploy: `npx wrangler pages deploy website`
- [ ] **Step 2:** Open the live site and check, per the spec's Testing section: the hub page
  and all 6 per-app pages at mobile/tablet/desktop widths; every link (hub → league → privacy
  → support → back-link → language switcher → back to hub); the old
  `br26-80k.pages.dev/privacy/en/` and `br26-80k.pages.dev/support/` URLs 301 to their new
  `/brasileirao/...` locations; `prefers-reduced-motion: reduce` stops the live-chip pulse.
- [ ] **Step 3:** Report results back; fix and redeploy if anything's broken.

---

### Task 9: Update BR2026's App Store Connect URLs (controller-executed, confirm first)

Brasileirão's live `marketing_url`, `privacy_url`, and `support_url` fields in App Store
Connect currently point at the pre-move root-level paths. This is a live-metadata push
visible in App Store Connect — get explicit confirmation from the user immediately before
running the `deliver` push, per this project's established metadata-safety discipline (always
diff local against a fresh pull before pushing, since `release_notes` pushes the entire
metadata directory unconditionally).

- [ ] **Step 1:** Pull current live metadata to confirm nothing else has drifted since the
  last sync:
  ```bash
  bundle exec fastlane deliver download_metadata -a com.vibrito.br2026 \
    --metadata_path fastlane/metadata/br2026 \
    --api_key "$(cat fastlane/.asc_api_key.json)"
  git diff fastlane/metadata/br2026
  ```
  (Adjust the `--api_key` argument to however `asc_api_key` is actually sourced in this
  repo's Fastfile — check `fastlane/Fastfile`'s `asc_api_key` helper before running.) If
  anything unexpected shows up in the diff, stop and investigate before proceeding — don't
  overwrite unreviewed live drift.

- [ ] **Step 2:** Update the 4 locale directories with real content (`en-US`, `en-GB`,
  `pt-BR`, `pt-PT` — `fr` has no existing URL files for this app and stays untouched, a
  pre-existing gap unrelated to this task):

  | File | Old value | New value |
  |---|---|---|
  | `fastlane/metadata/br2026/en-US/marketing_url.txt` | `https://br26-80k.pages.dev/` | `https://br26-80k.pages.dev/brasileirao/` |
  | `fastlane/metadata/br2026/en-US/privacy_url.txt` | `https://br26-80k.pages.dev/privacy/en/` | `https://br26-80k.pages.dev/brasileirao/privacy/en/` |
  | `fastlane/metadata/br2026/en-US/support_url.txt` | `https://br26-80k.pages.dev/support/` | `https://br26-80k.pages.dev/brasileirao/support/` |
  | `fastlane/metadata/br2026/en-GB/marketing_url.txt` | `https://br26-80k.pages.dev/` | `https://br26-80k.pages.dev/brasileirao/` |
  | `fastlane/metadata/br2026/en-GB/privacy_url.txt` | `https://br26-80k.pages.dev/privacy/en-gb/` | `https://br26-80k.pages.dev/brasileirao/privacy/en-gb/` |
  | `fastlane/metadata/br2026/en-GB/support_url.txt` | `https://br26-80k.pages.dev/support/` | `https://br26-80k.pages.dev/brasileirao/support/` |
  | `fastlane/metadata/br2026/pt-BR/marketing_url.txt` | `https://br26-80k.pages.dev/` | `https://br26-80k.pages.dev/brasileirao/` |
  | `fastlane/metadata/br2026/pt-BR/privacy_url.txt` | `https://br26-80k.pages.dev/privacy/pt-br/` | `https://br26-80k.pages.dev/brasileirao/privacy/pt-br/` |
  | `fastlane/metadata/br2026/pt-BR/support_url.txt` | `https://br26-80k.pages.dev/support/` | `https://br26-80k.pages.dev/brasileirao/support/` |
  | `fastlane/metadata/br2026/pt-PT/marketing_url.txt` | `https://br26-80k.pages.dev/` | `https://br26-80k.pages.dev/brasileirao/` |
  | `fastlane/metadata/br2026/pt-PT/privacy_url.txt` | `https://br26-80k.pages.dev/privacy/pt-pt/` | `https://br26-80k.pages.dev/brasileirao/privacy/pt-pt/` |
  | `fastlane/metadata/br2026/pt-PT/support_url.txt` | `https://br26-80k.pages.dev/support/` | `https://br26-80k.pages.dev/brasileirao/support/` |

- [ ] **Step 3:** Confirm with the user, then push:
  ```bash
  bundle exec fastlane release_notes app:br2026
  ```

- [ ] **Step 4:** Verify the push landed with a second `download_metadata` pull and diff
  against what was just pushed.

- [ ] **Step 5:** Commit the 12 updated `.txt` files:
  ```bash
  git add fastlane/metadata/br2026
  git commit -m "Point BR2026's App Store Connect URLs at /brasileirao/ after the site move"
  ```
