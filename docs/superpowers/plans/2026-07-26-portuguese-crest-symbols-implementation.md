# Liga Portugal Crest Symbols Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the Primeira Liga target hand-curated *futebol de botão* crest discs for all 18 clubs, adding a checkerboard pattern to the shared crest engine along the way.

**Architecture:** Two files do all the work, and both are shared byte-for-byte with the Fixture 2026 app in the sibling `../worldcup` repo. `TeamCrestSymbol.swift` gains a `.checkerboard` enum case and 18 `byTeamID` rows; `CrestDisc.swift` gains one `switch` branch to draw the checkerboard. Every edit to either file must be followed by `scripts/sync-crests.sh`, which copies both into `../worldcup` and rewrites their integrity stamps — `CrestSyncTests` in both repos fails otherwise.

**Tech Stack:** SwiftUI (iOS 26), Swift Testing, `xcodebuild`, a POSIX `sh` sync script.

## Global Constraints

- **Both shared files must be synced after any edit.** Run `./scripts/sync-crests.sh` from the white-label repo root. Never hand-edit the `// crest-sync:` stamp, and never edit the `../worldcup` copies directly — the white-label repo is the source of truth.
- **Every change lands in two repos.** `/Users/mlbbr-mac-vinicius/projects/footballWhiteLabel` and `/Users/mlbbr-mac-vinicius/projects/worldcup`. Both get their own commit.
- **Hex colours carry no leading `#`** — matches every existing entry and what `Color(hex:)` expects.
- **No force-unwraps (`!`) outside tests.**
- **No new unit tests for the crest data or the renderer.** Per CLAUDE.md, unit tests cover ViewModels and Services, not Views. The data table is static data feeding a View, and `CrestDisc` is a View. `CrestSyncTests` is the only test that moves, and it moves on its own.
- **Ask the user before running any `xcodebuild` command.** Standing preference — builds and test runs are slow and the user wants the call.
- **Test commands** (destinations verified available on this machine):
  - White-label: `xcodebuild test -project BR2026.xcodeproj -scheme BR2026 -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:BR2026Tests`
  - Fixture 2026: `xcodebuild test -project Fixture2026.xcodeproj -scheme Fixture2026 -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:Fixture2026Tests`
  - Always pipe through `tail` with `set -o pipefail`, then echo the pipeline's status — a bare pipe reports `tail`'s exit code, which hides a failed build. **This shell is zsh, not bash:** use `${pipestatus[1]}` (lowercase, 1-indexed). Bash's `${PIPESTATUS[0]}` expands to the empty string here, which reads as a passing check when nothing was checked at all.

**Spec:** `docs/superpowers/specs/2026-07-26-portuguese-crest-symbols-design.md`

---

## File Structure

| File | Repo | Responsibility |
|---|---|---|
| `BR2026/Models/TeamCrestSymbol.swift` | white-label (source of truth) | Pattern vocabulary (`TeamCrestSymbol`) + the `byTeamID` lookup table |
| `BR2026/Components/CrestDisc.swift` | white-label (source of truth) | Draws one disc from a symbol |
| `Fixture2026App/Models/TeamCrestSymbol.swift` | worldcup | Byte-identical copy, written by the sync script |
| `Fixture2026App/Components/CrestDisc.swift` | worldcup | Byte-identical copy, written by the sync script |

No new files. No project-file (`.pbxproj`) changes — every file involved is already a member of its targets.

---

### Task 1: Add the checkerboard case and its renderer

The engine change, landed on its own so a reviewer can judge the new pattern before eighteen clubs depend on it. After this task the case exists and draws correctly but nothing uses it yet — that is intentional.

**Files:**
- Modify: `BR2026/Models/TeamCrestSymbol.swift` (enum cases, ~line 38)
- Modify: `BR2026/Components/CrestDisc.swift` (`pattern` switch, ~line 92)
- Synced to: `../worldcup/Fixture2026App/Models/TeamCrestSymbol.swift`, `../worldcup/Fixture2026App/Components/CrestDisc.swift`

**Interfaces:**
- Consumes: `TeamCrestSymbol.Band`, `Color(hex:)` — both already exist.
- Produces: `case checkerboard(light: String, dark: String, squares: Int)`. Task 2 uses this for Moreirense as `.checkerboard(light: "FFFFFF", dark: "0A6B3D", squares: 4)`.

