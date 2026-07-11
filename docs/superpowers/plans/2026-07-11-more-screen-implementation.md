# More Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the placeholder `MoreView` with a real screen showing a Legal section
(Terms of Service) and disabled Settings/In-App Purchases placeholder rows, per
`docs/superpowers/specs/2026-07-11-more-screen-design.md`.

**Architecture:** A data-driven `MoreRow`/`MoreSection`/`MoreDestination` model exposed by
`MoreViewModel` (`@Observable`, no service dependency), rendered by `MoreView` as
`GlassCard`-wrapped sections matching the existing Liquid Glass design system. Terms of
Service pushes a `TermsOfServiceView` showing localized static text (all 5 locales); Settings
and In-App Purchases render as dimmed, non-tappable rows.

**Tech Stack:** SwiftUI (iOS 26+), Swift Testing, `@Observable`, existing `GlassCard` /
`StadiumBackground` components, `Localizable.xcstrings` String Catalog.

## Global Constraints

- MVVM: Views own no business logic; `MoreViewModel` is `@Observable`. (CLAUDE.md Architecture)
- No force-unwraps (`!`) outside tests. (CLAUDE.md Coding Guidelines)
- Icons are SF Symbols only: Terms of Service → `doc.text`, Settings → `gearshape`,
  In-App Purchases → `cart`. (Design spec, Views section)
- Corner radii/opacity from CLAUDE.md's design system: slim-row card corner radius 18px;
  card border `0.5px, white @ 0.16`; disabled-row dim `white @ 0.3`; section header text
  13px/700, tracking 0.8, `white @ 0.5`, uppercase.
- All user-facing UI strings go through `Localizable.xcstrings` (CLAUDE.md Localization). Row/
  section titles ("Legal", "Preferences", "Terms of Service", "Settings", "In-App Purchases")
  follow the existing codebase convention of an `en`-only entry (matching every other string
  currently in the catalog). The Terms of Service body text is the one exception: real starter
  copy in all 5 locales (pt-BR, pt-PT, fr, en, en-GB), per explicit user decision during
  brainstorming — this is starter legal boilerplate, **not legal advice**, and must be reviewed
  by qualified counsel before App Store submission.
- Privacy Policy is out of scope for the in-app screen (handled via App Store Connect metadata
  only). Actual Settings/In-App Purchases functionality, persistence, and a Privacy Policy
  in-app screen are future phases — do not implement beyond the disabled placeholder rows.
- Test framework: Swift Testing (`@Test`, `@Suite`), no `MockMatchService` needed here (no
  service dependency). No view tests, per CLAUDE.md's "unit test ViewModels, not Views."

---

## Task 1: `MoreRow`/`MoreSection`/`MoreDestination` models + `MoreViewModel`

**Files:**
- Create: `BR2026/Models/MoreDestination.swift`
- Create: `BR2026/Models/MoreRow.swift`
- Create: `BR2026/Models/MoreSection.swift`
- Create: `BR2026/ViewModels/MoreViewModel.swift`
- Test: `BR2026Tests/ViewModels/MoreViewModelTests.swift`

**Interfaces:**
- Produces: `MoreDestination` (enum, case `.termsOfService`), `MoreRow` (struct: `id: String`,
  `titleKey: LocalizedStringResource`, `systemImage: String`, `destination: MoreDestination?`,
  `isEnabled: Bool`), `MoreSection` (struct: `id: String`, `titleKey: LocalizedStringResource`,
  `rows: [MoreRow]`), `MoreViewModel` (`@Observable final class`, property `sections: [MoreSection]`
  with ids `"legal"` and `"preferences"`) — all consumed by Task 3's `MoreView`.

- [ ] **Step 1: Write the failing test**

Create `BR2026Tests/ViewModels/MoreViewModelTests.swift`:
```swift
import Testing
@testable import BR2026

@Suite("MoreViewModel")
struct MoreViewModelTests {
    @Test("Legal section has one enabled Terms of Service row")
    func legalSection() {
        let viewModel = MoreViewModel()
        let legal = viewModel.sections.first { $0.id == "legal" }
        #expect(legal?.rows.count == 1)
        #expect(legal?.rows.first?.destination == .termsOfService)
        #expect(legal?.rows.first?.isEnabled == true)
    }

    @Test("Preferences section has two disabled, destination-less rows")
    func preferencesSection() {
        let viewModel = MoreViewModel()
        let preferences = viewModel.sections.first { $0.id == "preferences" }
        #expect(preferences?.rows.count == 2)
        #expect(preferences?.rows.allSatisfy { $0.destination == nil && !$0.isEnabled } == true)
    }
}
```

