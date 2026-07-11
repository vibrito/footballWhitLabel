# Privacy Policy Website Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a minimal static website — a home page plus a Privacy Policy in all 5 locales
the app already supports — ready to deploy to Netlify, per
`docs/superpowers/specs/2026-07-11-privacy-policy-website-design.md`.

**Architecture:** Plain static HTML/CSS in a new `website/` directory at the repo root, no build
step. A shared `styles.css` implements the app's Liquid Glass look (stadium-night gradient,
glass cards, Sunset Red accent). The Privacy Policy is 5 separate static pages (one per locale,
absolute-root-relative URLs under `/privacy/<locale>/`), not a single JS-driven page, so every
language has a stable, indexable URL with no JavaScript dependency for correct content.

**Tech Stack:** Plain HTML5, plain CSS (no framework, no build tool), Netlify static hosting.

## Global Constraints

- No external dependencies, no framework, no JavaScript required for content to display
  correctly. (Design spec, Architecture)
- Locale directory names: `en`, `en-gb`, `fr`, `pt-br`, `pt-pt` — lowercased versions of the
  identifiers already used in `BR2026/Resources/Localizable.xcstrings` (`en`, `en-GB`, `fr`,
  `pt-BR`, `pt-PT`). (Design spec, File Structure)
- Visual design tokens from CLAUDE.md: background radial-gradient `#173a68` → `#0b2143` →
  `#061325` (top-center light source); two blurred blobs (top-left accent @ 40% alpha,
  bottom-right teal `rgba(45,212,191,0.32)`); accent color `#ff4d5e`; glass card fill
  `white @ 0.07`, border `0.5px, white @ 0.16`, shadow `0 8px 22px black @ 0.22`. (Design spec,
  Home Page / CLAUDE.md Design System)
- Privacy Policy content is starter legal boilerplate, not legal advice, and must be reviewed by
  qualified counsel before App Store submission — same caveat CLAUDE.md already states for the
  in-app Terms of Service. All 5 locales get full, equivalent translated text, not
  English-with-a-note. (Design spec, Privacy Policy Pages)
- `netlify.toml`: `publish = "website"`, no build command. (Design spec, Netlify Deployment)
- Home page's "Coming soon to the App Store" badge is plain text, not a clickable link — there
  is no live App Store URL yet. (Design spec, Home Page)

---

## Task 1: Site foundation and home page

**Files:**
- Create: `netlify.toml`
- Create: `website/styles.css`
- Create: `website/favicon.png`
- Create: `website/index.html`

**Interfaces:**
- Produces: CSS classes consumed by Task 2 — `.page`, `.content`, `.stadium-background`,
  `.blob`, `.blob-accent`, `.blob-teal`, `.glass-card`, `.privacy-page`, `.lang-switcher`,
  `.policy-card`, `.back-link`, and the `--accent` custom property.

- [ ] **Step 1: Write `netlify.toml`**

```toml
[build]
  publish = "website"
```

- [ ] **Step 2: Write `website/styles.css`**

