# Liga Portugal Crest Symbols — Design

**Date:** 2026-07-26
**Status:** approved (all 18 clubs reviewed on the crest board)

## Goal

Give the Primeira Liga target the same hand-curated *futebol de botão* crest discs the
Brasileirão and Scottish Premiership targets have, by adding 18 entries to
`TeamCrestSymbols.byTeamID`.

Today every Portuguese club falls through to the initials placeholder in `TeamCrestBadge`,
because `byTeamID` covers only the 20 Brazilian and 12 Scottish clubs.

## How this differs from the Scottish set

The Scottish set was data only: 12 band-list entries, one repo, no code. This one is not.

Moreirense's checkerboard is the first **two-dimensional** pattern in the engine. Every symbol
to date is a one-dimensional band list — a row or a column of coloured strips. A checkerboard
cannot be expressed that way, so it needs a new `TeamCrestSymbol` case and a new branch in
`CrestDisc`.

Both of those files are **shared byte-for-byte with the Fixture 2026 app** (see the header of
each, and `scripts/sync-crests.sh`). So this change carries a ripple the Scottish one did not:

| File | Change | Shared |
|---|---|---|
| `BR2026/Models/TeamCrestSymbol.swift` | 18 entries + `.checkerboard` case | yes |
| `BR2026/Components/CrestDisc.swift` | renderer branch for `.checkerboard` | yes |

Sequence: edit → run `scripts/sync-crests.sh` → both files' integrity stamps change → **commit
and push both repos**. Skipping the sync fails `CrestSyncTests` in whichever repo was edited,
which is the point of the stamp.

## Scope

**In:** 18 band-data entries, one new enum case, one new renderer branch.

**Out:** any change to `TeamCrestBadge`'s policy for *when* a disc is shown, to `TeamBadge` in
Fixture 2026, or to the crest cache.

**Not the marketing site.** The crest board's footer claims the checkerboard needs "a renderer
in each app and the site". It does not. `website/` has no band engine — its only crest is a
`<span class="mock-crest">H</span>` letter in a static mockup. The live matchday section that
might have needed one was removed on 2026-07-26.

Deliberately **not** a new screen. The crest board that drove this review is a throwaway
artifact, not app UI.

## Why no target gating

`byTeamID` is keyed by team ID and consulted per team, so entries are inert unless that team
appears in the data. Adding Portuguese clubs cannot affect the Brazilian, Scottish or World Cup
builds, and none of the `#if TARGET_*` gating that `AppIconOption` and
`MoreViewModel.preferencesRows` need applies here. Clubs with no entry keep the initials
placeholder, which is how every Portuguese club renders today.

This is also why the 18 entries are harmless in the Fixture 2026 copy of the shared file: that
app never sees a Primeira Liga team ID, so the rows are dead weight measured in bytes.

## Team IDs

Taken from the live `PPL` standings rather than assumed, so they match what the app receives.
All 18 were cross-checked against the board.

(The board's footer says these come from the `SPL` standings. That is a copy-paste slip from
the Scottish board — the IDs themselves are Portuguese and correct.)

| ID | Club | ID | Club |
|---|---|---|---|
| 211 | Benfica | 228 | Sporting CP |
| 212 | FC Porto | 230 | Estoril |
| 214 | Marítimo | 238 | Académico Viseu |
| 215 | Moreirense | 240 | Arouca |
| 217 | SC Braga | 242 | Famalicão |
| 224 | Guimarães | 762 | Gil Vicente |
| 225 | Nacional | 4716 | Casa Pia |
| 226 | Rio Ave | 4724 | Alverca |
| 227 | Santa Clara | 15130 | Estrela Amadora |

## Patterns

Sixteen of the eighteen are vertical band lists, reusing shapes already in the Brazilian and
Scottish sets. One is horizontal. One needs the new case.

- **Seven equal vertical bands** — Porto, Marítimo, Nacional, Rio Ave, Santa Clara and Estoril
  all share the shape Kilmarnock and St Mirren use: three bars of the second colour, club
  colour at both edges.
- **Horizontal hoops** — Sporting CP only. `equalStripes` is vertical-only, so the equal bands
  are spelled out with `.horizontalStripes`, exactly as Celtic's are.
- **Body between two sleeve bands** — SC Braga and Académico Viseu, the shape Hibernian and
  Falkirk use. Braga red, Viseu black.
- **Single thin stripe** — Guimarães, Arouca and Famalicão, the Internacional structure
  (8 : 1 : 2).
- **Halves** — Gil Vicente only, two equal vertical bands. New to the vocabulary, but it needs
  no new case.
- **Off-centre bar** — Casa Pia only, two bands weighted 7 : 2 so the gold sits down one side.
  The only asymmetric disc in any set.