- [ ] **Step 1: Add the enum case**

In `BR2026/Models/TeamCrestSymbol.swift`, directly after the `diagonalSash` case (the last case, before the `equalStripes` helper):

```swift
    /// A checkerboard of `squares` × `squares` alternating cells, `light` in the top-left.
    /// The only two-dimensional pattern — every other case is a one-dimensional band list.
    case checkerboard(light: String, dark: String, squares: Int)
```

- [ ] **Step 2: Prove the sync guard catches the edit**

The shared file now disagrees with its stamp. Confirm the guard notices, without a full build:

```bash
cd /Users/mlbbr-mac-vinicius/projects/footballWhiteLabel
grep '^// crest-sync:' BR2026/Models/TeamCrestSymbol.swift | cut -d' ' -f3
grep -v '^// crest-sync:' BR2026/Models/TeamCrestSymbol.swift | shasum -a 256 | cut -d' ' -f1
```

Expected: the two hashes **differ**. That mismatch is exactly what `CrestSyncTests` asserts on, so it would fail right now. Do not fix it yet — Step 4 does.

- [ ] **Step 3: Add the renderer branch**

In `BR2026/Components/CrestDisc.swift`, add a final case to the `switch symbol` inside `pattern`, after the `.concentric` case:

```swift
        case .checkerboard(let light, let dark, let squares):
            // Guard the divisor: a zero or negative count would divide by zero below.
            let count = max(squares, 1)
            let cell = size / CGFloat(count)
            VStack(spacing: 0) {
                ForEach(Array(0..<count), id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(Array(0..<count), id: \.self) { column in
                            Color(hex: (row + column).isMultiple(of: 2) ? light : dark)
                                .frame(width: cell, height: cell)
                        }
                    }
                }
            }
```

`(row + column).isMultiple(of: 2)` puts `light` at row 0, column 0 — the top-left, as the doc comment promises.

- [ ] **Step 4: Sync both shared files**

```bash
cd /Users/mlbbr-mac-vinicius/projects/footballWhiteLabel
./scripts/sync-crests.sh
```

Expected: two lines naming the files and their new hash prefixes, then `note: synced to ... — commit both repos.`

- [ ] **Step 5: Verify the copies are identical and the stamps now agree**

```bash
cd /Users/mlbbr-mac-vinicius/projects/footballWhiteLabel
for f in Models/TeamCrestSymbol.swift Components/CrestDisc.swift; do
  diff -q BR2026/$f ../worldcup/Fixture2026App/$f >/dev/null && echo "$f identical" || echo "$f DIFFER"
  s=$(grep '^// crest-sync:' BR2026/$f | cut -d' ' -f3)
  a=$(grep -v '^// crest-sync:' BR2026/$f | shasum -a 256 | cut -d' ' -f1)
  [ "$s" = "$a" ] && echo "$f stamp OK" || echo "$f STAMP MISMATCH"
done
```

Expected: four lines, all `identical` / `stamp OK`.

- [ ] **Step 6: Run both test suites**

Ask the user first. Then run both commands from Global Constraints. Expected: `** TEST SUCCEEDED **` and `XCODEBUILD_EXIT=0` for each, with the two `Crest sync` tests passing in both.

This is the real check on Step 3: `CrestDisc`'s `switch` is exhaustive, so if the new case had no branch the build would fail outright.

- [ ] **Step 7: Commit both repos**