```css
:root {
  --accent: #ff4d5e;
  --bg-top: #173a68;
  --bg-mid: #0b2143;
  --bg-bottom: #061325;
}

* {
  box-sizing: border-box;
}

html, body {
  margin: 0;
  padding: 0;
  min-height: 100%;
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", Roboto, sans-serif;
  color: #ffffff;
  background: var(--bg-bottom);
}

.stadium-background {
  position: fixed;
  inset: 0;
  z-index: -2;
  background: radial-gradient(circle at 50% 0%, var(--bg-top), var(--bg-mid) 55%, var(--bg-bottom) 100%);
}

.blob {
  position: fixed;
  z-index: -1;
  width: 480px;
  height: 480px;
  border-radius: 50%;
  filter: blur(90px);
  pointer-events: none;
}

.blob-accent {
  top: -120px;
  left: -120px;
  background: var(--accent);
  opacity: 0.4;
}

.blob-teal {
  bottom: -140px;
  right: -140px;
  background: rgba(45, 212, 191, 0.32);
}

.page {
  position: relative;
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
}

.content {
  position: relative;
  z-index: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 20px;
  max-width: 480px;
  text-align: center;
}

.title {
  margin: 0;
  font-size: 32px;
  font-weight: 800;
  letter-spacing: -0.5px;
  line-height: 1.1;
}

.tagline {
  margin: 0;
  font-size: 17px;
  font-weight: 500;
  line-height: 1.5;
  color: rgba(255, 255, 255, 0.85);
}

.glass-card {
  background: rgba(255, 255, 255, 0.07);
  border: 0.5px solid rgba(255, 255, 255, 0.16);
  border-radius: 15px;
  box-shadow: 0 8px 22px rgba(0, 0, 0, 0.22);
  -webkit-backdrop-filter: blur(20px);
  backdrop-filter: blur(20px);
  padding: 12px 20px;
  font-size: 13px;
  font-weight: 700;
  letter-spacing: 0.3px;
}

.badge {
  color: rgba(255, 255, 255, 0.7);
}

.privacy-link {
  color: var(--accent);
  text-decoration: none;
}

.privacy-link:hover {
  text-decoration: underline;
}

/* Privacy policy pages */

.privacy-page .content {
  max-width: 640px;
  align-items: stretch;
  text-align: left;
}

.lang-switcher {
  display: flex;
  flex-wrap: wrap;
  gap: 8px 16px;
  margin: 0 0 8px 0;
}

.lang-switcher a {
  color: rgba(255, 255, 255, 0.55);
  text-decoration: none;
  font-size: 13px;
  font-weight: 600;
}

.lang-switcher a[aria-current="true"] {
  color: var(--accent);
}

.lang-switcher a:hover {
  color: #ffffff;
}

.policy-card {
  background: rgba(255, 255, 255, 0.07);
  border: 0.5px solid rgba(255, 255, 255, 0.16);
  border-radius: 24px;
  box-shadow: 0 8px 22px rgba(0, 0, 0, 0.22);
  -webkit-backdrop-filter: blur(20px);
  backdrop-filter: blur(20px);
  padding: 32px;
}

.policy-card h1 {
  margin: 0 0 4px 0;
  font-size: 28px;
  font-weight: 800;
  letter-spacing: -0.5px;
}

.policy-card h2 {
  margin: 24px 0 8px 0;
  font-size: 15px;
  font-weight: 700;
  letter-spacing: 0.3px;
  color: rgba(255, 255, 255, 0.9);
}

.policy-card p {
  margin: 0 0 12px 0;
  font-size: 14px;
  line-height: 1.6;
  color: rgba(255, 255, 255, 0.85);
}

.back-link {
  display: inline-block;
  margin-top: 24px;
  font-size: 13px;
  font-weight: 600;
  color: var(--accent);
  text-decoration: none;
}

.back-link:hover {
  text-decoration: underline;
}
```

- [ ] **Step 3: Generate the favicon from the existing app icon**

```bash
mkdir -p website
sips -Z 512 docs/AppIcon-1024.png --out website/favicon.png
```

Expected: `website/favicon.png` exists and is a 512×512 (or smaller, `sips -Z` preserves aspect
ratio and only shrinks) PNG.

- [ ] **Step 4: Write `website/index.html`**

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
  <main class="page">
    <div class="content">
      <h1 class="title">Brasileirão</h1>
      <p class="tagline">Live scores, fixtures, and the Brasileirão table — all in one place.</p>
      <div class="glass-card badge">Coming soon to the App Store</div>
      <a class="glass-card privacy-link" href="/privacy/en/">Privacy Policy</a>
    </div>
  </main>
