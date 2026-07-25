# Website Broadcasts Row + Country Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a live "today's matches" section to the Brasileirão marketing page showing real fixtures with a broadcasts row naming where to watch each match, plus a country control, fed through a Cloudflare Pages Function that keeps the API key server-side.

**Architecture:** A strict allowlisted Pages Function proxy (`/api/matches`) attaches the `X-Auth-Token` header server-side and edge-caches for 60s. The browser fetches the whole competition (8.3 KB gzipped), then buckets matches by **local** calendar date, because "today" is a timezone-dependent concept the edge cannot answer correctly. Pure logic lives in a DOM-free module so it is unit-testable under `node --test`; the section starts `hidden` and reveals only on successful render, so every failure mode degrades to the page that exists today.

**Tech Stack:** Vanilla ES modules (no framework, no build step), Cloudflare Pages Functions, Node's built-in test runner (`node --test`, zero dependencies), `Intl.DateTimeFormat`/`Intl.DisplayNames`/`Intl.Locale` for all localization.

> **Suite command:** run `node --test tests/*.test.js`, not `node --test tests/`. Verified on
> Node v24.17.0 in this repo: the bare-directory form fails with a spurious `Cannot find
> module '.../tests'` and reports a phantom failing test named `tests`, while the glob form
> discovers and passes everything. Use the glob form everywhere.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-25-website-broadcasts-country-picker-design.md`
- Scope is `website/br2026/` **only**. Do not touch the other five landing pages.
- Do not modify or remove any existing CSS rule or the three decorative `.mock-*` blocks. Append only.
- No build step, no framework, no npm dependencies. No `package.json` is created.
- The API key must never appear in any file served to a browser, and never in a commit.
- Upstream base URL: `https://football-api-production-16d9.up.railway.app`
- Allowed competition codes: `BSA`, `PL`, `FL1`, `PPL`, `SPL`, `PD`
- Backend live statuses are `IN_PLAY` and `PAUSED` — **never** the literal `LIVE`. Unknown statuses are treated as scheduled.
- `broadcasts[].url` and `broadcasts[].logo` are null in all live data. Render text only; never emit an anchor or `<img>` for a broadcaster.
- Never send `country=` to the upstream API — it filters without falling back, returning empty for every country except `BR`.
- Build DOM with `createElement`/`textContent`, never `innerHTML` — team, venue, and broadcaster names are server-driven strings.
- Design tokens (match existing `styles.css` values exactly): card fill `rgba(255,255,255,0.07)`, border `0.5px solid rgba(255,255,255,0.16)`, shadow `0 8px 22px rgba(0,0,0,0.22)`, match-card radius `22px`, accent `var(--accent)`, numerics `font-variant-numeric: tabular-nums`.

### Two structural decisions that differ from the spec's file list

1. **Test files must never live inside `functions/`.** Cloudflare Pages maps every `.js` file in that tree to a public route, so `functions/api/matches.test.js` would ship as `/api/matches.test`. All tests live in `tests/` at the repo root.
2. **`matchday.js` is split in two.** `website/matchday-data.js` holds the pure logic with no DOM references so `node --test` can import it directly; `website/matchday.js` holds rendering and imports it. The spec described one file; splitting follows its own stated principle of one responsibility per unit.

### File structure

| File | Responsibility |
|---|---|
| `functions/api/matches.js` | NEW. Allowlisted proxy; attaches key, edge-caches, normalizes errors. |
| `website/matchday-data.js` | NEW. Pure: day bucketing, country extraction, listing order, status chips. No DOM. |
| `website/matchday.js` | NEW. DOM rendering, country control, `localStorage`, fetch orchestration. |
| `tests/matches-proxy.test.js` | NEW. Proxy behaviour incl. the allowlist security boundary. |
| `tests/matchday-data.test.js` | NEW. Pure-logic cases incl. the timezone boundary. |
| `website/br2026/index.html` | MODIFY. Insert `<section>` after the hero (after line 20), add module script. |
| `website/styles.css` | MODIFY. Append `.live-*` rules. |
| `.gitignore` | MODIFY. Add `.dev.vars`. |
| `.dev.vars` | NEW, gitignored. Local key for `wrangler pages dev`. |

---

### Task 1: Pages Function proxy

**Files:**
- Create: `functions/api/matches.js`
- Create: `tests/matches-proxy.test.js`
- Create: `.dev.vars`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: the HTTP route `GET /api/matches?code=<CODE>` returning the upstream JSON body verbatim on success (`{ "matches": [...] }`, each match carrying a `broadcasts` array). Error shape is `{ "error": "<slug>" }` with status 400/405/502. Task 4 consumes this route.

- [ ] **Step 1: Add `.dev.vars` to `.gitignore` before creating it**

Append to the `# Secrets` block in `.gitignore`, immediately after the `Secrets.xcconfig` line:

```
.dev.vars
```

- [ ] **Step 2: Create `.dev.vars` with the local key**

Copy the value from the gitignored `Secrets.xcconfig` at the repo root — never paste the
literal key into this plan, a commit message, or any tracked file:

```bash
printf 'FOOTBALL_API_KEY = %s\n' \
  "$(sed -n 's/^API_KEY = //p' Secrets.xcconfig)" > .dev.vars
```

Verify it captured a non-empty value without printing it:

```bash
test -s .dev.vars && grep -q '^FOOTBALL_API_KEY = .\{16,\}$' .dev.vars \
  && echo "key written ok" || echo "FAILED: check Secrets.xcconfig"
```