```bash
cd /Users/mlbbr-mac-vinicius/projects/footballWhiteLabel
git add BR2026/Models/TeamCrestSymbol.swift BR2026/Components/CrestDisc.swift
git commit -m "$(cat <<'EOF'
Teach the crest engine to draw a checkerboard

Every symbol so far is a one-dimensional band list — a row or a column of
coloured strips. Moreirense's kit is a checkerboard, which cannot be
expressed that way, so add a case that takes two colours and a square
count plus the renderer branch to draw it.

Nothing uses it yet; the Liga Portugal entries land next.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"

cd /Users/mlbbr-mac-vinicius/projects/worldcup
git add Fixture2026App/Models/TeamCrestSymbol.swift Fixture2026App/Components/CrestDisc.swift
git commit -m "$(cat <<'EOF'
Sync the crest engine's new checkerboard case

Mirrors the white-label repo, which is the source of truth for both
shared files. No Fixture 2026 team uses the case; taking it keeps the
copies byte-identical, which is what CrestSyncTests checks.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Add the eighteen Liga Portugal entries

**Files:**
- Modify: `BR2026/Models/TeamCrestSymbol.swift` (`byTeamID`, appended after the Scottish block, before the closing `]`)
- Synced to: `../worldcup/Fixture2026App/Models/TeamCrestSymbol.swift`

**Interfaces:**
- Consumes: `.equalStripes(_:)`, `.verticalStripes(_:)`, `.horizontalStripes(_:)`, `Band.init(_:_:)` (weight defaults to 1), and `.checkerboard(light:dark:squares:)` from Task 1.
- Produces: 18 rows in `byTeamID`. Nothing later depends on them by name.

- [ ] **Step 1: Append the entries**

In `BR2026/Models/TeamCrestSymbol.swift`, after the last Scottish entry (Dundee, id `253`) and before the closing `]` of `byTeamID`:

```swift

        // ── Liga Portugal ───────────────────────────────────────────────────────────────
        // Keyed by team id like everything above, so these are inert in the Brazilian,
        // Scottish and World Cup builds and need no target gating. Ids come from the live
        // PPL standings.
        // See docs/superpowers/specs/2026-07-26-portuguese-crest-symbols-design.md.

        // Benfica — solid red.
        211: .equalStripes(["DA020E"]),
        // FC Porto — blue & white vertical stripes, blue at both edges.
        212: .equalStripes(["003DA5", "FFFFFF", "003DA5", "FFFFFF", "003DA5", "FFFFFF", "003DA5"]),
        // Marítimo — green & red vertical stripes, green at both edges.
        214: .equalStripes(["00A551", "E4002B", "00A551", "E4002B", "00A551", "E4002B", "00A551"]),
        // Moreirense — green & white checkerboard, 4 squares across (the Croatia pattern).
        // Six across was tested on the crest board and rejected: it collapses into noise
        // below 32pt.
        215: .checkerboard(light: "FFFFFF", dark: "0A6B3D", squares: 4),
        // SC Braga — red body with white sleeves (the Arsenalistas heritage). Same shape as
        // Hibernian and Falkirk.
        217: .verticalStripes([
            .init("FFFFFF"),
            .init("DC0B15", 6),
            .init("FFFFFF"),
        ]),
        // Vitória de Guimarães — white with a thin black stripe (the Internacional structure).
        224: .verticalStripes([
            .init("FFFFFF", 8),
            .init("000000", 1),
            .init("FFFFFF", 2),
        ]),
        // Nacional — black & white vertical stripes, black at both edges.
        225: .equalStripes(["000000", "FFFFFF", "000000", "FFFFFF", "000000", "FFFFFF", "000000"]),
        // Rio Ave — green & white vertical stripes, white at both edges.
        226: .equalStripes(["FFFFFF", "007A3D", "FFFFFF", "007A3D", "FFFFFF", "007A3D", "FFFFFF"]),
        // Santa Clara — red & white vertical stripes, red at both edges.
        227: .equalStripes(["E4002B", "FFFFFF", "E4002B", "FFFFFF", "E4002B", "FFFFFF", "E4002B"]),
        // Sporting CP — green & white horizontal hoops, white at top & bottom. `equalStripes`
        // is vertical-only, so the equal bands are spelled out (same as Celtic).
        228: .horizontalStripes([
            .init("FFFFFF"),
            .init("008057"),
            .init("FFFFFF"),
            .init("008057"),
            .init("FFFFFF"),
            .init("008057"),
            .init("FFFFFF"),
        ]),
        // Estoril — yellow & blue vertical stripes, yellow at both edges.
        230: .equalStripes(["FFD400", "0033A0", "FFD400", "0033A0", "FFD400", "0033A0", "FFD400"]),
        // Académico de Viseu — black body with white sleeves (the same shape as SC Braga).
        238: .verticalStripes([
            .init("FFFFFF"),
            .init("111111", 6),
            .init("FFFFFF"),
        ]),
        // Arouca — yellow with a thin blue stripe (the Internacional structure).
        240: .verticalStripes([
            .init("FFD400", 8),
            .init("0A2E6E", 1),
            .init("FFD400", 2),
        ]),
        // Famalicão — blue with a thin white stripe (the Internacional structure).
        242: .verticalStripes([
            .init("0A2E6E", 8),
            .init("FFFFFF", 1),
            .init("0A2E6E", 2),
        ]),
        // Gil Vicente — red and blue halves. The only halved kit in any set.
        762: .equalStripes(["E4002B", "0A2E6E"]),
        // Casa Pia — black with a gold bar down the right. The only asymmetric disc in any
        // set: on a circle a bar down one side reads as a crescent rather than a stripe.
        4716: .verticalStripes([
            .init("111111", 7),
            .init("D4AF37", 2),
        ]),
        // Alverca — blue with a central red band. Colours sampled from a kit photo rather
        // than guessed; the kit's thin white edging was dropped because it would not have
        // survived 24pt.
        4724: .verticalStripes([
            .init("0060A8", 5),
            .init("F6002A", 3),
            .init("0060A8", 5),
        ]),
        // Estrela da Amadora — Fluminense's tricolour structure with thicker white bars
        // (1.8 against Fluminense's 1), so the three colours still read at badge size.
        15130: .verticalStripes([
            .init("FFFFFF", 1.8),
            .init("00613C", 3), .init("FFFFFF", 1.8),
            .init("870A28", 3), .init("FFFFFF", 1.8),
            .init("00613C", 3), .init("FFFFFF", 1.8),
            .init("870A28", 3), .init("FFFFFF", 1.8),
            .init("00613C", 3), .init("FFFFFF", 1.8),
            .init("870A28", 3), .init("FFFFFF", 1.8),
            .init("00613C", 3), .init("FFFFFF", 1.8),
        ]),