</body>
</html>
```

- [ ] **Step 5: Verify locally**

```bash
cd website && python3 -m http.server 8765 >/dev/null 2>&1 &
SERVER_PID=$!
sleep 1
curl -s http://localhost:8765/ | grep -o 'Brasileirão'
curl -s http://localhost:8765/ | grep -o 'Coming soon to the App Store'
curl -s http://localhost:8765/ | grep -o 'href="/privacy/en/"'
kill "$SERVER_PID"
cd ..
```

Expected: all three `grep` commands print a match (the page loads and contains the app name,
the badge text, and the link to the not-yet-created `/privacy/en/` page — that link will 404
until Task 2, which is expected at this point).

- [ ] **Step 6: Commit**

```bash
git add netlify.toml website/styles.css website/favicon.png website/index.html
git commit -m "Add site foundation and home page for the Privacy Policy website"
```

---

## Task 2: Privacy Policy pages, all 5 locales

**Files:**
- Create: `website/privacy/en/index.html`
- Create: `website/privacy/en-gb/index.html`
- Create: `website/privacy/fr/index.html`
- Create: `website/privacy/pt-br/index.html`
- Create: `website/privacy/pt-pt/index.html`

**Interfaces:**
- Consumes: `.page`, `.content`, `.privacy-page`, `.lang-switcher`, `.policy-card`,
  `.back-link`, `.stadium-background`, `.blob`/`.blob-accent`/`.blob-teal` from
  `website/styles.css` (Task 1).
- Produces: the 5 URLs (`/privacy/en/`, `/privacy/en-gb/`, `/privacy/fr/`, `/privacy/pt-br/`,
  `/privacy/pt-pt/`) that Task 1's home page already links to via `/privacy/en/`, and that each
  page's language switcher cross-links to.

- [ ] **Step 1: Write `website/privacy/en/index.html`**

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Brasileirão — Privacy Policy</title>
  <link rel="icon" type="image/png" href="/favicon.png">
  <link rel="stylesheet" href="/styles.css">
</head>
<body>
  <div class="stadium-background"></div>
  <div class="blob blob-accent"></div>
  <div class="blob blob-teal"></div>
  <main class="page privacy-page">
    <div class="content">
      <nav class="lang-switcher" aria-label="Language">
        <a href="/privacy/en/" aria-current="true">English</a>
        <a href="/privacy/en-gb/">English (UK)</a>
        <a href="/privacy/fr/">Français</a>
        <a href="/privacy/pt-br/">Português (Brasil)</a>
        <a href="/privacy/pt-pt/">Português (Portugal)</a>
      </nav>
      <article class="policy-card">
        <h1>Privacy Policy</h1>
        <p>This Privacy Policy explains how the Brasileirão app ("the app") handles information when you use it.</p>

        <h2>1. Information We Collect</h2>
        <p>This app does not collect, store, or share any personal information. It does not require account creation, sign-in, or any personal details. The app fetches public sports data — match scores, fixtures, and standings for the Brasileirão championship — from a third-party sports data API. This data is cached locally on your device to improve performance and is not transmitted anywhere else.</p>

        <h2>2. Analytics and Tracking</h2>
        <p>This app does not use analytics, advertising, or tracking software of any kind.</p>

        <h2>3. Third-Party Services</h2>
        <p>Match, team, and competition data (including team crest images) is loaded from a third-party sports data API. Loading this data may expose your device's IP address to that service, as is standard for any network request. We do not control and are not responsible for that service's own data practices.</p>

        <h2>4. Data Stored on Your Device</h2>
        <p>The app uses on-device storage to cache match data for faster loading. This data stays on your device and is not sent to us.</p>

        <h2>5. Children's Privacy</h2>
        <p>This app is not directed at children and does not knowingly collect information from children.</p>

        <h2>6. Changes to This Policy</h2>
        <p>We may update this Privacy Policy from time to time. Continued use of the app after changes constitutes acceptance of the updated policy.</p>

        <h2>7. Contact</h2>
        <p>Questions about this Privacy Policy can be directed to the app's support contact listed on its App Store page.</p>

        <a class="back-link" href="/">← Back to home</a>
      </article>
    </div>
  </main>
</body>
</html>
```