Then verify it is ignored — this must print nothing:

```bash
git status --porcelain .dev.vars
```

- [ ] **Step 3: Write the failing proxy tests**

Create `tests/matches-proxy.test.js`:

```js
import { test, afterEach } from "node:test";
import assert from "node:assert/strict";
import { onRequest } from "../functions/api/matches.js";

const KEY = "test-key";
const realFetch = globalThis.fetch;

afterEach(() => {
  globalThis.fetch = realFetch;
});

function ctx(url, { method = "GET", env = { FOOTBALL_API_KEY: KEY } } = {}) {
  return { request: new Request(url, { method }), env };
}

function stubFetch(handler) {
  const calls = [];
  globalThis.fetch = async (input, init) => {
    calls.push({ url: String(input), init });
    return handler(String(input), init);
  };
  return calls;
}

test("rejects a non-GET method", async () => {
  const res = await onRequest(ctx("https://site/api/matches?code=BSA", { method: "POST" }));
  assert.equal(res.status, 405);
});

test("rejects a competition code outside the allowlist", async () => {
  for (const code of ["EVIL", "bsa", "", "../secrets"]) {
    const res = await onRequest(ctx(`https://site/api/matches?code=${encodeURIComponent(code)}`));
    assert.equal(res.status, 400, `code=${code} should be rejected`);
    assert.deepEqual(await res.json(), { error: "unknown_competition" });
  }
});

test("rejects a missing code parameter", async () => {
  const res = await onRequest(ctx("https://site/api/matches"));
  assert.equal(res.status, 400);
});

test("returns 502 when the key is not configured", async () => {
  const res = await onRequest(ctx("https://site/api/matches?code=BSA", { env: {} }));
  assert.equal(res.status, 502);
});

test("forwards the key and include=broadcasts, and returns the upstream body", async () => {
  const payload = JSON.stringify({ matches: [{ id: 1, broadcasts: [] }] });
  const calls = stubFetch(() => new Response(payload, { status: 200 }));

  const res = await onRequest(ctx("https://site/api/matches?code=BSA"));

  assert.equal(res.status, 200);
  assert.equal(await res.text(), payload);
  assert.match(res.headers.get("Cache-Control"), /max-age=60/);
  assert.equal(calls.length, 1);
  assert.equal(
    calls[0].url,
    "https://football-api-production-16d9.up.railway.app/v4/competitions/BSA/matches?include=broadcasts",
  );
  assert.equal(calls[0].init.headers["X-Auth-Token"], KEY);
  assert.equal(calls[0].init.cf.cacheTtl, 60);
});

test("never sends a country parameter upstream", async () => {
  const calls = stubFetch(() => new Response("{}", { status: 200 }));
  await onRequest(ctx("https://site/api/matches?code=BSA&country=US"));
  assert.ok(!calls[0].url.includes("country"));
});

test("collapses an upstream error to 502 without forwarding its body", async () => {
  stubFetch(() => new Response("upstream says: bad token abc123", { status: 403 }));
  const res = await onRequest(ctx("https://site/api/matches?code=BSA"));
  assert.equal(res.status, 502);
  const body = await res.text();
  assert.ok(!body.includes("abc123"));
});

test("collapses a network throw to 502", async () => {
  stubFetch(() => {
    throw new Error("boom");
  });
  const res = await onRequest(ctx("https://site/api/matches?code=BSA"));
  assert.equal(res.status, 502);
});
```

- [ ] **Step 4: Run the tests to verify they fail**

```bash
node --test tests/matches-proxy.test.js
```

Expected: FAIL — `Cannot find module .../functions/api/matches.js`

- [ ] **Step 5: Implement the proxy**

Create `functions/api/matches.js`:

```js
const UPSTREAM = "https://football-api-production-16d9.up.railway.app";

// The security boundary. Without this allowlist the endpoint is an open relay
// that anyone can point at arbitrary upstream paths using our paid API key.
const ALLOWED_CODES = ["BSA", "PL", "FL1", "PPL", "SPL", "PD"];

export async function onRequest(context) {
  const { request, env } = context;

  if (request.method !== "GET") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const code = new URL(request.url).searchParams.get("code");
  if (!ALLOWED_CODES.includes(code)) {
    return json({ error: "unknown_competition" }, 400);
  }

  if (!env.FOOTBALL_API_KEY) {
    return json({ error: "upstream_unavailable" }, 502);
  }

  // `include=broadcasts` is undocumented and unvalidated upstream: a typo returns
  // 200 with the key silently absent. `country=` is deliberately never sent — it
  // filters without falling back, so anything but BR comes back empty.
  const url = `${UPSTREAM}/v4/competitions/${code}/matches?include=broadcasts`;

  let upstream;
  try {
    upstream = await fetch(url, {
      headers: { "X-Auth-Token": env.FOOTBALL_API_KEY },
      cf: { cacheTtl: 60, cacheEverything: true },
    });
  } catch {
    return json({ error: "upstream_unavailable" }, 502);
  }

  if (!upstream.ok) {
    // Never forward the upstream body — it can echo key-related detail.
    return json({ error: "upstream_unavailable" }, 502);
  }

  return new Response(await upstream.text(), {
    status: 200,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "public, max-age=60",
    },
  });
}

function json(body, status) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
}
```

- [ ] **Step 6: Run the tests to verify they pass**

```bash
node --test tests/matches-proxy.test.js
```

Expected: PASS — 8 tests

- [ ] **Step 7: Commit**

```bash
git add .gitignore functions/api/matches.js tests/matches-proxy.test.js
git commit -m "Add allowlisted Pages Function proxy for match data

