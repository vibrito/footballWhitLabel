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