- [ ] **Step 2: Write `website/privacy/en-gb/index.html`**

```html
<!doctype html>
<html lang="en-GB">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Brasileirão — Privacy Policy</title>
  <link rel="icon" type="image/png" href="/favicon.png">
  <link rel="stylesheet" href="/styles.css">
</head>
<body>
  <div class="stadium-background"></div>
  <div class="blob blob-accent"></div>
  <div class="blob blob-teal"></div>
  <main class="page privacy-page">
    <div class="content">
      <nav class="lang-switcher" aria-label="Language">
        <a href="/privacy/en/">English</a>
        <a href="/privacy/en-gb/" aria-current="true">English (UK)</a>
        <a href="/privacy/fr/">Français</a>
        <a href="/privacy/pt-br/">Português (Brasil)</a>
        <a href="/privacy/pt-pt/">Português (Portugal)</a>
      </nav>
      <article class="policy-card">
        <h1>Privacy Policy</h1>
        <p>This Privacy Policy explains how the Brasileirão app ("the app") handles information when you use it.</p>

        <h2>1. Information We Collect</h2>
        <p>This app does not collect, store, or share any personal information. It does not require account creation, sign-in, or any personal details. The app fetches public sports data — match scores, fixtures, and standings for the Brasileirão championship — from a third-party sports data API. This data is cached locally on your device to improve performance and is not transmitted anywhere else.</p>

        <h2>2. Analytics and Tracking</h2>
        <p>This app does not use analytics, advertising, or tracking software of any kind.</p>

        <h2>3. Third-Party Services</h2>
        <p>Match, team, and competition data (including team crest images) is loaded from a third-party sports data API. Loading this data may expose your device's IP address to that service, as is standard for any network request. We do not control and are not responsible for that service's own data practices.</p>

        <h2>4. Data Stored on Your Device</h2>
        <p>The app uses on-device storage to cache match data for faster loading. This data stays on your device and is not sent to us.</p>

        <h2>5. Children's Privacy</h2>
        <p>This app is not directed at children and does not knowingly collect information from children.</p>

        <h2>6. Changes to This Policy</h2>
        <p>We may update this Privacy Policy from time to time. Continued use of the app after changes constitutes acceptance of the updated policy.</p>

        <h2>7. Contact</h2>
        <p>Questions about this Privacy Policy can be directed to the app's support contact listed on its App Store page.</p>

        <a class="back-link" href="/">← Back to home</a>
      </article>
    </div>
  </main>
</body>
</html>
```

- [ ] **Step 3: Write `website/privacy/fr/index.html`**