Keeps X-Auth-Token server-side so the marketing site can show live
fixtures without publishing the API key. The competition-code allowlist
is the security boundary: without it the route is an open relay."
```

Confirm `.dev.vars` is absent from the commit:

```bash
git show --stat --name-only HEAD
```

---

### Task 2: Pure data module

**Files:**
- Create: `website/matchday-data.js`
- Create: `tests/matchday-data.test.js`

**Interfaces:**
- Consumes: the match JSON shape returned by Task 1's route.
- Produces, all imported by Task 4:
  - `localDateKey(date: Date, timeZone?: string): string` — `"YYYY-MM-DD"`
  - `selectMatchday(matches: object[], now: Date, timeZone?: string): { dateKey: string, isToday: boolean, matches: object[] } | null`
  - `dayTitleKind(dateKey: string, now: Date, timeZone?: string): "today" | "tomorrow" | "later"`
  - `countriesFrom(matches: object[]): string[]`
  - `sortCountries(codes: string[], displayName: (code: string) => string): string[]`
  - `listingsFor(match: object, country: string): object[]`
  - `statusChip(match: object): { kind: "live" | "muted", text: string } | null`
  - `hasScore(match: object): boolean`

- [ ] **Step 1: Write the failing data tests**

Create `tests/matchday-data.test.js`:

```js
import { test } from "node:test";
import assert from "node:assert/strict";
import {
  localDateKey,
  selectMatchday,
  dayTitleKind,
  countriesFrom,
  sortCountries,
  listingsFor,
  statusChip,
  hasScore,
} from "../website/matchday-data.js";

const SP = "America/Sao_Paulo";
const LISBON = "Europe/Lisbon";

function match(id, utcDate, extra = {}) {
  return { id, utcDate, status: "SCHEDULED", broadcasts: [], ...extra };
}

test("localDateKey formats as YYYY-MM-DD in the given zone", () => {
  const d = new Date("2026-07-25T23:30:00Z");
  assert.equal(localDateKey(d, SP), "2026-07-25");
  assert.equal(localDateKey(d, LISBON), "2026-07-26");
});

test("a 23:30 UTC kickoff buckets to different local days either side of UTC", () => {
  const matches = [match(1, "2026-07-25T23:30:00Z")];
  const now = new Date("2026-07-25T12:00:00Z");

  const inSaoPaulo = selectMatchday(matches, now, SP);
  assert.equal(inSaoPaulo.dateKey, "2026-07-25");
  assert.equal(inSaoPaulo.isToday, true);

  const inLisbon = selectMatchday(matches, now, LISBON);
  assert.equal(inLisbon.dateKey, "2026-07-26");
  assert.equal(inLisbon.isToday, false);
});

test("selects today when today has matches", () => {
  const matches = [
    match(1, "2026-07-25T21:30:00Z"),
    match(2, "2026-07-29T22:00:00Z"),
  ];
  const result = selectMatchday(matches, new Date("2026-07-25T12:00:00Z"), SP);
  assert.equal(result.dateKey, "2026-07-25");
  assert.equal(result.isToday, true);
  assert.deepEqual(result.matches.map((m) => m.id), [1]);
});

test("selects the earliest future day when today is empty", () => {
  const matches = [
    match(1, "2026-08-07T22:00:00Z"),
    match(2, "2026-08-14T22:00:00Z"),
  ];
  const result = selectMatchday(matches, new Date("2026-08-01T12:00:00Z"), SP);
  assert.equal(result.dateKey, "2026-08-07");
  assert.equal(result.isToday, false);
});

test("still selects today when every match today has finished", () => {
  const matches = [
    match(1, "2026-07-25T14:00:00Z", { status: "FINISHED" }),
    match(2, "2026-07-29T22:00:00Z"),
  ];
  const result = selectMatchday(matches, new Date("2026-07-25T23:00:00Z"), SP);
  assert.equal(result.dateKey, "2026-07-25");
});

test("ignores postponed matches", () => {
  const matches = [
    match(1, "2026-07-25T21:30:00Z", { status: "POSTPONED" }),
    match(2, "2026-07-29T22:00:00Z"),
  ];
  const result = selectMatchday(matches, new Date("2026-07-25T12:00:00Z"), SP);
  assert.equal(result.dateKey, "2026-07-29");
});

test("returns null when nothing qualifies", () => {
  assert.equal(selectMatchday([], new Date("2026-07-25T12:00:00Z"), SP), null);
  const allPast = [match(1, "2026-01-01T12:00:00Z")];
  assert.equal(selectMatchday(allPast, new Date("2026-07-25T12:00:00Z"), SP), null);
  const allPostponed = [match(1, "2026-08-01T12:00:00Z", { status: "POSTPONED" })];
  assert.equal(selectMatchday(allPostponed, new Date("2026-07-25T12:00:00Z"), SP), null);
});

test("orders the selected day by kickoff time", () => {
  const matches = [
    match(1, "2026-07-25T23:30:00Z"),
    match(2, "2026-07-25T21:30:00Z"),
  ];
  const result = selectMatchday(matches, new Date("2026-07-25T12:00:00Z"), SP);
  assert.deepEqual(result.matches.map((m) => m.id), [2, 1]);
});

test("skips matches with an unparseable date", () => {
  const matches = [match(1, "not-a-date"), match(2, "2026-07-29T22:00:00Z")];
  const result = selectMatchday(matches, new Date("2026-07-25T12:00:00Z"), SP);
  assert.deepEqual(result.matches.map((m) => m.id), [2]);
});