- [ ] **Step 2: Run it to confirm it fails to compile**

Run:
```bash
/opt/homebrew/bin/rbenv exec bundle exec fastlane test
```
Expected: build failure — `cannot find 'MoreViewModel' in scope`.

- [ ] **Step 3: Create the model files**

Create `BR2026/Models/MoreDestination.swift`:
```swift
import Foundation

enum MoreDestination: Hashable {
    case termsOfService
}
```

Create `BR2026/Models/MoreRow.swift`:
```swift
import Foundation

struct MoreRow: Identifiable {
    let id: String
    let titleKey: LocalizedStringResource
    let systemImage: String
    let destination: MoreDestination?
    let isEnabled: Bool
}
```

Create `BR2026/Models/MoreSection.swift`:
```swift
import Foundation

struct MoreSection: Identifiable {
    let id: String
    let titleKey: LocalizedStringResource
    let rows: [MoreRow]
}
```

- [ ] **Step 4: Create the ViewModel**

Create `BR2026/ViewModels/MoreViewModel.swift`:
```swift
import Foundation
import Observation

@Observable
final class MoreViewModel {
    let sections: [MoreSection] = [
        MoreSection(
            id: "legal",
            titleKey: "Legal",
            rows: [
                MoreRow(
                    id: "termsOfService",
                    titleKey: "Terms of Service",
                    systemImage: "doc.text",
                    destination: .termsOfService,
                    isEnabled: true
                )
            ]
        ),
        MoreSection(
            id: "preferences",
            titleKey: "Preferences",
            rows: [
                MoreRow(
                    id: "settings",
                    titleKey: "Settings",
                    systemImage: "gearshape",
                    destination: nil,
                    isEnabled: false
                ),
                MoreRow(
                    id: "inAppPurchases",
                    titleKey: "In-App Purchases",
                    systemImage: "cart",
                    destination: nil,
                    isEnabled: false
                )
            ]
        )
    ]
}
```

- [ ] **Step 5: Run tests again to confirm they pass**

Run:
```bash
/opt/homebrew/bin/rbenv exec bundle exec fastlane test
```
Expected: `Number of failures | 0`, `Number of tests` up from 40 to 42.

- [ ] **Step 6: Commit**

```bash
git add BR2026/Models/MoreDestination.swift BR2026/Models/MoreRow.swift BR2026/Models/MoreSection.swift BR2026/ViewModels/MoreViewModel.swift BR2026Tests/ViewModels/MoreViewModelTests.swift
git commit -m "Add MoreViewModel with Legal/Preferences sections"
```

---

## Task 2: Localization content

**Files:**
- Modify: `BR2026/Resources/Localizable.xcstrings`
- Modify: `BR2026.xcodeproj/project.pbxproj` (add locales to `knownRegions`)

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: catalog keys `"Legal"`, `"Preferences"`, `"Terms of Service"`, `"Settings"`,
  `"In-App Purchases"` (en-only, matching every other existing entry), and
  `"terms_of_service_body"` (en, en-GB, fr, pt-BR, pt-PT) — consumed by Task 3's `MoreView` and
  `TermsOfServiceView`.

- [ ] **Step 1: Add the four new locales to the Xcode project**

In `BR2026.xcodeproj/project.pbxproj`, find:
```
			knownRegions = (
				Base,
				en,
			);
```
Replace with:
```
			knownRegions = (
				Base,
				en,
				"en-GB",
				fr,
				"pt-BR",
				"pt-PT",
			);
```
(Without this, Xcode's project settings won't list these as supported localizations, even
though the String Catalog can technically hold the values.)

- [ ] **Step 2: Add the new string catalog entries**