```

- [ ] **Step 2: Check every ID resolves and none collides**

The map is a dictionary literal — a duplicate key is a runtime trap, not a compile error, so check it explicitly:

```bash
cd /Users/mlbbr-mac-vinicius/projects/footballWhiteLabel
grep -oE '^[[:space:]]+[0-9]+:' BR2026/Models/TeamCrestSymbol.swift | tr -d ' :' | sort -n > /tmp/crest-ids.txt
echo "entries: $(wc -l < /tmp/crest-ids.txt)"
echo "duplicates:"; sort /tmp/crest-ids.txt | uniq -d
```

Expected: `entries: 50` (20 Brazilian + 12 Scottish + 18 Portuguese), and **no** lines under `duplicates:`.

- [ ] **Step 3: Check all 18 Portuguese IDs match the live PPL standings**

```bash
cd /Users/mlbbr-mac-vinicius/projects/footballWhiteLabel
KEY=$(grep '^API_KEY' Secrets.xcconfig | sed 's/.*=[[:space:]]*//' | tr -d '"' | tr -d ' ')
curl -s -H "X-Auth-Token: $KEY" \
  "https://football-api-production-16d9.up.railway.app/v4/competitions/PPL/standings" \
  | python3 -c "import json,sys; print('\n'.join(str(r['team']['id']) for r in json.load(sys.stdin)['standings']))" \
  | sort -n > /tmp/ppl-ids.txt
comm -3 <(grep -E '^(211|212|214|215|217|224|225|226|227|228|230|238|240|242|762|4716|4724|15130)$' /tmp/crest-ids.txt | sort -n) /tmp/ppl-ids.txt
```

Expected: **no output.** Any line means an ID in the table is not in the live league, or a club in the league has no entry.

- [ ] **Step 4: Sync both shared files**

```bash
cd /Users/mlbbr-mac-vinicius/projects/footballWhiteLabel
./scripts/sync-crests.sh
```

Then re-run the verify loop from Task 1 Step 5. Expected: four lines, all `identical` / `stamp OK`.

- [ ] **Step 5: Run both test suites**

Ask the user first, then run both commands from Global Constraints. Expected: `** TEST SUCCEEDED **` and `XCODEBUILD_EXIT=0` for each.

- [ ] **Step 6: Commit both repos**

```bash
cd /Users/mlbbr-mac-vinicius/projects/footballWhiteLabel
git add BR2026/Models/TeamCrestSymbol.swift
git commit -m "$(cat <<'EOF'
Add crest symbols for the 18 Liga Portugal clubs

Ids come from the live PPL standings, so they match what the app
receives. Every Portuguese club falls through to the initials placeholder
today.

Sixteen reuse shapes already in the Brazilian and Scottish sets. Sporting
gets Celtic's hoops, Moreirense the new checkerboard. Colours and
patterns were reviewed club by club on the crest board.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"

