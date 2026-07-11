# Real API Screenshots Design

**Goal:** The `screenshots` fastlane lane currently forces `MockMatchService` (via the
`-FASTLANE_SNAPSHOT` launch argument fastlane's `snapshot` sets automatically) so App Store
screenshots are deterministic regardless of the live season/API state. Switch this so
screenshots are always captured against the real live API instead, accepting that captured
output will vary with whatever matches/standings exist at capture time.

**Architecture:** Remove the snapshot-specific mock override in `Championship.swift` so service
selection is uniform across snapshot and normal launches: always try `LiveMatchService`, fall
back to `MockMatchService` only if no real API key is configured. Bump the fixed sleeps in the
screenshot UI test to tolerate real network latency. No new flags, no new branching — the
snapshot-forces-mock code path is deleted, not made conditional.

## Service Selection

`BR2026/App/Championship.swift`:

- Delete the `shouldUseMockService(arguments:)` static method and its call site in
  `makeService()`.
- `makeService()` becomes unconditional: always attempt
  `LiveMatchService.makeFromBundle(config:modelContext:)` first; fall back to
  `MockMatchService()` only when that throws (missing/placeholder API key in
  `Secrets.xcconfig`). This is the same fallback that already exists for normal launches — it
  now also covers snapshot runs, so a fresh checkout without `Secrets.xcconfig` configured still
  produces screenshots (with mock data) instead of crashing.

## Tests

`BR2026Tests/App/ChampionshipServiceSelectionTests.swift`:

- Delete this file. It exists solely to test `shouldUseMockService`, which no longer exists.
  The remaining fallback behavior (mock-if-no-key) isn't snapshot-specific and isn't under test
  elsewhere either, so nothing loses coverage.

## Screenshot Capture Timing

`BR2026UITests/SnapshotUITests.swift`:

- Replace the fixed `sleep(1)` / `sleep(2)` calls before each tab's `snapshot(...)` call with a
  more generous fixed delay (e.g. 4–5s) to tolerate real network latency. Keeps the file's
  existing plain-`sleep()` style — no `waitForExistence` polling or new accessibility
  identifiers, since this lane runs manually/occasionally rather than in CI and doesn't need
  CI-grade determinism.

## Documentation

`CLAUDE.md`, Fastlane / Release Automation section:

- Remove the line stating screenshots are "deterministic regardless of the live season/API
  state" (no longer true).
- Note that the `screenshots` lane now requires a configured `Secrets.xcconfig` (real API key)
  and hits the live API, so captured output reflects whatever's live/scheduled at capture time.

## Out of Scope

- No CI workflow exists for the `screenshots` lane today (run manually) — no CI-secrets handling
  needed.
- No changes to `LiveMatchService` itself.
- No changes to how normal (non-screenshot) app launches select a service — that logic already
  does exactly what screenshots will now also do.
