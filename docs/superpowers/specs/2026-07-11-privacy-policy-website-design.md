# Privacy Policy Website Design

**Goal:** A minimal static website — a home page plus a Privacy Policy in all 5 locales the app
already supports — deployable to Netlify. The immediate driver is App Store Connect's required
Privacy Policy URL field; a fuller marketing site (screenshots, feature tour) is a separate,
later piece of work.

**Architecture:** Plain static HTML/CSS in a new `website/` directory at the repo root — no
build step, no framework, no JS dependency for content, consistent with this project's
"external dependencies: none" ethos. The Privacy Policy is 5 separate static pages (one per
locale) rather than one page that switches text via JavaScript, so each language has a stable,
shareable, indexable URL and renders correctly with JS disabled. Netlify serves the folder
directly via `netlify.toml`.

## File Structure

```
website/
├── index.html               # home page (English only)
├── styles.css                # shared styles, Liquid Glass look reused from the app
├── favicon.png                # derived from docs/AppIcon-1024.png
└── privacy/
    ├── en/index.html          # English (default/fallback, matches app's en-US fallback)
    ├── en-gb/index.html        # British English
    ├── fr/index.html           # French
    ├── pt-br/index.html         # Brazilian Portuguese
    └── pt-pt/index.html         # European Portuguese
netlify.toml                  # repo root: publish = "website", no build command
```

Locale directory names mirror the identifiers already used as keys in
`BR2026/Resources/Localizable.xcstrings` (`en`, `en-GB`, `fr`, `pt-BR`, `pt-PT`), lowercased for
URL cleanliness.

## Home Page (`website/index.html`)

English only, minimal content:
- App name: "Brasileirão" (from `ChampionshipConfig.brasileirao.displayName`)
- Tagline: "Live scores, fixtures, and the Brasileirão table — all in one place." (reused
  verbatim from `fastlane/metadata/en-US/release_notes.txt`)
- A "Coming soon to the App Store" badge — plain text/styled badge, **not a clickable link**:
  there is no live App Store URL yet (the app is TestFlight-beta-only per CLAUDE.md)
- A link to the Privacy Policy, pointing at `/privacy/en/` (the canonical URL to give App Store
  Connect)

Visual style reuses CLAUDE.md's Liquid Glass design language so the site reads as the same
product as the app:
- Background: the same radial-gradient stadium-night treatment
  (`#173a68` → `#0b2143` → `#061325`, top-center light source)
- Accent color: Sunset Red `#ff4d5e` (the app's default accent)
- Typography: system font stack (SF Pro on Apple platforms, falling back to the OS default
  elsewhere), matching the app's weight/tracking conventions for a title (32px/800) and a
  tagline/eyebrow (11px/700, tracking, uppercase, `white @ 0.5`)
- A glass-card treatment (semi-transparent white fill, thin light border, soft shadow) for the
  "Coming soon" badge and the Privacy Policy link, approximating `.ultraThinMaterial`/
  `.regularMaterial` with CSS `backdrop-filter` (the CSS equivalent CLAUDE.md tells the iOS app
  *not* to use, but which is the correct and only tool for this on the web)

## Privacy Policy Pages (`website/privacy/<locale>/index.html`)

Each locale page:
- Shares `styles.css` with the home page (same background/accent/typography, plain-text glass
  card containing the policy body)
- Has a language switcher at the top: 5 plain-text links (English, English (UK), Français,
  Português (Brasil), Português (Portugal)), each pointing at its sibling locale page
- Has a locale-specific `<title>` for SEO/App Store review clarity, e.g.
  `Brasileirão — Privacy Policy`, `Brasileirão — Politique de confidentialité`,
  `Brasileirão — Política de Privacidade`

**Content** mirrors the tone, structure, and legal caveat already established for the in-app
Terms of Service (`terms_of_service_body` in `Localizable.xcstrings`): plain-language starter
legal copy, **not legal advice**, and must be reviewed by qualified counsel before App Store
submission — same caveat CLAUDE.md already states for the Terms of Service. Content reflects
what the app actually does, verified against CLAUDE.md and the codebase: no accounts, no
analytics/advertising/tracking SDKs (`External dependencies: None` per CLAUDE.md Tech Stack), no
personal data collected. It fetches public match/team/competition data from a third-party sports
API and caches it locally on-device via SwiftData; that cache never leaves the device.

Canonical English structure (all 5 locales get full, equivalent translated text — not
English-with-a-note — matching the Terms of Service pattern):

```
Privacy Policy

This Privacy Policy explains how the Brasileirão app ("the app") handles information
when you use it.

1. Information We Collect
This app does not collect, store, or share any personal information. It does not
require account creation, sign-in, or any personal details. The app fetches public
sports data — match scores, fixtures, and standings for the Brasileirão championship —
from a third-party sports data API. This data is cached locally on your device to
improve performance and is not transmitted anywhere else.

2. Analytics and Tracking
This app does not use analytics, advertising, or tracking software of any kind.

3. Third-Party Services
Match, team, and competition data (including team crest images) is loaded from a
third-party sports data API. Loading this data may expose your device's IP address to
that service, as is standard for any network request. We do not control and are not
responsible for that service's own data practices.

4. Data Stored on Your Device
The app uses on-device storage to cache match data for faster loading. This data stays
on your device and is not sent to us.

5. Children's Privacy
This app is not directed at children and does not knowingly collect information from
children.

6. Changes to This Policy
We may update this Privacy Policy from time to time. Continued use of the app after
changes constitutes acceptance of the updated policy.

7. Contact
Questions about this Privacy Policy can be directed to the app's support contact listed
on its App Store page.
```

The other 4 locales (en-GB, fr, pt-BR, pt-PT) get full professional translations of this same
structure, written out verbatim in the implementation plan — the same way the Terms of Service
translations were written out task-by-task rather than left as a translation TODO.

## Netlify Deployment

`netlify.toml` at the repo root:
```toml
[build]
  publish = "website"
```
No build command — the folder is served as-is.

**Out of scope for this plan:** actually creating and connecting the Netlify site is an
account-linked action in the user's Netlify dashboard (connect the GitHub repo, or drag-and-drop
deploy) — this plan produces a ready-to-deploy folder and the `netlify.toml`, but does not
perform the account-linking step itself. A fuller marketing site (screenshots, feature tour,
multi-page navigation, App Store download button once the app is live) is separate, later work.