test("dayTitleKind distinguishes today, tomorrow and later", () => {
  const now = new Date("2026-07-25T12:00:00Z");
  assert.equal(dayTitleKind("2026-07-25", now, SP), "today");
  assert.equal(dayTitleKind("2026-07-26", now, SP), "tomorrow");
  assert.equal(dayTitleKind("2026-08-07", now, SP), "later");
});

test("countriesFrom dedupes across matches and tolerates missing broadcasts", () => {
  const matches = [
    { broadcasts: [{ country: "BR" }, { country: "BR" }] },
    { broadcasts: [{ country: "US" }] },
    { broadcasts: [] },
    {},
  ];
  assert.deepEqual(countriesFrom(matches).sort(), ["BR", "US"]);
});

test("sortCountries orders by display name, not by code", () => {
  const names = { BR: "Brazil", US: "United States", AR: "Argentina" };
  const sorted = sortCountries(["US", "BR", "AR"], (c) => names[c]);
  assert.deepEqual(sorted, ["AR", "BR", "US"]);
});

test("listingsFor filters by country and puts free-to-air first", () => {
  const m = {
    broadcasts: [
      { name: "Premiere", type: "PPV", country: "BR" },
      { name: "GE TV", type: "STREAMING", country: "BR" },
      { name: "Globo", type: "FREE_TV", country: "BR" },
      { name: "SporTV", type: "PAY_TV", country: "BR" },
      { name: "ESPN+", type: "STREAMING", country: "US" },
    ],
  };
  assert.deepEqual(
    listingsFor(m, "BR").map((b) => b.name),
    ["Globo", "SporTV", "GE TV", "Premiere"],
  );
  assert.deepEqual(listingsFor(m, "US").map((b) => b.name), ["ESPN+"]);
  assert.deepEqual(listingsFor(m, "PT"), []);
  assert.deepEqual(listingsFor({}, "BR"), []);
});

test("listingsFor puts an unknown type last rather than dropping it", () => {
  const m = {
    broadcasts: [
      { name: "Mystery", type: "RADIO", country: "BR" },
      { name: "Globo", type: "FREE_TV", country: "BR" },
    ],
  };
  assert.deepEqual(listingsFor(m, "BR").map((b) => b.name), ["Globo", "Mystery"]);
});

test("statusChip maps the real backend statuses", () => {
  assert.deepEqual(statusChip({ status: "IN_PLAY", minute: 67 }), { kind: "live", text: "LIVE 67'" });
  assert.deepEqual(statusChip({ status: "IN_PLAY" }), { kind: "live", text: "LIVE" });
  assert.deepEqual(statusChip({ status: "PAUSED" }), { kind: "live", text: "HT" });
  assert.deepEqual(statusChip({ status: "FINISHED" }), { kind: "muted", text: "FT" });
  assert.equal(statusChip({ status: "SCHEDULED" }), null);
  assert.equal(statusChip({ status: "TIMED" }), null);
  assert.equal(statusChip({ status: "LIVE" }), null, "backend never sends the literal LIVE");
});

test("hasScore is true only once a match has started", () => {
  assert.equal(hasScore({ status: "IN_PLAY" }), true);
  assert.equal(hasScore({ status: "PAUSED" }), true);
  assert.equal(hasScore({ status: "FINISHED" }), true);
  assert.equal(hasScore({ status: "SCHEDULED" }), false);
});
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
node --test tests/matchday-data.test.js
```

Expected: FAIL — `Cannot find module .../website/matchday-data.js`

- [ ] **Step 3: Implement the data module**

Create `website/matchday-data.js`:

```js
// Pure logic for the live matchday section. No DOM references — this module is
// imported directly by `node --test`, so anything touching `document` belongs in
// matchday.js instead.

// Free-to-air first, so the cheapest way to watch reads first.
const TYPE_ORDER = ["FREE_TV", "PAY_TV", "STREAMING", "PPV"];

const STARTED_STATUSES = ["IN_PLAY", "PAUSED", "FINISHED"];

/**
 * Local calendar date as "YYYY-MM-DD". `en-CA` is the shortest route to an
 * ISO-shaped date; passing an explicit `timeZone` is what makes the
 * timezone-boundary behaviour testable without mutating process.env.TZ.
 */
export function localDateKey(date, timeZone) {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(date);
}

/**
 * Pick the day to show: today when it has any matches at all (finished ones
 * included — final scores on the current day are useful), otherwise the
 * earliest future day. Returns null when nothing qualifies.
 *
 * Bucketing happens in the *visitor's* timezone by design: a 23:30 UTC kickoff
 * is still "today" in São Paulo but already "tomorrow" in Lisbon, and an edge
 * function deciding this in UTC would disagree with the visitor's own calendar
 * for part of every day.
 */
export function selectMatchday(matches, now, timeZone) {
  const todayKey = localDateKey(now, timeZone);
  const buckets = new Map();

  for (const match of matches) {
    if (match.status === "POSTPONED") continue;
    const kickoff = new Date(match.utcDate);
    if (Number.isNaN(kickoff.getTime())) continue;

    const key = localDateKey(kickoff, timeZone);
    if (key < todayKey) continue;

    if (!buckets.has(key)) buckets.set(key, []);
    buckets.get(key).push(match);
  }

  if (buckets.size === 0) return null;

  const dateKey = [...buckets.keys()].sort()[0];
  const dayMatches = buckets
    .get(dateKey)
    .slice()
    .sort((a, b) => new Date(a.utcDate) - new Date(b.utcDate));

  return { dateKey, isToday: dateKey === todayKey, matches: dayMatches };
}