cd /Users/mlbbr-mac-vinicius/projects/worldcup
git add Fixture2026App/Models/TeamCrestSymbol.swift
git commit -m "$(cat <<'EOF'
Sync the Liga Portugal crest symbols

Mirrors the white-label repo. Fixture 2026 never sees a Primeira Liga
team id, so the rows are inert here — taking them keeps the shared file
byte-identical, which is what CrestSyncTests checks.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Verify the discs at real size

The spec's three Known Risks can only be judged in the simulator — the crest board renders at 104px, the app draws roughly 24pt on a match card. This task is the reason the plan does not push until Task 4.

**Files:** none, unless a risk materialises (then `BR2026/Models/TeamCrestSymbol.swift`, re-synced).

- [ ] **Step 1: Launch the Primeira Liga target in the simulator**

Ask the user first. Build and run the `PrimeiraLiga2026` target on iPhone 17, and open a screen showing several clubs at once — Standings gives the most crests per screen, Fixtures shows them at match-card size.

- [ ] **Step 2: Judge the three flagged discs**

Look specifically at:

| Club | Risk | Fallback if it fails |
|---|---|---|
| Casa Pia (4716) | Off-centre gold bar reads as a crescent on a circle | Centre it: `.init("111111", 4), .init("D4AF37", 2), .init("111111", 4)` |
| Moreirense (215) | 4 cells shimmer against the disc's glossy highlight | Drop to `squares: 3` |
| Guimarães (224), Arouca (240), Famalicão (242) | 1-weight stripe disappears | Widen to `1.5` |

All three fallbacks are data changes — no code, no new case.

- [ ] **Step 3: If nothing needs changing, say so and move to Task 4**

Report which discs were checked and on which screen. Do not claim discs were verified that were not visible.

- [ ] **Step 4: If something needs changing, apply the fallback, re-sync, re-test, commit both repos**

Apply the data change, then `./scripts/sync-crests.sh`, then the verify loop from Task 1 Step 5, then both test suites, then commit both repos with a message naming the club and what changed and why.

---

### Task 4: Push both repos

Split out because pushing is outward-facing and should not ride along with a visual check that might still produce fixes.

- [ ] **Step 1: Confirm both repos are clean and ahead**

```bash
cd /Users/mlbbr-mac-vinicius/projects/footballWhiteLabel && git status -sb | head -1 && git log origin/main..HEAD --oneline
cd /Users/mlbbr-mac-vinicius/projects/worldcup && git status -sb | head -1 && git log origin/main..HEAD --oneline
```

Expected: each shows its unpushed crest commits and no unstaged changes to the shared files. Unrelated untracked files (screenshots, `Localizable.xcstrings`, `.DS_Store`) are expected and must stay out.

- [ ] **Step 2: Push**

```bash
cd /Users/mlbbr-mac-vinicius/projects/footballWhiteLabel && git push origin main
cd /Users/mlbbr-mac-vinicius/projects/worldcup && git push origin main
```

- [ ] **Step 3: Confirm both landed**

```bash
cd /Users/mlbbr-mac-vinicius/projects/footballWhiteLabel && git status -sb | head -1
cd /Users/mlbbr-mac-vinicius/projects/worldcup && git status -sb | head -1
```

Expected: `## main...origin/main` with no `ahead` marker on either.

---

## Notes for the implementer

**Why the sync script and not just editing both copies.** The two apps ship from separate git repos, so nothing at build time can compare them. Each shared file carries a SHA-256 of its own body; `CrestSyncTests` recomputes it. Two copies carrying the same stamp and each hashing to it are necessarily byte-identical — that is the cross-repo guarantee. Hand-editing either copy breaks it silently until the tests run.

**Why there are no tests for the crests themselves.** CLAUDE.md scopes unit tests to ViewModels and Services. The 18 rows are static data and `CrestDisc` is a View; a test over the table would only restate it. The compile is the real check on the renderer (`CrestDisc`'s `switch` is exhaustive, so a missing branch fails the build), and the eye is the real check on the colours.

**What is deliberately not in scope.** No `.pbxproj` changes, no change to `TeamCrestBadge`'s policy for when a disc appears, no change to `TeamBadge` in Fixture 2026, and nothing on the marketing site — `website/` has no band engine, only a static `<span class="mock-crest">` letter.