In `BR2026/Resources/Localizable.xcstrings`, find the `"VS"` entry (the last entry before the
closing of the `"strings"` object):
```json
    "VS" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "VS"
          }
        }
      }
    }
  },
  "version" : "1.1"
}
```
Replace with (adds a comma after the `"VS"` entry's closing brace, then the six new entries,
preserving the final closing exactly as before):
```json
    "VS" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "VS"
          }
        }
      }
    },
    "In-App Purchases" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "In-App Purchases"
          }
        }
      }
    },
    "Legal" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Legal"
          }
        }
      }
    },
    "Preferences" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Preferences"
          }
        }
      }
    },
    "Settings" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Settings"
          }
        }
      }
    },
    "Terms of Service" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Terms of Service"
          }
        }
      }
    },
    "terms_of_service_body" : {
      "comment" : "Full legal text on the Terms of Service screen (More tab). Starter draft only -- must be reviewed by legal counsel before App Store submission.",
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "By using this app, you agree to the following terms.\n\n1. About This App\nThis app provides live scores, fixtures, and standings for the Brasileirão championship. Match, team, and competition data is provided by a third-party sports data API and is displayed as received; we do not guarantee its accuracy or timeliness.\n\n2. Acceptable Use\nYou agree to use this app only for lawful purposes and not to attempt to disrupt, reverse-engineer, or gain unauthorized access to its underlying services.\n\n3. No Warranty\nThis app is provided \"as is,\" without warranties of any kind. We are not liable for any inaccuracies in match data, missed updates, or interruptions in service.\n\n4. Changes to These Terms\nWe may update these terms from time to time. Continued use of the app after changes constitutes acceptance of the updated terms.\n\n5. Contact\nQuestions about these terms can be directed to the app's support contact listed on its App Store page."
          }
        },
        "en-GB" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "By using this app, you agree to the following terms.\n\n1. About This App\nThis app provides live scores, fixtures, and standings for the Brasileirão championship. Match, team, and competition data is provided by a third-party sports data API and is displayed as received; we do not guarantee its accuracy or timeliness.\n\n2. Acceptable Use\nYou agree to use this app only for lawful purposes and not to attempt to disrupt, reverse-engineer, or gain unauthorised access to its underlying services.\n\n3. No Warranty\nThis app is provided \"as is,\" without warranties of any kind. We are not liable for any inaccuracies in match data, missed updates, or interruptions in service.\n\n4. Changes to These Terms\nWe may update these terms from time to time. Continued use of the app after changes constitutes acceptance of the updated terms.\n\n5. Contact\nQuestions about these terms can be directed to the app's support contact listed on the app's App Store page."
          }
        },
        "fr" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "En utilisant cette application, vous acceptez les conditions suivantes.\n\n1. À propos de cette application\nCette application fournit les scores en direct, le calendrier et le classement du Championnat brésilien (Brasileirão). Les données de matchs, d'équipes et de compétition proviennent d'une API sportive tierce et sont affichées telles que reçues ; nous ne garantissons ni leur exactitude ni leur actualisation en temps réel.\n\n2. Utilisation autorisée\nVous vous engagez à utiliser cette application uniquement à des fins légales et à ne pas tenter de perturber, d'effectuer une rétro-ingénierie ou d'accéder sans autorisation à ses services sous-jacents.\n\n3. Absence de garantie\nCette application est fournie « telle quelle », sans garantie d'aucune sorte. Nous ne pouvons être tenus responsables des imprécisions dans les données de match, des mises à jour manquées ou des interruptions de service.\n\n4. Modifications des présentes conditions\nNous pouvons modifier ces conditions de temps à autre. La poursuite de l'utilisation de l'application après ces modifications vaut acceptation des nouvelles conditions.\n\n5. Contact\nLes questions relatives à ces conditions peuvent être adressées au contact d'assistance indiqué sur la page App Store de l'application."
          }
        },
        "pt-BR" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Ao usar este aplicativo, você concorda com os seguintes termos.\n\n1. Sobre este aplicativo\nEste aplicativo fornece placares ao vivo, jogos e classificação do Campeonato Brasileiro. Os dados de partidas, times e competição são fornecidos por uma API esportiva de terceiros e exibidos como recebidos; não garantimos sua precisão ou atualização em tempo real.\n\n2. Uso aceitável\nVocê concorda em usar este aplicativo apenas para fins lícitos e em não tentar interromper, fazer engenharia reversa ou obter acesso não autorizado aos seus serviços subjacentes.\n\n3. Sem garantias\nEste aplicativo é fornecido \"como está\", sem garantias de qualquer tipo. Não nos responsabilizamos por imprecisões nos dados das partidas, atualizações perdidas ou interrupções no serviço.\n\n4. Alterações a estes termos\nPodemos atualizar estes termos periodicamente. O uso continuado do aplicativo após as alterações constitui aceitação dos novos termos.\n\n5. Contato\nDúvidas sobre estes termos podem ser enviadas para o contato de suporte listado na página do aplicativo na App Store."
          }
        },
        "pt-PT" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Ao utilizar esta aplicação, concorda com os seguintes termos.\n\n1. Sobre esta aplicação\nEsta aplicação fornece resultados ao vivo, jogos e classificação do Campeonato Brasileiro. Os dados de jogos, equipas e competição são fornecidos por uma API desportiva de terceiros e apresentados tal como recebidos; não garantimos a sua exatidão ou atualização em tempo real.\n\n2. Utilização aceitável\nCompromete-se a utilizar esta aplicação apenas para fins lícitos e a não tentar interromper, efetuar engenharia inversa ou obter acesso não autorizado aos seus serviços subjacentes.\n\n3. Sem garantias\nEsta aplicação é fornecida \"tal como está\", sem garantias de qualquer tipo. Não nos responsabilizamos por imprecisões nos dados dos jogos, atualizações em falta ou interrupções no serviço.\n\n4. Alterações a estes termos\nPodemos atualizar estes termos periodicamente. A utilização continuada da aplicação após alterações constitui aceitação dos novos termos.\n\n5. Contacto\nQuestões sobre estes termos podem ser enviadas para o contacto de suporte indicado na página da aplicação na App Store."
          }
        }
      }
    }
  },
  "version" : "1.1"
}
```