export function dayTitleKind(dateKey, now, timeZone) {
  if (dateKey === localDateKey(now, timeZone)) return "today";
  const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);
  if (dateKey === localDateKey(tomorrow, timeZone)) return "tomorrow";
  return "later";
}

export function countriesFrom(matches) {
  const codes = new Set();
  for (const match of matches) {
    for (const listing of match.broadcasts ?? []) {
      if (listing.country) codes.add(listing.country);
    }
  }
  return [...codes];
}

export function sortCountries(codes, displayName) {
  return codes.slice().sort((a, b) => displayName(a).localeCompare(displayName(b)));
}

export function listingsFor(match, country) {
  const rank = (type) => {
    const index = TYPE_ORDER.indexOf(type);
    return index === -1 ? TYPE_ORDER.length : index;
  };
  return (match.broadcasts ?? [])
    .filter((listing) => listing.country === country)
    .sort((a, b) => rank(a.type) - rank(b.type));
}

/**
 * The backend sends IN_PLAY and PAUSED, never the literal "LIVE" — the same
 * naming gotcha MatchStatus.swift handles on the app side. Anything unknown
 * falls through to null and is treated as not-yet-started.
 */
export function statusChip(match) {
  switch (match.status) {
    case "IN_PLAY":
      return { kind: "live", text: match.minute != null ? `LIVE ${match.minute}'` : "LIVE" };
    case "PAUSED":
      return { kind: "live", text: "HT" };
    case "FINISHED":
      return { kind: "muted", text: "FT" };
    default:
      return null;
  }
}