```html
<!doctype html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Brasileirão — Politique de confidentialité</title>
  <link rel="icon" type="image/png" href="/favicon.png">
  <link rel="stylesheet" href="/styles.css">
</head>
<body>
  <div class="stadium-background"></div>
  <div class="blob blob-accent"></div>
  <div class="blob blob-teal"></div>
  <main class="page privacy-page">
    <div class="content">
      <nav class="lang-switcher" aria-label="Langue">
        <a href="/privacy/en/">English</a>
        <a href="/privacy/en-gb/">English (UK)</a>
        <a href="/privacy/fr/" aria-current="true">Français</a>
        <a href="/privacy/pt-br/">Português (Brasil)</a>
        <a href="/privacy/pt-pt/">Português (Portugal)</a>
      </nav>
      <article class="policy-card">
        <h1>Politique de confidentialité</h1>
        <p>Cette politique de confidentialité explique comment l'application Brasileirão (« l'application ») traite les informations lorsque vous l'utilisez.</p>

        <h2>1. Informations que nous collectons</h2>
        <p>Cette application ne collecte, ne stocke et ne partage aucune information personnelle. Elle ne nécessite ni création de compte, ni connexion, ni aucune donnée personnelle. L'application récupère des données sportives publiques — scores, calendrier et classement du Championnat brésilien (Brasileirão) — auprès d'une API sportive tierce. Ces données sont mises en cache localement sur votre appareil afin d'améliorer les performances et ne sont transmises nulle part ailleurs.</p>

        <h2>2. Analyse et suivi</h2>
        <p>Cette application n'utilise aucun logiciel d'analyse, de publicité ou de suivi.</p>

        <h2>3. Services tiers</h2>
        <p>Les données de matchs, d'équipes et de compétition (y compris les images des écussons d'équipe) sont chargées depuis une API sportive tierce. Le chargement de ces données peut exposer l'adresse IP de votre appareil à ce service, comme c'est le cas pour toute requête réseau standard. Nous ne contrôlons pas et ne sommes pas responsables des pratiques de ce service en matière de données.</p>

        <h2>4. Données stockées sur votre appareil</h2>
        <p>L'application utilise un stockage local pour mettre en cache les données de match afin d'accélérer leur chargement. Ces données restent sur votre appareil et ne nous sont jamais transmises.</p>

        <h2>5. Confidentialité des enfants</h2>
        <p>Cette application ne s'adresse pas aux enfants et ne collecte sciemment aucune information les concernant.</p>

        <h2>6. Modifications de cette politique</h2>
        <p>Nous pouvons mettre à jour cette politique de confidentialité de temps à autre. La poursuite de l'utilisation de l'application après ces modifications vaut acceptation de la politique mise à jour.</p>

        <h2>7. Contact</h2>
        <p>Les questions relatives à cette politique de confidentialité peuvent être adressées au contact d'assistance indiqué sur la page App Store de l'application.</p>

        <a class="back-link" href="/">← Retour à l'accueil</a>
      </article>
    </div>
  </main>
</body>
</html>
```

- [ ] **Step 4: Write `website/privacy/pt-br/index.html`**

```html
<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Brasileirão — Política de Privacidade</title>
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
        <a href="/privacy/en/">English</a>
        <a href="/privacy/en-gb/">English (UK)</a>
        <a href="/privacy/fr/">Français</a>
        <a href="/privacy/pt-br/" aria-current="true">Português (Brasil)</a>
        <a href="/privacy/pt-pt/">Português (Portugal)</a>
      </nav>
      <article class="policy-card">
        <h1>Política de Privacidade</h1>
        <p>Esta Política de Privacidade explica como o aplicativo Brasileirão ("o aplicativo") trata as informações quando você o utiliza.</p>

        <h2>1. Informações que coletamos</h2>
        <p>Este aplicativo não coleta, armazena nem compartilha nenhuma informação pessoal. Ele não exige criação de conta, login ou qualquer dado pessoal. O aplicativo busca dados esportivos públicos — placares, jogos e classificação do Campeonato Brasileiro — em uma API esportiva de terceiros. Esses dados são armazenados em cache localmente no seu dispositivo para melhorar o desempenho e não são transmitidos para nenhum outro lugar.</p>

        <h2>2. Análise e rastreamento</h2>
        <p>Este aplicativo não utiliza software de análise, publicidade ou rastreamento de nenhum tipo.</p>

        <h2>3. Serviços de terceiros</h2>
        <p>Os dados de partidas, times e competição (incluindo as imagens dos escudos dos times) são carregados de uma API esportiva de terceiros. O carregamento desses dados pode expor o endereço IP do seu dispositivo a esse serviço, como é padrão em qualquer solicitação de rede. Não controlamos nem somos responsáveis pelas práticas de dados desse serviço.</p>

        <h2>4. Dados armazenados no seu dispositivo</h2>
        <p>O aplicativo utiliza armazenamento local para colocar em cache os dados das partidas e acelerar o carregamento. Esses dados permanecem no seu dispositivo e não são enviados para nós.</p>

        <h2>5. Privacidade infantil</h2>
        <p>Este aplicativo não é direcionado a crianças e não coleta intencionalmente informações de crianças.</p>

        <h2>6. Alterações a esta política</h2>
        <p>Podemos atualizar esta Política de Privacidade periodicamente. O uso continuado do aplicativo após as alterações constitui aceitação da política atualizada.</p>

        <h2>7. Contato</h2>
        <p>Dúvidas sobre esta Política de Privacidade podem ser enviadas para o contato de suporte listado na página do aplicativo na App Store.</p>

        <a class="back-link" href="/">← Voltar ao início</a>
      </article>
    </div>
  </main>
</body>
</html>
```

