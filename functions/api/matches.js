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
