# Live Match Polling — Design

## Context

Split out from the accessibility (VoiceOver) roadmap item: a future "announce score
changes" feature needs something to actually detect a change to announce, and today the
app has **no polling mechanism at all** — matches only refresh on first tab load
(`loadOnce()`, fires once per app session) or a manual pull-to-refresh gesture. A live
match can sit stale on screen indefinitely otherwise. This is valuable to every user, not
just VoiceOver ones, so it ships as its own project before the announcement feature is
built on top of it.

## Scope

Matchday, Fixtures, and Match Detail — the three screens that can show a match currently
`.live`. Standings stays refresh-on-demand only; points only change once a match finishes,
not while one is in progress.

## Behavior

- Poll only while a `.live` match is present in the screen's current data — not
  continuously. Cheapest on battery/network; a scheduled match transitioning to live gets
  picked up at the next natural refresh (tab reappear, pull-to-refresh, app foreground)
  rather than mid-wait.
- 30 second interval while live.
- Pause while the app is backgrounded; do one immediate refresh on returning to the
  foreground, then resume polling (rather than waiting out the rest of the interval).

## Components

### `LivePoller` (new, `BR2026/Services/LivePoller.swift`)

A minimal stateless helper — one static async function, not a class with manual
start/stop bookkeeping:

```swift
enum LivePoller {
    static func run(interval: Duration, shouldContinue: () -> Bool, action: () async -> Void) async {
        while !Task.isCancelled && shouldContinue() {
            try? await Task.sleep(for: interval)
            guard !Task.isCancelled && shouldContinue() else { break }
            await action()
        }
    }
}
```

Called from inside a View's `.task` modifier, so SwiftUI's structured concurrency cancels
it automatically when the view disappears or its `.task(id:)` identity changes — no
separate `Task` variable or manual `.cancel()` needed anywhere.

### ViewModel additions

`MatchdayViewModel` / `FixturesViewModel` each get:

```swift
var hasLiveMatch: Bool { matches.contains { $0.status == .live } }

func pollWhileLive() async {
    await LivePoller.run(interval: .seconds(30), shouldContinue: { hasLiveMatch }, action: { await load() })
}
```

`MatchDetailViewModel` gets the equivalent, checking its own single `match`:

```swift
var isLive: Bool { match.status == .live }

func pollWhileLive() async {
    await LivePoller.run(interval: .seconds(30), shouldContinue: { isLive }, action: { await load() })
}
```

`hasLiveMatch`/`isLive` are plain computed properties — unit-testable with Swift Testing
exactly like the rest of each ViewModel. `LivePoller`'s actual sleep loop is not unit
tested, consistent with how the rest of the suite avoids real async waits.

### Foreground/background + first-load, unified

Matchday and Fixtures currently drive their one-time cache+refresh via
`.task { await viewModel.loadOnce() }`, with a comment explaining why: the `.task`
modifier restarts every time the tab reappears (not just on first launch), and calling
`load()` unconditionally there caused a visible content jump colliding with
`.refreshable`. Adding a second, independent `.task` for polling would race against this
one on first launch (both would fire `load()`-family calls concurrently with no ordering
guarantee).

Instead, replace the existing task with a single one keyed to `scenePhase`, and add one
new ViewModel method that picks the right behavior depending on whether this is truly the
first activation:

```swift
// MatchdayViewModel / FixturesViewModel
func refreshIfNeeded() async {
    if hasLoadedOnce {
        await load()       // returning from background: always refresh
    } else {
        await loadOnce()   // first activation: cache-then-refresh-once
    }
}
```

```swift
// View
@Environment(\.scenePhase) private var scenePhase

.task(id: scenePhase) {
    guard scenePhase == .active else { return }
    await viewModel.refreshIfNeeded()
    await viewModel.pollWhileLive()
}
```

Walking through the cases:
- **First launch:** `scenePhase` is already `.active`, so the task runs immediately;
  `refreshIfNeeded()` takes the `loadOnce()` branch (cache + one-time background refresh),
  then `pollWhileLive()` starts.
- **Tab reappear** (TabView re-selection, not an app background/foreground event):
  `scenePhase` hasn't changed, so `id:` is unchanged and the task does **not** restart —
  this is what avoids the exact content-jump problem the current code comment warns
  about, more robustly than relying solely on the `hasLoadedOnce` guard.
- **App backgrounded:** `scenePhase` changes away from `.active` → `id:` changes → SwiftUI
  cancels the running task (which also cancels `pollWhileLive()`'s loop mid-sleep) → the
  new task instance's guard fails immediately, no-op.
- **Return to foreground:** `scenePhase` → `.active` again → new task →
  `refreshIfNeeded()` takes the `load()` branch (always refresh, since `hasLoadedOnce` is
  now `true`) → `pollWhileLive()` resumes.

`.refreshable`'s pull-to-refresh gesture is untouched — it already calls `load()` directly
and is orthogonal to this scenePhase-driven task.

Match Detail is simpler — each presentation is a fresh `MatchDetailViewModel` instance, so
there's no "first activation" ambiguity to resolve:

```swift
.task(id: scenePhase) {
    guard scenePhase == .active else { return }
    await viewModel.load()
    await viewModel.pollWhileLive()
}
```

### Match Detail's score/status sync

There's no single-match fetch endpoint (`MatchService` only exposes bulk `fetchMatches()`).
Rather than have `MatchDetailViewModel` redundantly poll the entire match list just to
refresh the one match's score, its `pollWhileLive()` only refreshes `events` (its own
unique content) — it relies on the `Match` object it holds being the *same reference* the
presenting screen (Matchday or Fixtures) already keeps live-updated via upsert-by-id, so
SwiftUI observation reflects score/status changes automatically since it's the same
instance. This depends on the presenting screen's own `.task(id: scenePhase)` continuing
to run while its sheet is up — standard SwiftUI behavior, since `.sheet` doesn't remove the
presenting view from the hierarchy — but worth confirming empirically during
implementation rather than taking on faith.

## Testing

- `hasLiveMatch` / `isLive`: Swift Testing, `MockMatchService`, matching the existing
  ViewModel test conventions — no SwiftData container, no real async waits.
- `refreshIfNeeded()`'s branch selection (loadOnce vs load, based on `hasLoadedOnce`):
  same testable-without-timing approach.
- `LivePoller.run`'s loop itself is not unit tested (real timing, not worth the flakiness).
- Manual verification: launch on a simulator, confirm a `.live` match's score updates
  in place ~30s after the backend value changes, without user interaction; background and
  foreground the app and confirm an immediate refresh happens on return.

## Out of scope

The actual "announce a score change via VoiceOver" feature — this project only builds the
underlying refresh mechanism it depends on. That resumes as a separate phase once this
ships.
