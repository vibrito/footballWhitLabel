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