- **Centred band** — Alverca, 5 : 3 : 5.
- **Tricolour pinstripes** — Estrela Amadora, Fluminense's structure with the white bars
  thickened to 1.8 (against Fluminense's 1).
- **Solid** — Benfica.
- **Checkerboard** — Moreirense, 4 squares across.

`diagonalSash` and `concentric` stay unused: no Primeira Liga club wears a sash.

## The checkerboard case

```swift
/// A checkerboard of `squares` × `squares` alternating cells, `light` in the top-left.
case checkerboard(light: String, dark: String, squares: Int)
```

Moreirense is `.checkerboard(light: "FFFFFF", dark: "0A6B3D", squares: 4)`.

`squares` is a stored parameter rather than a hardcoded 4 because it is the pattern's defining
dimension — a checkerboard case that cannot say how many squares it has is a worse API than one
extra `Int`. It is also the value most likely to be tuned after seeing it at real size.

**Renderer:** a `VStack` of `HStack`s, `squares` rows of `squares` cells, each row starting on
the opposite colour from the one above. This matches the band-list idiom already in
`CrestDisc.pattern`, needs no `Canvas`, and clips to the circle like every other pattern. At
24pt on a match card each cell is roughly 6pt.

Six-across was tested on the board and rejected — it collapses into noise below 32pt.

## Band data

The approved values, verbatim from the board. Colours are hex without a leading `#`, matching
every existing entry.

| Club | Symbol |
|---|---|
| Benfica | `.equalStripes(["DA020E"])` |
| FC Porto | 7 equal: `003DA5` / `FFFFFF`, blue at both edges |
| Sporting CP | 7 equal horizontal: `FFFFFF` / `008057`, white top & bottom |
| SC Braga | `FFFFFF` 1, `DC0B15` 6, `FFFFFF` 1 |
| Guimarães | `FFFFFF` 8, `000000` 1, `FFFFFF` 2 |
| Marítimo | 7 equal: `00A551` / `E4002B`, green at both edges |
| Nacional | 7 equal: `000000` / `FFFFFF`, black at both edges |
| Rio Ave | 7 equal: `FFFFFF` / `007A3D`, white at both edges |
| Moreirense | `.checkerboard(light: "FFFFFF", dark: "0A6B3D", squares: 4)` |
| Santa Clara | 7 equal: `E4002B` / `FFFFFF`, red at both edges |
| Estoril | 7 equal: `FFD400` / `0033A0`, yellow at both edges |
| Gil Vicente | `E4002B` 1, `0A2E6E` 1 |
| Arouca | `FFD400` 8, `0A2E6E` 1, `FFD400` 2 |
| Famalicão | `0A2E6E` 8, `FFFFFF` 1, `0A2E6E` 2 |
| Casa Pia | `111111` 7, `D4AF37` 2 |
| Académico Viseu | `FFFFFF` 1, `111111` 6, `FFFFFF` 1 |
| Alverca | `0060A8` 5, `F6002A` 3, `0060A8` 5 |
| Estrela Amadora | 15 bands: `FFFFFF` 1.8 alternating with `00613C` 3 and `870A28` 3 |

## Decisions made during review

- **Moreirense is a checkerboard, not stripes.** Accepted at 4 squares across even though it
  forces a new enum case, a renderer, and a re-sync of both repos. Six across was rejected as
  illegible below 32pt.
- **SC Braga's red is `#DC0B15`**, corrected during review from the first proposal.
- **Alverca's `#0060A8` and `#F6002A` are sampled from a kit photo**, not guessed. The kit's
  thin white edging was dropped deliberately — it would not survive 24pt.
- **Famalicão is blue with a white stripe**, the earlier proposal with the two colours swapped.
- **Gil Vicente is halved**, which puts the halved shape into the vocabulary for the first time.
- **Estrela Amadora's white bars are thickened to 1.8**, against Fluminense's 1, so the
  tricolour reads at badge size.
- **Académico Viseu reuses SC Braga's shape** in black rather than getting its own.

## Known risks

All are visual and none can be judged from the board, which renders at 104px against the app's
roughly 24pt on match cards.

- **Casa Pia's off-centre gold bar.** On a circle, a bar down one side reads as a crescent
  rather than a stripe. This is the one to look at hardest. If it reads wrong, centring it
  (`111111` 4, `D4AF37` 2, `111111` 4) is a data change, no code.
- **Moreirense at 4 across.** The whole reason for the new case. If the cells shimmer against
  the disc's glossy highlight, 3 across is the fallback — again data, no code.
- **The 1-weight thin stripes** on Guimarães, Arouca and Famalicão. Same class of risk the
  Scottish spec logged for Rangers' 0.35 pinstripes; those shipped, so 1 should be safe, but it
  is worth confirming on the same screen.

Check all three in the simulator before considering this done.

## Testing

Per CLAUDE.md, unit tests cover ViewModels and Services, not Views. The 18 entries are a static
data table feeding a View, and `CrestDisc` is a View — neither is unit-tested, and there is no
behaviour to assert that would not simply restate the table.

`CrestSyncTests` is the one test that does move: both shared files get new stamps from
`scripts/sync-crests.sh`, and the suites in both repos must pass afterwards. That is a
regression guard on the sync, not on the crests.

The meaningful verification is visual, at real size, in the simulator — see Known risks.