- [ ] **Step 3: Validate the JSON and confirm the project still builds**

Run:
```bash
plutil -lint BR2026/Resources/Localizable.xcstrings
/opt/homebrew/bin/rbenv exec bundle exec fastlane test
```
Expected: `plutil` prints `... OK`; fastlane's test run still ends with `Number of failures | 0`
(these are catalog/project changes only — no test count change from Task 1's 42).

- [ ] **Step 4: Commit**

```bash
git add BR2026/Resources/Localizable.xcstrings BR2026.xcodeproj/project.pbxproj
git commit -m "Add localized Terms of Service copy (5 locales) and More screen UI strings"
```

---

## Task 3: `MoreView` + `TermsOfServiceView`

**Files:**
- Modify: `BR2026/Views/More/MoreView.swift` (full rewrite)
- Create: `BR2026/Views/More/TermsOfServiceView.swift`
- Modify: `BR2026/Views/Root/ContentView.swift`

**Interfaces:**
- Consumes: `MoreViewModel`, `MoreSection`, `MoreRow`, `MoreDestination` (Task 1); catalog keys
  `"Legal"`, `"Preferences"`, `"Terms of Service"`, `"Settings"`, `"In-App Purchases"`,
  `"terms_of_service_body"` (Task 2); `GlassCard`, `StadiumBackground` (existing components).
- Produces: `MoreView` with no required init parameters (drops the `config: ChampionshipConfig`
  parameter the placeholder used, since the new design doesn't show championship name).

- [ ] **Step 1: Replace `MoreView.swift`**

Replace the full contents of `BR2026/Views/More/MoreView.swift`:
```swift
import SwiftUI

struct MoreView: View {
    @State private var viewModel = MoreViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(viewModel.sections) { section in
                        sectionView(section)
                    }
                }
                .padding(16)
            }
            .scrollContentBackground(.hidden)
            .background(StadiumBackground())
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: MoreDestination.self) { destination in
                switch destination {
                case .termsOfService:
                    TermsOfServiceView()
                }
            }
        }
    }

    private func sectionView(_ section: MoreSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.titleKey)
                .font(.system(size: 13, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
            GlassCard(cornerRadius: 18) {
                VStack(spacing: 0) {
                    ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                        rowView(row)
                        if index < section.rows.count - 1 {
                            Rectangle()
                                .fill(Color.white.opacity(0.16))
                                .frame(height: 0.5)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func rowView(_ row: MoreRow) -> some View {
        if row.isEnabled, let destination = row.destination {
            NavigationLink(value: destination) {
                rowLabel(row, showsChevron: true)
            }
            .buttonStyle(.plain)
        } else {
            rowLabel(row, showsChevron: false)
                .opacity(0.3)
        }
    }

    private func rowLabel(_ row: MoreRow, showsChevron: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: row.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 24)
            Text(row.titleKey)
                .font(.system(size: 16, weight: .semibold))
            Spacer()
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .foregroundStyle(.white)
        .padding(.vertical, 10)
    }
}
```

- [ ] **Step 2: Create `TermsOfServiceView.swift`**

Create `BR2026/Views/More/TermsOfServiceView.swift`:
```swift
import SwiftUI

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            Text("terms_of_service_body")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
        .scrollContentBackground(.hidden)
        .background(StadiumBackground())
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

- [ ] **Step 3: Update `ContentView.swift`'s call site**

In `BR2026/Views/Root/ContentView.swift`, replace:
```swift
            MoreView(config: config)
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
```
with:
```swift
            MoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
```

- [ ] **Step 4: Build and run the full test suite**

Run:
```bash
/opt/homebrew/bin/rbenv exec bundle exec fastlane test
```
Expected: `Number of failures | 0` (same 42 tests as Task 1 — this task adds no new tests, per
CLAUDE.md's "unit test ViewModels, not Views").

- [ ] **Step 5: Commit**

```bash
git add BR2026/Views/More/MoreView.swift BR2026/Views/More/TermsOfServiceView.swift BR2026/Views/Root/ContentView.swift
git commit -m "Build the More screen: Legal section with Terms of Service, disabled Settings/IAP rows"
```

---

## Task 4: Manual verification (no commit)

**Files:** None modified permanently. This task temporarily edits
`BR2026UITests/SnapshotUITests.swift` to drive one extra screenshot, then discards that edit —
mirroring the smoke-test-then-restore pattern already used for the `screenshots` lane.

**Interfaces:** Consumes the finished `MoreView`/`TermsOfServiceView` from Task 3. Produces
nothing lasting — this is a visual/behavioral check, not new automated coverage.

- [ ] **Step 1: Smoke-test the More tab screenshot**

Temporarily narrow `fastlane/Snapfile` to one device/locale (same approach used for the
`screenshots` lane originally):
```bash
cp fastlane/Snapfile fastlane/Snapfile.full.bak
```
Edit `fastlane/Snapfile`'s `devices`/`languages` calls to `devices(["iPhone 17"])` /
`languages(["en-US"])`, then run:
```bash
/opt/homebrew/bin/rbenv exec bundle exec fastlane screenshots
```
Expected: 💚 result; open `fastlane/screenshots/en-US/iPhone 17-04More.png` and confirm it shows
"LEGAL" / "PREFERENCES" section headers, an enabled "Terms of Service" row with a chevron, and
dimmed "Settings" / "In-App Purchases" rows with no chevron. Then restore and remove the backup:
```bash
mv fastlane/Snapfile.full.bak fastlane/Snapfile
```

- [ ] **Step 2: Verify the Terms of Service subview renders the localized text**

Temporarily add one more tap + snapshot to the end of
`BR2026UITests/SnapshotUITests.swift`'s `testCaptureScreenshots()` (after the existing "04More"
snapshot):
```swift
        app.buttons["Terms of Service"].tap()
        sleep(1)
        snapshot("05TermsOfService")
```
Run:
```bash
/opt/homebrew/bin/rbenv exec bundle exec fastlane screenshots
```
Expected: a fifth screenshot `iPhone 17-05TermsOfService.png` appears; open it and confirm it
shows the "Terms of Service" navigation title and the English starter legal text body (multiple
numbered paragraphs, not truncated or showing a raw string-catalog key).

If `app.buttons["Terms of Service"]` doesn't match, inspect via
`app.buttons.debugDescription` printed to the fastlane log, or try
`app.staticTexts["Terms of Service"]` instead — `NavigationLink` rows expose their label as
either depending on hit-testing container.

- [ ] **Step 3: Discard the temporary test edit**

```bash
git checkout -- BR2026UITests/SnapshotUITests.swift
git status
```
Expected: `git status` shows no pending changes (only the untracked/generated
`fastlane/screenshots/` output, which is gitignored).