- [ ] **Step 5: Write `website/privacy/pt-pt/index.html`**

```html
<!doctype html>
<html lang="pt-PT">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Brasileirão — Política de Privacidade</title>
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
        <a href="/privacy/en/">English</a>
        <a href="/privacy/en-gb/">English (UK)</a>
        <a href="/privacy/fr/">Français</a>
        <a href="/privacy/pt-br/">Português (Brasil)</a>
        <a href="/privacy/pt-pt/" aria-current="true">Português (Portugal)</a>
      </nav>
      <article class="policy-card">
        <h1>Política de Privacidade</h1>
        <p>Esta Política de Privacidade explica como a aplicação Brasileirão ("a aplicação") trata as informações quando a utiliza.</p>

        <h2>1. Informações que recolhemos</h2>
        <p>Esta aplicação não recolhe, armazena nem partilha qualquer informação pessoal. Não exige criação de conta, sessão iniciada nem quaisquer dados pessoais. A aplicação obtém dados desportivos públicos — resultados, jogos e classificação do Campeonato Brasileiro — a partir de uma API desportiva de terceiros. Estes dados são armazenados em cache localmente no seu dispositivo para melhorar o desempenho e não são transmitidos para mais nenhum lugar.</p>

        <h2>2. Análise e monitorização</h2>
        <p>Esta aplicação não utiliza software de análise, publicidade ou monitorização de qualquer tipo.</p>

        <h2>3. Serviços de terceiros</h2>
        <p>Os dados de jogos, equipas e competição (incluindo as imagens dos emblemas das equipas) são carregados a partir de uma API desportiva de terceiros. O carregamento destes dados pode expor o endereço IP do seu dispositivo a esse serviço, tal como é habitual em qualquer pedido de rede. Não controlamos nem somos responsáveis pelas práticas de dados desse serviço.</p>

        <h2>4. Dados armazenados no seu dispositivo</h2>
        <p>A aplicação utiliza armazenamento local para colocar em cache os dados dos jogos e acelerar o respetivo carregamento. Estes dados permanecem no seu dispositivo e não nos são enviados.</p>

        <h2>5. Privacidade das crianças</h2>
        <p>Esta aplicação não se destina a crianças e não recolhe intencionalmente informações sobre crianças.</p>

        <h2>6. Alterações a esta política</h2>
        <p>Podemos atualizar esta Política de Privacidade periodicamente. A utilização continuada da aplicação após alterações constitui aceitação da política atualizada.</p>

        <h2>7. Contacto</h2>
        <p>Questões sobre esta Política de Privacidade podem ser enviadas para o contacto de suporte indicado na página da aplicação na App Store.</p>

        <a class="back-link" href="/">← Voltar ao início</a>
      </article>
    </div>
  </main>
</body>
</html>
```

- [ ] **Step 6: Verify locally**

```bash
cd website && python3 -m http.server 8765 >/dev/null 2>&1 &
SERVER_PID=$!
sleep 1
for loc in en en-gb fr pt-br pt-pt; do
  code=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:8765/privacy/$loc/")
  echo "$loc: $code"
done
curl -s http://localhost:8765/ | grep -o 'href="/privacy/en/"'
kill "$SERVER_PID"
cd ..
```

Expected: all 5 locale checks print `200`, and the home page's link to `/privacy/en/` still
matches (now resolving instead of 404ing).

- [ ] **Step 7: Commit**

```bash
git add website/privacy
git commit -m "Add Privacy Policy pages for all 5 supported locales"
```
