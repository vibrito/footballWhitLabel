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
