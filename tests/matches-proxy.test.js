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