export function hasScore(match) {
  return STARTED_STATUSES.includes(match.status);
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
node --test tests/matchday-data.test.js
```

Expected: PASS — 16 tests

- [ ] **Step 5: Run the whole suite**

```bash
node --test tests/*.test.js
```

Expected: PASS — 24 tests total (8 proxy + 16 data)

- [ ] **Step 6: Commit**

```bash
git add website/matchday-data.js tests/matchday-data.test.js
git commit -m "Add pure matchday selection and broadcast helpers

Buckets matches by the visitor's local calendar date rather than UTC, so
a 23:30Z kickoff reads as today in Sao Paulo and tomorrow in Lisbon.
Kept DOM-free so node --test can import it with no runner or deps."
```

---

### Task 3: Section markup and styles

**Files:**
- Modify: `website/br2026/index.html` (insert after line 20, the `</div>` closing `.hero`)
- Modify: `website/styles.css` (append)

**Interfaces:**
- Consumes: nothing at runtime — this is the static shell.
- Produces the DOM contract Task 4 renders into. Task 4 depends on these exact hooks:
  - `section.live-matchday[data-code]` — the root, ships with `hidden`
  - `.live-eyebrow`, `.live-title`, `.live-country`, `.live-cards` — the four fill targets

- [ ] **Step 1: Insert the section markup**

In `website/br2026/index.html`, between the closing `</div>` of `.hero` (line 20) and the first `<div class="feature-block">` (line 22), insert:

```html
      <section class="live-matchday" data-code="BSA" aria-labelledby="live-matchday-title" hidden>
        <p class="live-eyebrow"></p>
        <div class="live-header">
          <h2 class="live-title" id="live-matchday-title"></h2>
          <div class="live-country"></div>
        </div>
        <div class="live-cards"></div>
      </section>
```

The `hidden` attribute is deliberate and load-bearing: the section is revealed only after a successful render, so a dead API, a missing key, or disabled JavaScript all leave the page exactly as it ships today.

- [ ] **Step 2: Add the module script before `</body>`**

Replace the closing `</main>\n</body>` in `website/br2026/index.html` with:

```html
  </main>
  <script type="module" src="/matchday.js"></script>
</body>
```

`type="module"` defers by default, so no `defer` attribute is needed.

- [ ] **Step 3: Append the styles**

Append to `website/styles.css`:

```css
/* ---- Live matchday section (br2026 only) ---- */

.live-matchday {
  width: 100%;
  margin: 8px 0 48px;
}

.live-matchday[hidden] {
  display: none;
}

.live-eyebrow {
  margin: 0 0 4px;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  color: rgba(255, 255, 255, 0.5);
}

.live-header {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 12px;
  margin-bottom: 20px;
}

.live-title {
  margin: 0;
  font-size: 32px;
  font-weight: 800;
  letter-spacing: -0.5px;
  line-height: 1.1;
}

.live-country-pill,
.live-country select {
  font: inherit;
  font-size: 13px;
  font-weight: 600;
  color: #ffffff;
  background: rgba(255, 255, 255, 0.07);
  border: 0.5px solid rgba(255, 255, 255, 0.16);
  border-radius: 15px;
  padding: 8px 14px;
}

.live-country select {
  appearance: none;
  padding-right: 30px;
  background-image: linear-gradient(45deg, transparent 50%, rgba(255, 255, 255, 0.6) 50%),
    linear-gradient(135deg, rgba(255, 255, 255, 0.6) 50%, transparent 50%);
  background-position: right 14px center, right 9px center;
  background-size: 5px 5px, 5px 5px;
  background-repeat: no-repeat;
}

/* The native dropdown list is OS-rendered, so its options need a dark-on-light
   pairing that survives outside our glass surface. */
.live-country select option {
  color: #061325;
  background: #ffffff;
}

.live-cards {
  display: grid;
  gap: 12px;
}

.live-card {
  display: grid;
  grid-template-columns: 1fr auto 1fr;
  align-items: center;
  gap: 12px;
  background: rgba(255, 255, 255, 0.07);
  border: 0.5px solid rgba(255, 255, 255, 0.16);
  border-radius: 22px;
  box-shadow: 0 8px 22px rgba(0, 0, 0, 0.22);
  padding: 18px 20px;
}

.live-card--finished {
  background: rgba(255, 255, 255, 0.05);
}

.live-team {
  display: flex;
  align-items: center;
  gap: 10px;
  min-width: 0;
}

.live-team--away {
  flex-direction: row-reverse;
}

.live-team-name {
  font-size: 15px;
  font-weight: 600;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.live-crest {
  width: 28px;
  height: 28px;
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.05);
  font-size: 10px;
  font-weight: 700;
  color: rgba(255, 255, 255, 0.7);
}

.live-crest img {
  width: 28px;
  height: 28px;
  object-fit: contain;
}

.live-center {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  min-width: 74px;
}

.live-score,
.live-kickoff {
  font-variant-numeric: tabular-nums;
}

.live-score {
  font-size: 19px;
  font-weight: 800;
}

.live-kickoff {
  font-size: 15px;
  font-weight: 700;
  color: rgba(255, 255, 255, 0.65);
}

.live-chip {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.3px;
  text-transform: uppercase;
  border-radius: 13px;
  padding: 3px 9px;
}

.live-chip--live {
  color: var(--accent);
  background: color-mix(in srgb, var(--accent) 18%, transparent);
  border: 1px solid color-mix(in srgb, var(--accent) 45%, transparent);
}

.live-chip--muted {
  color: rgba(255, 255, 255, 0.55);
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid rgba(255, 255, 255, 0.16);
}

.live-broadcasts {
  grid-column: 1 / -1;
  display: flex;
  align-items: baseline;
  gap: 8px;
  margin-top: 4px;
  padding-top: 12px;
  border-top: 0.5px solid rgba(255, 255, 255, 0.16);
  font-size: 12px;
  font-weight: 600;
  color: rgba(255, 255, 255, 0.7);
}

.live-broadcasts--empty {
  color: rgba(255, 255, 255, 0.4);
  font-weight: 500;
}

@media (max-width: 520px) {
  .live-card {
    padding: 16px;
  }

  .live-title {
    font-size: 26px;
  }
}
```

- [ ] **Step 4: Verify the page is visually unchanged**

```bash
npx wrangler pages dev
```

Open `http://localhost:8788/br2026/`. Expected: the page looks exactly as before — the new section is `hidden` and no script has been written yet, so nothing renders. Confirm no console errors other than a 404 for `/matchday.js`.

- [ ] **Step 5: Commit**

```bash
git add website/br2026/index.html website/styles.css
git commit -m "Add live matchday section shell and styles to br2026 page

Section ships hidden and is revealed only on a successful render, so any
failure degrades to the page as it stands today. Styles reuse the
existing glass tokens; nothing existing is modified."
```

---

### Task 4: Rendering and country control

**Files:**
- Create: `website/matchday.js`

**Interfaces:**
- Consumes: `GET /api/matches?code=<CODE>` from Task 1; every export of `website/matchday-data.js` from Task 2; the DOM hooks from Task 3.
- Produces: the rendered section. No exports — this is the entry point.

- [ ] **Step 1: Write the renderer**

Create `website/matchday.js`:

```js
import {
  selectMatchday,
  dayTitleKind,
  countriesFrom,
  sortCountries,
  listingsFor,
  statusChip,
  hasScore,
} from "./matchday-data.js";

const STORAGE_KEY = "br26.broadcastCountry";

const root = document.querySelector(".live-matchday");
if (root) {
  start(root).catch((error) => {
    // A marketing page must never surface a data error to the visitor; the
    // section simply stays hidden and the page reads as it always has.
    console.warn("[matchday] section not rendered:", error);
  });
}

async function start(section) {
  const code = section.dataset.code;
  if (!code) throw new Error("missing data-code");

  const response = await fetch(`/api/matches?code=${encodeURIComponent(code)}`);
  if (!response.ok) throw new Error(`proxy returned ${response.status}`);

  const payload = await response.json();
  const day = selectMatchday(payload.matches ?? [], new Date());
  if (!day || day.matches.length === 0) throw new Error("no matchday to show");

  renderHeader(section, day);

  const countries = sortCountries(countriesFrom(day.matches), displayCountry);
  let selected = initialCountry(countries);

  renderCountryControl(section, countries, selected, (next) => {
    selected = next;
    persistCountry(next);
    renderCards(section, day.matches, selected, countries.length > 0);
  });

  renderCards(section, day.matches, selected, countries.length > 0);
  section.hidden = false;
}

/* ---- header ---- */

function renderHeader(section, day) {
  // Noon avoids any DST edge when turning a date key back into a Date.
  const date = new Date(`${day.dateKey}T12:00:00`);
  const weekdayShort = new Intl.DateTimeFormat(undefined, { weekday: "short" }).format(date);
  const dayMonth = new Intl.DateTimeFormat(undefined, { day: "numeric", month: "short" }).format(date);

  section.querySelector(".live-eyebrow").textContent =
    `${weekdayShort} · ${dayMonth}`.toUpperCase();

  const kind = dayTitleKind(day.dateKey, new Date());
  const titles = {
    today: "Today",
    tomorrow: "Tomorrow",
    later: new Intl.DateTimeFormat(undefined, { weekday: "long" }).format(date),
  };
  section.querySelector(".live-title").textContent = titles[kind];
}

/* ---- country control ---- */

function displayCountry(code) {
  try {
    return new Intl.DisplayNames(undefined, { type: "region" }).of(code) ?? code;
  } catch {
    return code;
  }
}

function initialCountry(countries) {
  if (countries.length === 0) return null;

  const stored = readStoredCountry();
  if (stored && countries.includes(stored)) return stored;

  try {
    const region = new Intl.Locale(navigator.language).region;
    if (region && countries.includes(region)) return region;
  } catch {
    // Unparseable navigator.language — fall through to the first entry.
  }
  return countries[0];
}

function readStoredCountry() {
  try {
    return localStorage.getItem(STORAGE_KEY);
  } catch {
    return null; // Private mode / storage disabled.
  }
}

function persistCountry(code) {
  try {
    localStorage.setItem(STORAGE_KEY, code);
  } catch {
    // Non-fatal: the choice just won't survive a reload.
  }
}

function renderCountryControl(section, countries, selected, onChange) {
  const host = section.querySelector(".live-country");
  host.replaceChildren();

  // A dropdown holding one option is a dead control, so a single country
  // renders as a static label instead. Today this is always the case.
  if (countries.length === 0) return;

  if (countries.length === 1) {
    const pill = document.createElement("span");
    pill.className = "live-country-pill";
    pill.textContent = `📺 ${displayCountry(countries[0])}`;
    host.appendChild(pill);
    return;
  }

  const select = document.createElement("select");
  select.setAttribute("aria-label", "Broadcast country");
  for (const code of countries) {
    const option = document.createElement("option");
    option.value = code;
    option.textContent = displayCountry(code);
    option.selected = code === selected;
    select.appendChild(option);
  }
  select.addEventListener("change", () => onChange(select.value));
  host.appendChild(select);
}

/* ---- cards ---- */

function renderCards(section, matches, country, anyCountries) {
  const host = section.querySelector(".live-cards");
  host.replaceChildren(...matches.map((match) => cardEl(match, country, anyCountries)));
}

function cardEl(match, country, anyCountries) {
  const card = document.createElement("article");
  card.className = "live-card";
  if (match.status === "FINISHED") card.classList.add("live-card--finished");

  card.append(
    teamEl(match.homeTeam, "home"),
    centerEl(match),
    teamEl(match.awayTeam, "away"),
  );

  if (anyCountries && country) {
    card.appendChild(broadcastsEl(match, country));
  }
  return card;
}

function teamEl(team, side) {
  const wrap = document.createElement("div");
  wrap.className = `live-team live-team--${side}`;

  const name = document.createElement("span");
  name.className = "live-team-name";
  name.textContent = team?.shortName || team?.name || "—";

  wrap.append(crestEl(team), name);
  return wrap;
}

function crestEl(team) {
  const badge = document.createElement("span");
  badge.className = "live-crest";

  const initials = (team?.shortName || team?.name || "?").slice(0, 3).toUpperCase();
  badge.textContent = initials;

  if (team?.crest) {
    const img = document.createElement("img");
    img.src = team.crest;
    img.alt = "";
    img.loading = "lazy";
    img.width = 28;
    img.height = 28;
    // Swap the initials out only once the crest has actually decoded, so a
    // failed or slow load leaves the placeholder in place with no flicker.
    img.addEventListener("load", () => badge.replaceChildren(img));
  }
  return badge;
}

function centerEl(match) {
  const center = document.createElement("div");
  center.className = "live-center";

  if (hasScore(match)) {
    const score = document.createElement("span");
    score.className = "live-score";
    const home = match.score?.fullTime?.home ?? 0;
    const away = match.score?.fullTime?.away ?? 0;
    score.textContent = `${home} – ${away}`;
    center.appendChild(score);
  } else {
    const kickoff = document.createElement("span");
    kickoff.className = "live-kickoff";
    kickoff.textContent = new Date(match.utcDate).toLocaleTimeString(undefined, {
      hour: "2-digit",
      minute: "2-digit",
    });
    center.appendChild(kickoff);
  }

  const chip = statusChip(match);
  if (chip) {
    const el = document.createElement("span");
    el.className = `live-chip live-chip--${chip.kind}`;
    el.textContent = chip.text;
    center.appendChild(el);
  }
  return center;
}

function broadcastsEl(match, country) {
  const row = document.createElement("div");
  row.className = "live-broadcasts";

  const icon = document.createElement("span");
  icon.setAttribute("aria-hidden", "true");
  icon.textContent = "📺";

  const names = document.createElement("span");
  const listings = listingsFor(match, country);

  if (listings.length === 0) {
    row.classList.add("live-broadcasts--empty");
    names.textContent = "No listings";
  } else {
    // Text only: url and logo are null in all live data, so there is nothing
    // to link to and no logo asset to render.
    names.textContent = listings.map((listing) => listing.name).join(" · ");
  }

  row.append(icon, names);
  return row;
}
```

- [ ] **Step 2: Verify the full test suite still passes**

```bash
node --test tests/*.test.js
```

Expected: PASS — 24 tests (this task adds no tests; `matchday.js` is DOM glue whose logic lives in the tested module. The "empty broadcasts renders No listings" case the spec lists is covered at the data layer by `listingsFor({}, "BR") === []`, which drives that branch; the DOM half is covered by manual verification in Step 3.)

- [ ] **Step 3: Verify against the live API**

```bash
npx wrangler pages dev
```

Open `http://localhost:8788/br2026/` and confirm:
- the section appears between the hero and the first feature block
- the eyebrow/title match the real next matchday
- each card shows crests, names, and a kickoff time or score
- the broadcasts row names real broadcasters, free-to-air first
- the country control is a **static `📺 Brazil` pill**, not a dropdown, because BR is the only country in the data

- [ ] **Step 4: Verify graceful degradation**

Temporarily break the key in `.dev.vars` (change one character), restart `wrangler pages dev`, and reload. Expected: the section does not appear, the page is identical to production, and the console shows one `[matchday]` warning. Restore the key afterwards.

- [ ] **Step 5: Commit**

```bash
git add website/matchday.js
git commit -m "Render live matchday cards with broadcasts row and country control

Single country renders a static pill rather than a one-option dropdown.
Crests swap in only on successful decode so the initials placeholder
never flickers. All DOM built via textContent — team and broadcaster
names are server-driven strings."
```

---

### Task 5: End-to-end verification and documentation

**Files:**
- Modify: `CLAUDE.md` (Backend API section)

**Interfaces:**
- Consumes: everything from Tasks 1–4.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Confirm no secret is tracked**

```bash
git status --porcelain .dev.vars
KEY="$(sed -n 's/^API_KEY = //p' Secrets.xcconfig)"
git log --all --oneline -S "$KEY" -- . ':!Secrets.xcconfig'
unset KEY
```

Expected: both commands print nothing. Read the key from `Secrets.xcconfig` into a shell
variable rather than typing it — a literal here would be committed with this plan, which is
exactly the leak the check exists to catch. If the second command prints a commit, stop and
report it: an unpushed commit can be rewritten, but anything already pushed needs the key
rotated instead.

Then confirm nothing served to a browser mentions the key:

```bash
grep -rn "X-Auth-Token\|FOOTBALL_API_KEY" website/ || echo "clean: no key reference under website/"
```

Expected: `clean: no key reference under website/` — the header belongs only in `functions/`.

- [ ] **Step 2: Verify the allowlist rejects an arbitrary code against the running server**

With `npx wrangler pages dev` running:

```bash
curl -s -o /dev/null -w "%{http_code}\n" "http://localhost:8788/api/matches?code=BSA"
curl -s -o /dev/null -w "%{http_code}\n" "http://localhost:8788/api/matches?code=EVIL"
curl -s -o /dev/null -w "%{http_code}\n" -X POST "http://localhost:8788/api/matches?code=BSA"
```

Expected: `200`, `400`, `405`.

- [ ] **Step 3: Verify the other five pages are untouched**

```bash
git diff --stat HEAD~4 -- website/
```

Expected: only `website/br2026/index.html`, `website/styles.css`, plus the two new `website/*.js` files. No `premier-league/`, `ligue-1/`, `liga-portugal/`, `sp2026/`, or `la-liga/` paths.

- [ ] **Step 4: Document the undocumented parameter in CLAUDE.md**

In the **Backend API** section of `CLAUDE.md`, after the existing
`GET /v4/competitions/{code}/matches` bullet, add:

```markdown
- `GET /v4/competitions/{code}/matches?include=broadcasts` — adds a `broadcasts` array
  (`name`/`type`/`country`, plus always-null `url`/`logo`) to each match. Undocumented and
  **unvalidated**: a typo like `include=bogus` returns 200 and silently adds no key. Only
  `BSA` has data, only for the current round, only `country: "BR"`. Do not send `country=` —
  it filters without falling back, so anything but `BR` returns empty. Consumed by the
  marketing site (`website/matchday.js`) via a Pages Function proxy that keeps the API key
  server-side; the iOS app does not consume it yet.
```

- [ ] **Step 5: Note the production secret requirement**

In the **Fastlane / Release Automation** section of `CLAUDE.md`, append this paragraph at the
end of the section:

```markdown
The marketing site's live matchday section needs `FOOTBALL_API_KEY` set as a Cloudflare Pages
environment secret (dashboard → the `br26` project → Settings → Environment variables, marked
Encrypted) for the deployed site, and in a gitignored `.dev.vars` at the repo root for local
`npx wrangler pages dev`. Without it `/api/matches` returns 502 and the section stays hidden —
the page degrades to its pre-broadcasts appearance rather than breaking.
```

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md
git commit -m "Document include=broadcasts and the Pages Function secret

Records that the parameter is unvalidated (typos fail silently) and that
country= filters without falling back, both of which cost time to
discover against the live API."
```

- [ ] **Step 7: Final full verification**

```bash
node --test tests/*.test.js
```

Expected: PASS — 24 tests.

Report to the user: the test count, the actual matchday the section rendered, the broadcasters shown, and confirmation that the country control rendered as a static pill (single-country case) rather than a dropdown.

---

## Deferred, and why

Recorded so a later reader does not mistake these for oversights — each is in the spec's own out-of-scope list:

- **The other five landing pages.** The proxy allowlist already accepts their codes; rolling out is adding the section markup with a different `data-code`. None have broadcast data today.
- **The iOS app.** It has no broadcasts row. The API-side change would be adding `include=broadcasts` to `LiveMatchService.fetchMatches()` and a `broadcasts` field on `MatchDTO`; the UI is a separate spec.
- **Broadcaster logos and deep links**, until the backend populates `url` and `logo`.
- **Live score polling.** The section renders once per page load; the 60s edge cache means a reload shows reasonably fresh scores.
